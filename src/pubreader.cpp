// Simply DTP — Publisher reader for the browser.
// Reads a .pub file with libmspub and writes it out as a flat ODF drawing (.fodg, one XML text)
// with libodfgen. Simply DTP's .odg importer then turns that into editable pages.
// Licence: MPL-2.0 (same as libmspub).
#include <cstdlib>
#include <cstring>
#include <string>
#include <emscripten.h>
#include <librevenge/librevenge.h>
#include <librevenge-stream/librevenge-stream.h>
#include <libmspub/libmspub.h>
#include <libodfgen/libodfgen.hxx>

namespace {

// collects the XML that libodfgen writes into one string
class StringHandler : public OdfDocumentHandler {
public:
  std::string out;
  void startDocument() override {}
  void endDocument() override {}
  void startElement(const char *name, const librevenge::RVNGPropertyList &props) override {
    out += '<';
    out += name;
    librevenge::RVNGPropertyList::Iter i(props);
    for (i.rewind(); i.next();) {
      if (!i.key() || !*i.key() || i.child()) continue;
      librevenge::RVNGString value;
      value.appendEscapedXML(i()->getStr());
      out += ' ';
      out += i.key();
      out += "=\"";
      out += value.cstr();
      out += '"';
    }
    out += '>';
  }
  void endElement(const char *name) override {
    out += "</";
    out += name;
    out += '>';
  }
  void characters(const librevenge::RVNGString &text) override {
    librevenge::RVNGString value;
    value.appendEscapedXML(text);
    out += value.cstr();
  }
};

char *copyOut(const std::string &s) {
  char *p = static_cast<char *>(std::malloc(s.size() + 1));
  std::memcpy(p, s.c_str(), s.size() + 1);
  return p;
}

} // namespace

// Called from JavaScript. Returns a newly allocated string (free it with _free):
// the flat ODF XML, or "ERROR:..." if the file could not be read.
extern "C" EMSCRIPTEN_KEEPALIVE char *pub_to_fodg(const unsigned char *data, int length) {
  try {
    librevenge::RVNGStringStream input(data, static_cast<unsigned>(length));
    if (!libmspub::MSPUBDocument::isSupported(&input))
      return copyOut("ERROR:not-a-publisher-file");
    input.seek(0, librevenge::RVNG_SEEK_SET);
    StringHandler handler;
    OdgGenerator generator;
    generator.addDocumentHandler(&handler, ODF_FLAT_XML);
    if (!libmspub::MSPUBDocument::parse(&input, &generator))
      return copyOut("ERROR:could-not-read");
    return copyOut("<?xml version=\"1.0\" encoding=\"UTF-8\"?>" + handler.out);
  } catch (...) {
    return copyOut("ERROR:crashed");
  }
}
