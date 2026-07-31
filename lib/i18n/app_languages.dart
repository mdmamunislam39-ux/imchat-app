import 'package:get/get.dart';

import 'lang/en.dart';

class AppLanguages extends Translations {

  @override
  // App supported languages
  Map<String, Map<String, String>> get keys {
    return {
      "en": english,
      "bn": {
        ...english,
        "lang_name": "Bangla (বাংলা)",
        "language": "ভাষা",
        "choose_a_language": "একটি ভাষা নির্বাচন করুন",
        "change_language": "ভাষা পরিবর্তন করুন",
        "chats": "চ্যাট",
        "profile": "প্রোফাইল",
        "settings": "সেটিংস",
        "dark_theme": "ডার্ক থিম",
        "invite_friends": "বন্ধুদের আমন্ত্রণ জানান",
        "groups": "গ্রুপ",
        "calls": "কল",
      },
      "ar": {
        ...english,
        "lang_name": "Arabic (العربية)",
        "language": "اللغة",
        "choose_a_language": "اختر لغة",
        "change_language": "تغيير اللغة",
        "chats": "المحادثات",
        "profile": "الملف الشخصي",
        "settings": "الإعدادات",
        "dark_theme": "الوضع الداكن",
        "invite_friends": "دعوة الأصدقاء",
        "groups": "المجموعات",
        "calls": "المكالمات",
      },
      "hi": {
        ...english,
        "lang_name": "Hindi (हिंदी)",
        "language": "भाषा",
        "choose_a_language": "भाषा चुनें",
        "change_language": "भाषा बदलें",
        "chats": "चैट्स",
        "profile": "प्रोफ़ाइल",
        "settings": "सेटिंग्स",
        "dark_theme": "डार्क थीम",
        "invite_friends": "दोस्तों को आमंत्रित करें",
        "groups": "समूह",
        "calls": "कॉल",
      },
      "ur": {
        ...english,
        "lang_name": "Urdu (اردو)",
        "language": "زبان",
        "choose_a_language": "زبان کا انتخاب کریں",
        "change_language": "زبان تبدیل کریں",
        "chats": "چیٹس",
        "profile": "پروفائل",
        "settings": "ترتیبات",
        "dark_theme": "تاریک تھیم",
        "invite_friends": "دوستوں کو مدعو کریں",
        "groups": "گروپس",
        "calls": "کالز",
      },
      "ru": {
        ...english,
        "lang_name": "Russian (Русский)",
        "language": "Язык",
        "choose_a_language": "Выберите язык",
        "change_language": "Сменить язык",
        "chats": "Чаты",
        "profile": "Профиль",
        "settings": "Настройки",
      },
    };
  }
}
