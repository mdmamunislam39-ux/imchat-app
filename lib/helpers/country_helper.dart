/// Model representing country details
class CountryData {
  final String code; // 2-letter ISO short code (e.g., 'BD', 'IN', 'US')
  final String name; // Full country name (e.g., 'Bangladesh', 'India')
  final String flag; // Flag emoji (e.g., '🇧🇩', '🇮🇳')
  final String dialCode; // Phone prefix (e.g., '+880', '+91')

  const CountryData({
    required this.code,
    required this.name,
    required this.flag,
    required this.dialCode,
  });
}

class CountryHelper {
  /// Convert 2-letter ISO country code to flag emoji
  static String codeToFlag(String countryCode) {
    final clean = countryCode.trim().toUpperCase();
    if (clean.length != 2) return '🌐';
    try {
      final first = clean.codeUnitAt(0) - 0x41 + 0x1F1E6;
      final second = clean.codeUnitAt(1) - 0x41 + 0x1F1E6;
      return String.fromCharCode(first) + String.fromCharCode(second);
    } catch (_) {
      return '🌐';
    }
  }

  /// List of supported countries with flags, codes, names and dial codes
  static const List<CountryData> _countries = [
    CountryData(code: 'BD', name: 'Bangladesh', flag: '🇧🇩', dialCode: '+880'),
    CountryData(code: 'IN', name: 'India', flag: '🇮🇳', dialCode: '+91'),
    CountryData(code: 'PK', name: 'Pakistan', flag: '🇵🇰', dialCode: '+92'),
    CountryData(code: 'SA', name: 'Saudi Arabia', flag: '🇸🇦', dialCode: '+966'),
    CountryData(code: 'AE', name: 'UAE', flag: '🇦🇪', dialCode: '+971'),
    CountryData(code: 'QA', name: 'Qatar', flag: '🇶🇦', dialCode: '+974'),
    CountryData(code: 'KW', name: 'Kuwait', flag: '🇰🇼', dialCode: '+965'),
    CountryData(code: 'OM', name: 'Oman', flag: '🇴🇲', dialCode: '+968'),
    CountryData(code: 'BH', name: 'Bahrain', flag: '🇧🇭', dialCode: '+973'),
    CountryData(code: 'MY', name: 'Malaysia', flag: '🇲🇾', dialCode: '+60'),
    CountryData(code: 'US', name: 'United States', flag: '🇺🇸', dialCode: '+1'),
    CountryData(code: 'GB', name: 'United Kingdom', flag: '🇬🇧', dialCode: '+44'),
    CountryData(code: 'SG', name: 'Singapore', flag: '🇸🇬', dialCode: '+65'),
    CountryData(code: 'ID', name: 'Indonesia', flag: '🇮🇩', dialCode: '+62'),
    CountryData(code: 'PH', name: 'Philippines', flag: '🇵🇭', dialCode: '+63'),
    CountryData(code: 'TH', name: 'Thailand', flag: '🇹🇭', dialCode: '+66'),
    CountryData(code: 'VN', name: 'Vietnam', flag: '🇻🇳', dialCode: '+84'),
    CountryData(code: 'TR', name: 'Turkey', flag: '🇹🇷', dialCode: '+90'),
    CountryData(code: 'EG', name: 'Egypt', flag: '🇪🇬', dialCode: '+20'),
    CountryData(code: 'NG', name: 'Nigeria', flag: '🇳🇬', dialCode: '+234'),
    CountryData(code: 'DE', name: 'Germany', flag: '🇩🇪', dialCode: '+49'),
    CountryData(code: 'FR', name: 'France', flag: '🇫🇷', dialCode: '+33'),
    CountryData(code: 'IT', name: 'Italy', flag: '🇮🇹', dialCode: '+39'),
    CountryData(code: 'ES', name: 'Spain', flag: '🇪🇸', dialCode: '+34'),
    CountryData(code: 'JP', name: 'Japan', flag: '🇯🇵', dialCode: '+81'),
    CountryData(code: 'KR', name: 'South Korea', flag: '🇰🇷', dialCode: '+82'),
    CountryData(code: 'CN', name: 'China', flag: '🇨🇳', dialCode: '+86'),
    CountryData(code: 'BR', name: 'Brazil', flag: '🇧🇷', dialCode: '+55'),
    CountryData(code: 'RU', name: 'Russia', flag: '🇷🇺', dialCode: '+7'),
    CountryData(code: 'CA', name: 'Canada', flag: '🇨🇦', dialCode: '+1'),
    CountryData(code: 'AU', name: 'Australia', flag: '🇦🇺', dialCode: '+61'),
    CountryData(code: 'IQ', name: 'Iraq', flag: '🇮🇶', dialCode: '+964'),
    CountryData(code: 'JO', name: 'Jordan', flag: '🇯🇴', dialCode: '+962'),
    CountryData(code: 'LB', name: 'Lebanon', flag: '🇱🇧', dialCode: '+961'),
    CountryData(code: 'SY', name: 'Syria', flag: '🇸🇾', dialCode: '+963'),
    CountryData(code: 'YE', name: 'Yemen', flag: '🇾🇪', dialCode: '+967'),
    CountryData(code: 'IR', name: 'Iran', flag: '🇮🇷', dialCode: '+98'),
    CountryData(code: 'AF', name: 'Afghanistan', flag: '🇦🇫', dialCode: '+93'),
    CountryData(code: 'NP', name: 'Nepal', flag: '🇳🇵', dialCode: '+977'),
    CountryData(code: 'LK', name: 'Sri Lanka', flag: '🇱🇰', dialCode: '+94'),
    CountryData(code: 'TW', name: 'Taiwan', flag: '🇹🇼', dialCode: '+886'),
    CountryData(code: 'HK', name: 'Hong Kong', flag: '🇭🇰', dialCode: '+852'),
    CountryData(code: 'MA', name: 'Morocco', flag: '🇲🇦', dialCode: '+212'),
    CountryData(code: 'DZ', name: 'Algeria', flag: '🇩🇿', dialCode: '+213'),
    CountryData(code: 'TN', name: 'Tunisia', flag: '🇹🇳', dialCode: '+216'),
    CountryData(code: 'SD', name: 'Sudan', flag: '🇸🇩', dialCode: '+249'),
    CountryData(code: 'ZA', name: 'South Africa', flag: '🇿🇦', dialCode: '+27'),
    CountryData(code: 'KE', name: 'Kenya', flag: '🇰🇪', dialCode: '+254'),
  ];

  /// Get list of all supported countries
  static List<CountryData> getAllCountries() {
    return _countries;
  }

  /// Get country data by ISO short code
  static CountryData getCountryData(String code) {
    final upper = code.trim().toUpperCase();
    final found = _countries.firstWhere(
      (c) => c.code == upper,
      orElse: () => CountryData(
        code: upper,
        name: upper,
        flag: codeToFlag(upper),
        dialCode: '',
      ),
    );
    return found;
  }

  /// Detect ISO 2-letter country code from phone number or user profile country string
  static String detectCountryCodeFromPhoneOrUser({String? phone, String? countryStr}) {
    if (phone != null && phone.trim().isNotEmpty) {
      String p = phone.trim().replaceAll(RegExp(r'[^\d+]'), '');
      if (p.startsWith('+')) p = p.substring(1);

      // 3-digit dial codes
      if (p.startsWith('880')) return 'BD';
      if (p.startsWith('966')) return 'SA';
      if (p.startsWith('971')) return 'AE';
      if (p.startsWith('974')) return 'QA';
      if (p.startsWith('965')) return 'KW';
      if (p.startsWith('968')) return 'OM';
      if (p.startsWith('973')) return 'BH';
      if (p.startsWith('964')) return 'IQ';
      if (p.startsWith('962')) return 'JO';
      if (p.startsWith('961')) return 'LB';
      if (p.startsWith('963')) return 'SY';
      if (p.startsWith('967')) return 'YE';
      if (p.startsWith('977')) return 'NP';
      if (p.startsWith('886')) return 'TW';
      if (p.startsWith('852')) return 'HK';
      if (p.startsWith('234')) return 'NG';
      if (p.startsWith('212')) return 'MA';
      if (p.startsWith('213')) return 'DZ';
      if (p.startsWith('216')) return 'TN';
      if (p.startsWith('249')) return 'SD';
      if (p.startsWith('254')) return 'KE';

      // 2-digit dial codes
      if (p.startsWith('91')) return 'IN';
      if (p.startsWith('92')) return 'PK';
      if (p.startsWith('60')) return 'MY';
      if (p.startsWith('65')) return 'SG';
      if (p.startsWith('66')) return 'TH';
      if (p.startsWith('84')) return 'VN';
      if (p.startsWith('62')) return 'ID';
      if (p.startsWith('63')) return 'PH';
      if (p.startsWith('90')) return 'TR';
      if (p.startsWith('20')) return 'EG';
      if (p.startsWith('49')) return 'DE';
      if (p.startsWith('33')) return 'FR';
      if (p.startsWith('39')) return 'IT';
      if (p.startsWith('34')) return 'ES';
      if (p.startsWith('44')) return 'GB';
      if (p.startsWith('81')) return 'JP';
      if (p.startsWith('82')) return 'KR';
      if (p.startsWith('86')) return 'CN';
      if (p.startsWith('55')) return 'BR';
      if (p.startsWith('98')) return 'IR';
      if (p.startsWith('93')) return 'AF';
      if (p.startsWith('94')) return 'LK';
      if (p.startsWith('27')) return 'ZA';

      // 1-digit dial codes
      if (p.startsWith('1')) return 'US';
      if (p.startsWith('7')) return 'RU';

      // Local BD mobile prefixes: 013, 014, 015, 016, 017, 018, 019
      if (RegExp(r'^01[3-9]').hasMatch(p)) return 'BD';
    }

    if (countryStr != null && countryStr.trim().isNotEmpty) {
      final c = countryStr.trim().toUpperCase();
      if (c == 'BANGLADESH' || c == 'BD') return 'BD';
      if (c == 'INDIA' || c == 'IN') return 'IN';
      if (c == 'PAKISTAN' || c == 'PK') return 'PK';
      if (c == 'SAUDI ARABIA' || c == 'KSA' || c == 'SA') return 'SA';
      if (c == 'UAE' || c == 'UNITED ARAB EMIRATES' || c == 'AE') return 'AE';
      if (c == 'QATAR' || c == 'QA') return 'QA';
      if (c == 'KUWAIT' || c == 'KW') return 'KW';
      if (c == 'OMAN' || c == 'OM') return 'OM';
      if (c == 'BAHRAIN' || c == 'BH') return 'BH';
      if (c == 'MALAYSIA' || c == 'MY') return 'MY';
      if (c == 'USA' || c == 'UNITED STATES' || c == 'US') return 'US';
      if (c == 'UK' || c == 'UNITED KINGDOM' || c == 'GB') return 'GB';
      if (c.length == 2) return c;
    }

    return 'BD';
  }
}
