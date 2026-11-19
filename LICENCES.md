# Licences

This repository builds a Publisher (.pub) file reader for the browser, used by Simply DTP.

- **libmspub** — Mozilla Public License 2.0 — https://wiki.documentfoundation.org/DLP/Libraries/libmspub
- **librevenge** — MPL 2.0 / LGPL 2.1+ — https://sourceforge.net/p/libwpd/wiki/librevenge/
- **libodfgen** — MPL 2.0 / LGPL 2.1+ — https://sourceforge.net/p/libwpd/wiki/libodfgen/
- **ICU** (Unicode text conversion) — Unicode License — https://github.com/unicode-org/icu
- **Boost** (headers) — Boost Software License 1.0 — https://www.boost.org/LICENSE_1_0.txt
- **zlib** — zlib License — https://zlib.net/zlib_license.html
- **src/pubreader.cpp** (the connector) — Mozilla Public License 2.0 — https://mozilla.org/MPL/2.0/

The source code of all of the above is downloaded by `build.sh` from the projects' official locations.
The full licence texts are copied into `dist/licences/` by each build.
