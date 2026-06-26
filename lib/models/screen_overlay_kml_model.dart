class ScreenOverlayKmlModel {
  static String generateLogoKML() {
    return '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2" xmlns:kml="http://www.opengis.net/kml/2.2" xmlns:atom="http://www.w3.org/2005/Atom">
    <Document>
        <name>Logo</name>
        <ScreenOverlay>
            <name>Logo</name>
            <Icon>
                <href>https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEgXmdNgBTXup6bdWew5RzgCmC9pPb7rK487CpiscWB2S8OlhwFHmeeACHIIjx4B5-Iv-t95mNUx0JhB_oATG3-Tq1gs8Uj0-Xb9Njye6rHtKKsnJQJlzZqJxMDnj_2TXX3eA5x6VSgc8aw/s320-rw/LOGO+LIQUID+GALAXY-sq1000-+OKnoline.png</href>
            </Icon>
            <overlayXY x="0.5" y="0.5" xunits="fraction" yunits="fraction"/>
            <screenXY x="0.5" y="0.5" xunits="fraction" yunits="fraction"/>
            <rotationXY x="0" y="0" xunits="fraction" yunits="fraction"/>
            <size x="350" y="200" xunits="pixels" yunits="pixels"/>
        </ScreenOverlay>
    </Document>
</kml>''';
  }
}
