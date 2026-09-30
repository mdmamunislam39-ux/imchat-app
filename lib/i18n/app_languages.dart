import 'package:get/get.dart';

import 'lang/en.dart';
import 'lang/bn.dart';
import 'lang/ar.dart';
import 'lang/hi.dart';
import 'lang/ur.dart';
import 'lang/ru.dart';
import 'lang/id.dart';

class AppLanguages extends Translations {

  @override
  // App supported languages
  Map<String, Map<String, String>> get keys {
    return {
      "en": english,
      "bn": bangla,
      "ar": arabic,
      "hi": hindi,
      "ur": urdu,
      "ru": russian,
      "id": indonesian,
    };
  }
}


