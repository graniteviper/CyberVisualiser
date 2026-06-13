class CountryCoordinate {
  final double latitude;
  final double longitude;

  const CountryCoordinate(this.latitude, this.longitude);
}

class CountryCoordinatesLookup {
  static const Map<String, CountryCoordinate> _coordinates = {
    'US': CountryCoordinate(37.0902, -95.7129),
    'CN': CountryCoordinate(35.8617, 104.1954),
    'RU': CountryCoordinate(61.5240, 105.3188),
    'DE': CountryCoordinate(51.1657, 10.4515),
    'IN': CountryCoordinate(20.5937, 78.9629),
    'BR': CountryCoordinate(-14.2350, -51.9253),
    'GB': CountryCoordinate(55.3781, -3.4360),
    'FR': CountryCoordinate(46.2276, 2.2137),
    'NL': CountryCoordinate(52.1326, 5.2913),
    'JP': CountryCoordinate(36.2048, 138.2529),
    'UA': CountryCoordinate(48.3794, 31.1656),
    'PL': CountryCoordinate(51.9194, 19.1451),
    'RO': CountryCoordinate(45.9432, 24.9668),
    'CA': CountryCoordinate(56.1304, -106.3468),
    'SG': CountryCoordinate(1.3521, 103.8198),
    'VN': CountryCoordinate(14.0583, 108.2772),
    'AU': CountryCoordinate(-25.2744, 133.7751),
    'ZA': CountryCoordinate(-30.5595, 22.9375),
    'KR': CountryCoordinate(35.9078, 127.7669),
    'TW': CountryCoordinate(23.6978, 120.9605),
    'IR': CountryCoordinate(32.4279, 53.6880),
    'TR': CountryCoordinate(38.9637, 35.2433),
    'ES': CountryCoordinate(40.4637, -3.7492),
    'IT': CountryCoordinate(41.8719, 12.5674),
    'SE': CountryCoordinate(60.1282, 18.6435),
    'CH': CountryCoordinate(46.8182, 8.2275),
    'IE': CountryCoordinate(53.4129, -8.2439),
    'HK': CountryCoordinate(22.3964, 114.1095),
    'ID': CountryCoordinate(-0.7893, 113.9213),
    'MX': CountryCoordinate(23.6345, -102.5528),
    'AR': CountryCoordinate(-38.4161, -63.6167),
    'CL': CountryCoordinate(-35.6751, -71.5430),
    'CO': CountryCoordinate(4.5709, -74.2973),
    'PE': CountryCoordinate(-9.1900, -75.0152),
    'VE': CountryCoordinate(6.4238, -66.5897),
    'IL': CountryCoordinate(31.0461, 34.8516),
    'SA': CountryCoordinate(23.8859, 45.0792),
    'AE': CountryCoordinate(23.4241, 53.8478),
    'TH': CountryCoordinate(15.8700, 100.9925),
    'MY': CountryCoordinate(4.2105, 101.9758),
    'PH': CountryCoordinate(12.8797, 121.7740),
    'PK': CountryCoordinate(30.3753, 69.3451),
    'BD': CountryCoordinate(23.6850, 90.3563),
    'EG': CountryCoordinate(26.8206, 30.8025),
    'NG': CountryCoordinate(9.0820, 8.6753),
    'KE': CountryCoordinate(-1.2921, 36.8219),
    'MA': CountryCoordinate(31.7917, -7.0926),
    'FI': CountryCoordinate(61.9241, 25.7482),
    'NO': CountryCoordinate(60.4720, 8.4689),
    'DK': CountryCoordinate(56.2639, 9.5018),
    'NZ': CountryCoordinate(-40.9006, 174.8860),
  };

  /// Looks up the coordinate of a country code. Returns a default coordinate (0,0) if not found.
  static CountryCoordinate getCoordinate(String countryCode) {
    final code = countryCode.trim().toUpperCase();
    return _coordinates[code] ?? const CountryCoordinate(0.0, 0.0);
  }
}
