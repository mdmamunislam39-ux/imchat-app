import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:country_code_picker/country_code_picker.dart';

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
    if (clean.length != 2) return '';
    try {
      final first = clean.codeUnitAt(0) - 0x41 + 0x1F1E6;
      final second = clean.codeUnitAt(1) - 0x41 + 0x1F1E6;
      return String.fromCharCode(first) + String.fromCharCode(second);
    } catch (_) {
      return '';
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
      orElse: () {
        // Search in extended codes if not in standard list
        for (final c in codes) {
          if ((c['code'] ?? '').toString().toUpperCase() == upper) {
            return CountryData(
              code: upper,
              name: c['name']?.toString() ?? upper,
              flag: codeToFlag(upper),
              dialCode: c['dial_code']?.toString() ?? '',
            );
          }
        }
        return CountryData(
          code: upper,
          name: upper,
          flag: codeToFlag(upper),
          dialCode: '',
        );
      },
    );
    return found;
  }

  /// Get country data by country name or code
  static CountryData getCountryDataByNameOrCode(String countryOrCode) {
    final clean = countryOrCode.trim();
    if (clean.isEmpty) return getCountryData('BD');

    final code = detectCountryCodeFromPhoneOrUser(countryStr: clean);
    if (code.isNotEmpty) {
      return getCountryData(code);
    }
    return getCountryData('BD');
  }

  /// Automatically detect user's device country via IP, system locale, or phone fallback
  static Future<CountryData> detectDeviceCountry({String? userPhone}) async {
    // 1. Try IP Geolocation first (fast timeout)
    try {
      final response = await http
          .get(Uri.parse('http://ip-api.com/json'))
          .timeout(const Duration(milliseconds: 2500));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && data['status'] == 'success') {
          final String? countryCode = data['countryCode']?.toString();
          if (countryCode != null && countryCode.trim().isNotEmpty) {
            final detectedCode = countryCode.trim().toUpperCase();
            debugPrint('📍 [CountryHelper] IP Geolocation detected: $detectedCode (${data['country']})');
            return getCountryData(detectedCode);
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [CountryHelper] Primary IP detection failed: $e');
    }

    // Secondary fallback IP service
    try {
      final response = await http
          .get(Uri.parse('https://api.country.is/'))
          .timeout(const Duration(milliseconds: 2000));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data is Map<String, dynamic> && data['country'] != null) {
          final String detectedCode = data['country'].toString().trim().toUpperCase();
          if (detectedCode.length == 2) {
            debugPrint('📍 [CountryHelper] Secondary IP detection detected: $detectedCode');
            return getCountryData(detectedCode);
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ [CountryHelper] Secondary IP detection failed: $e');
    }

    // 2. Try device system locale
    try {
      final locale = ui.PlatformDispatcher.instance.locale;
      final countryCode = locale.countryCode;
      if (countryCode != null && countryCode.trim().length == 2) {
        final cleanCode = countryCode.trim().toUpperCase();
        debugPrint('📍 [CountryHelper] System Locale detected: $cleanCode');
        return getCountryData(cleanCode);
      }
    } catch (e) {
      debugPrint('⚠️ [CountryHelper] System Locale detection failed: $e');
    }

    // 3. Try user's phone number
    if (userPhone != null && userPhone.trim().isNotEmpty) {
      final phoneCode = detectCountryCodeFromPhoneOrUser(phone: userPhone);
      if (phoneCode.isNotEmpty) {
        debugPrint('📍 [CountryHelper] Phone Prefix detected: $phoneCode');
        return getCountryData(phoneCode);
      }
    }

    // 4. Default fallback: Bangladesh
    return getCountryData('BD');
  }

  /// Detect ISO 2-letter country code from user profile country string or phone number
  static String detectCountryCodeFromPhoneOrUser({String? phone, String? countryStr}) {
    // 1. Prioritize user's explicitly selected country from profile
    if (countryStr != null && countryStr.trim().isNotEmpty && countryStr.trim().toLowerCase() != 'select') {
      final clean = countryStr.trim();
      final upper = clean.toUpperCase();

      // If already a 2-letter ISO code (e.g., 'BD', 'IN', 'SA', 'US')
      if (clean.length == 2 && RegExp(r'^[A-Za-z]{2}$').hasMatch(clean)) {
        return upper;
      }

      // Check common aliases
      if (upper == 'USA' || upper == 'UNITED STATES OF AMERICA' || upper == 'UNITED STATES') return 'US';
      if (upper == 'UK' || upper == 'UNITED KINGDOM' || upper == 'ENGLAND' || upper == 'GREAT BRITAIN') return 'GB';
      if (upper == 'KSA' || upper == 'SAUDI ARABIA') return 'SA';
      if (upper == 'UAE' || upper == 'UNITED ARAB EMIRATES') return 'AE';
      if (upper == 'SOUTH KOREA' || upper == 'KOREA') return 'KR';
      if (upper == 'RUSSIA' || upper == 'RUSSIAN FEDERATION') return 'RU';

      // Match against full 250+ country list from country_code_picker
      for (final c in codes) {
        final name = c['name']?.toString() ?? '';
        final code = c['code']?.toString() ?? '';
        if (name.toLowerCase() == clean.toLowerCase() ||
            code.toLowerCase() == clean.toLowerCase()) {
          return code.toUpperCase();
        }
      }

      // Partial match in country_code_picker
      for (final c in codes) {
        final name = c['name']?.toString() ?? '';
        final code = c['code']?.toString() ?? '';
        if (name.isNotEmpty && (name.toLowerCase().contains(clean.toLowerCase()) ||
            clean.toLowerCase().contains(name.toLowerCase()))) {
          return code.toUpperCase();
        }
      }
    }

    // 2. Fallback to phone number dial code if country is not set
    if (phone != null && phone.trim().isNotEmpty) {
      String p = phone.trim().replaceAll(RegExp(r'[^\d+]'), '');
      if (p.startsWith('+')) p = p.substring(1);

      // Match dial code from country_code_picker
      for (final c in codes) {
        final dial = (c['dial_code'] ?? '').replaceAll('+', '');
        final code = c['code']?.toString() ?? '';
        if (dial.isNotEmpty && p.startsWith(dial) && code.isNotEmpty) {
          return code.toUpperCase();
        }
      }

      // Local BD mobile prefixes: 013, 014, 015, 016, 017, 018, 019
      if (RegExp(r'^01[3-9]').hasMatch(p)) return 'BD';
    }
    return '';
  }
}

