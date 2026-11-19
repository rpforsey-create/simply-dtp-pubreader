#!/bin/bash
# Builds librevenge, libodfgen and libmspub for WebAssembly, then links them with src/pubreader.cpp.
# Output: dist/pubreader.mjs + dist/pubreader.wasm (+ licences)
set -euo pipefail

ROOT="$(pwd)"
PREFIX="$ROOT/prefix"
WORK="$ROOT/work"
mkdir -p "$PREFIX" "$WORK" "$ROOT/dist/licences"

REVENGE=librevenge-0.0.5
ODFGEN=libodfgen-0.1.8
MSPUB=libmspub-0.1.4
XML2=libxml2-2.12.9

step() { echo; echo "=================== $* ==================="; }

export CFLAGS="-O2 -fexceptions"
export CXXFLAGS="-O2 -fexceptions -std=gnu++14 -D_LIBCPP_ENABLE_CXX17_REMOVED_UNARY_BINARY_FUNCTION -Wno-deprecated-declarations"
export LDFLAGS="-fexceptions"
export CPPFLAGS="-I$PREFIX/include"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"
# Emscripten's configure helper replaces PKG_CONFIG_PATH with EM_PKG_CONFIG_PATH, so set that too
export EM_PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig"
# and tell libodfgen / libmspub directly where librevenge is, in case pkg-config still can't see it
export REVENGE_CFLAGS="-I$PREFIX/include/librevenge-0.0"
export REVENGE_LIBS="-L$PREFIX/lib -lrevenge-stream-0.0 -lrevenge-0.0"
export REVENGE_STREAM_CFLAGS="-I$PREFIX/include/librevenge-0.0"
export REVENGE_STREAM_LIBS="-L$PREFIX/lib -lrevenge-stream-0.0"
export REVENGE_GENERATORS_CFLAGS="-I$PREFIX/include/librevenge-0.0"
export REVENGE_GENERATORS_LIBS=""
# libodfgen uses libxml2 (built below)
export XML_CFLAGS="-I$PREFIX/include/libxml2"
export XML_LIBS="-L$PREFIX/lib -lxml2"
export LIBXML2_CFLAGS="$XML_CFLAGS" LIBXML2_LIBS="$XML_LIBS"
# use Emscripten's own builds of these libraries instead of looking for system ones
export ZLIB_CFLAGS="-sUSE_ZLIB=1"  ZLIB_LIBS="-sUSE_ZLIB=1"
export ICU_CFLAGS="-sUSE_ICU=1"    ICU_LIBS="-sUSE_ICU=1"

step "Preparing Emscripten's zlib, ICU and Boost"
embuilder build zlib icu boost_headers

# download a source package, trying a few mirrors
fetch() {
  local name="$1"; shift
  cd "$WORK"
  if [ -d "$name" ]; then return; fi
  for url in "$@"; do
    echo "Downloading $url"
    if curl -fsSL --retry 3 -o "$name.tar" "$url"; then
      tar xf "$name.tar" && rm "$name.tar" && [ -d "$name" ] && return
    fi
  done
  echo "Could not download $name"; exit 1
}
# older packages don't know the 'wasm32-unknown-emscripten' target: give them up-to-date helper scripts
refresh_config() {
  for f in config.sub config.guess; do
    local newest; newest="$(ls /usr/share/automake-*/$f 2>/dev/null | tail -1 || true)"
    [ -n "$newest" ] && cp "$newest" "$f" || true
  done
}
build_lib() {
  local name="$1"; shift
  step "Building $name"
  cd "$WORK/$name"
  refresh_config
  emconfigure ./configure --host=wasm32-unknown-emscripten --prefix="$PREFIX" \
    --disable-shared --enable-static --disable-werror --without-docs "$@"
  emmake make -j"$(nproc)"
  emmake make install
  for l in COPYING COPYING.MPL COPYING.LGPL; do [ -f "$l" ] && cp "$l" "$ROOT/dist/licences/$name-$l" || true; done
}

fetch "$REVENGE" \
  "https://dev-www.libreoffice.org/src/$REVENGE.tar.xz" \
  "https://dev-www.libreoffice.org/src/$REVENGE.tar.bz2" \
  "https://sourceforge.net/projects/libwpd/files/librevenge/$REVENGE/$REVENGE.tar.xz/download"
build_lib "$REVENGE" --disable-tests --disable-generators --enable-streams

fetch "$XML2" \
  "https://download.gnome.org/sources/libxml2/2.12/$XML2.tar.xz"
build_lib "$XML2" --without-python --without-zlib --without-lzma --without-http --without-ftp \
  --without-threads --without-modules --without-iconv --without-icu --without-readline --without-debug

fetch "$ODFGEN" \
  "https://dev-www.libreoffice.org/src/$ODFGEN.tar.xz" \
  "https://dev-www.libreoffice.org/src/$ODFGEN.tar.bz2" \
  "https://sourceforge.net/projects/libwpd/files/libodfgen/$ODFGEN/$ODFGEN.tar.xz/download"
build_lib "$ODFGEN" --disable-test

fetch "$MSPUB" \
  "https://dev-www.libreoffice.org/src/$MSPUB.tar.xz" \
  "https://dev-www.libreoffice.org/src/libmspub/$MSPUB.tar.xz" \
  "https://dev-www.libreoffice.org/src/$MSPUB.tar.bz2"
build_lib "$MSPUB" --disable-tools

step "Linking pubreader"
INC="-I$PREFIX/include/librevenge-0.0 -I$PREFIX/include/libodfgen-0.1 -I$PREFIX/include/libmspub-0.1"
em++ $CXXFLAGS $INC "$ROOT/src/pubreader.cpp" \
  "$PREFIX/lib/libmspub-0.1.a" "$PREFIX/lib/libodfgen-0.1.a" \
  "$PREFIX/lib/librevenge-stream-0.0.a" "$PREFIX/lib/librevenge-0.0.a" "$PREFIX/lib/libxml2.a" \
  -sUSE_ICU=1 -sUSE_ZLIB=1 -sUSE_BOOST_HEADERS=1 \
  -sMODULARIZE=1 -sEXPORT_ES6=1 -sEXPORT_NAME=createPubReader -sENVIRONMENT=web,worker \
  -sALLOW_MEMORY_GROWTH=1 -sSTACK_SIZE=8MB \
  -sEXPORTED_FUNCTIONS=_pub_to_fodg,_malloc,_free -sEXPORTED_RUNTIME_METHODS=UTF8ToString,HEAPU8 \
  -o "$ROOT/dist/pubreader.mjs"

cp "$ROOT/LICENCES.md" "$ROOT/dist/licences/" 2>/dev/null || true
step "Done"
ls -la "$ROOT/dist"
