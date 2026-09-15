// import 'package:dash_bubble/dash_bubble.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:chat_messenger/config/app_config.dart';
import 'package:chat_messenger/routes/app_pages.dart';
import 'package:chat_messenger/routes/app_routes.dart';

import 'controllers/preferences_controller.dart';
import 'firebase_options.dart';
import 'i18n/app_languages.dart';
import 'theme/app_theme.dart';
import 'package:chat_messenger/services/background_service.dart';
import 'package:chat_messenger/services/global_settings_service.dart';
import 'package:chat_messenger/services/deep_link_service.dart';
import 'package:chat_messenger/services/app_theme_service.dart';
import 'package:get_storage/get_storage.dart';
import 'package:chat_messenger/services/firebase_messaging_service.dart';
import 'package:chat_messenger/services/premium_room_service.dart';
import 'package:flutter/services.dart';
import 'package:chat_messenger/config/theme_config.dart';

bool isDebugMode() {
  bool inDebug = false;
  assert(inDebug = true);
  return inDebug;
}

final navigatorKey = Get.key;
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await GetStorage.init();
  } catch (e) {
    debugPrint('⚠️ GetStorage.init() error: $e');
  }
  MobileAds.instance.initialize();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  /// <-- Initialize Firebase App -->
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Initialize push notifications immediately so background handler is attached
    await FirebaseMessagingService.initFirebaseMessagingUpdates();

    // Initialize GlobalSettingsService for real-time app settings
    debugPrint('🔄 Initializing GlobalSettingsService...');
    await Get.putAsync(() => GlobalSettingsService().init());
    
    debugPrint('🔄 Initializing AppThemeService...');
    Get.put(AppThemeService());

    debugPrint('🔄 Initializing PremiumRoomService...');
    Get.put(PremiumRoomService(), permanent: true);

    debugPrint('🔄 Initializing DeepLinkService...');
    await Get.putAsync(() => DeepLinkService().init());

    try {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode ? AndroidDebugProvider() : AndroidPlayIntegrityProvider(),
        providerApple: kDebugMode ? AppleDebugProvider() : AppleAppAttestProvider(),
      );
      debugPrint('Firebase App Check initialized');
    } catch (e) {
      debugPrint('Firebase App Check initialization failed: $e');
    }
  } catch (e) {
    if (kDebugMode) {
      debugPrint('Firebase initialization error: $e');
    }
  }

//  if (isDebugMode()) {
//     FirebaseAppCheck.instance.onTokenChange.listen((token) {
//       debugPrint("Debug App Check Token: $token");
//     });
//   }

//   if (!isDebugMode()) {
//     // Activate App Check for release mode
//     await FirebaseAppCheck.instance.activate(
//       androidProvider: AndroidProvider.playIntegrity,
//       appleProvider: AppleProvider.appAttest,
//     );
//   } else {
//     // Use debug provider in debug mode
//     await FirebaseAppCheck.instance.activate(
//       androidProvider: AndroidProvider.debug,
//       appleProvider: AppleProvider.debug,
//     );
//   }
  // Initialize the Mobile Ads SDK
  // MobileAds.instance.initialize();

  // Future<void> requestOverlayPermission() async {
  //   bool isGranted = await DashBubble.instance.requestOverlayPermission();

  //   if (isGranted == true) {
  //     debugPrint('permission granted');
  //   } else {
  //     debugPrint('permission declined');
  //   }
  // }
//   Future<void> requestOverlayPermission2() async {
//   if (await Permission.systemAlertWindow.isGranted) {
//     debugPrint('Overlay permission already granted');
//   } else {
//     await Permission.systemAlertWindow.request();
//     debugPrint('Requesting overlay permission');
//   }
// }

  // requestOverlayPermission();
  // requestOverlayPermission2();

  // Initialize Background Service (handling notification channel creation)
  try {
    await BackgroundService().initialize();
  } catch (e) {
    debugPrint('Background Service initialization failed: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // @override
  // void initState() {
  //   super.initState();
  //   WidgetsBinding.instance.addObserver(this);
  // }

  // @override
  // void dispose() {
  //   WidgetsBinding.instance.removeObserver(this);
  //   super.dispose();
  // }

//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     super.didChangeAppLifecycleState(state);

//     if (state == AppLifecycleState.paused ||
//         state == AppLifecycleState.inactive) {
//           Future.delayed(const Duration(seconds: 2), () async{
//           bool isGranted = await Permission.systemAlertWindow.isGranted;

//     if (isGranted) {
//       debugPrint('permission granted2222222222222222');
//        startBubble(
//           bubbleOptions: BubbleOptions(
//               bubbleIcon: 'app_logo',
//               bubbleSize: 65,
//               distanceToClose: 80,
//               enableClose: true,
//               enableAnimateToEdge: true,
//               enableBottomShadow: true,

//               keepAliveWhenAppExit: true),
//           onTap: () {
//            handleBubbleTap();
//            // handleBubbleTap(context);
//             debugPrint('1111111111111');

//           });
//     } else {
//       debugPrint('permission declined');
//     }

//     });
//       // App is in the background

//     } else if (state == AppLifecycleState.resumed) {
//       // App is in the foreground
//       stopBubble();
//     }
//   }

//   // Method channel to communicate with native Android code
//  var platform = MethodChannel('com.imchatapp/app_visibility');

//   void handleBubbleTap() async {
//     try {
//       await platform.invokeMethod('bringToForeground');
//     } on PlatformException catch (e) {
//     //  debugPrint("Failed to bring app to foreground: '${e.message}'.");
//     }
//   }

//   Future<void> startBubble(
//       {BubbleOptions? bubbleOptions, VoidCallback? onTap}) async {
//    try {
//       final hasStarted = await DashBubble.instance
//         .startBubble(bubbleOptions: bubbleOptions, onTap: onTap);
//     if (hasStarted) {
//       debugPrint('bubble is started');
//     } else {
//       debugPrint('bubble is not started');
//     }
//    } catch (e) {
//      debugPrint(e.toString());
//    }
//   }

//   Future<void> stopBubble() async {
//     final hasStarted = await DashBubble.instance.stopBubble();
//     if (hasStarted == true) {
//       debugPrint('bubble stopped');
//     } else {
//       debugPrint('object');
//     }
//   }

// void handleBubbleTap(BuildContext context) async {
//   try {
//     final navigatorContext = Navigator.of(context).overlay?.context;
//     if (navigatorContext != null) {
//      showHalfScreenOverlay(context);
//     }else{
//       debugPrint('''''''''''''''object''''''''''''''');
//     }

//   } on PlatformException catch (e) {
//     debugPrint("Failed to show overlay: '${e.message}'.");
//   }
// }

// void showHalfScreenOverlay(BuildContext context) {
//   final ChatController chatController = Get.find();
//   // Get the chats list
//           final List<Chat> chats = chatController.isSearching.value
//               ? chatController.searchChat()
//               : chatController.chats;
//           final Chat chat = chats[0];
//           final User user = chat.receiver!;
//   // Create overlay entry
//   final overlay = Overlay.of(context, rootOverlay: true);
//   final overlayEntry = OverlayEntry(
//     builder: (context) => Positioned(
//       top: 170, // Align it to the bottom
//       left: 20,
//       right: 20,
//       height: MediaQuery.of(context).size.height / 1.7, // Half of the screen height
//       child: Material(
//         color: Colors.transparent,
//         shape: RoundedRectangleBorder(
//        borderRadius: BorderRadius.circular(20),
//         ),

//         elevation: 5, // Make the overlay semi-transparent
//         child: MessageScreen(isGroup: false,user: user,),
//       ),
//     ),
//   );

//   // Insert overlay entry
//   overlay.insert(overlayEntry);

//   // Close overlay after some time or on user action
//   Future.delayed(const Duration(seconds: 10), () {
//     overlayEntry.remove(); // Auto-remove the overlay after 5 seconds
//   });
// }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // Get preferences controller
      final preferencesController = Get.put(PreferencesController());
      // Get theme mode
      final bool isDarkMode = preferencesController.isDarkMode.value;

      // Dynamically update status bar / system navigation bar style based on theme
      SystemChrome.setSystemUIOverlayStyle(
        getSystemOverlayStyle(isDarkMode),
      );

      return GetMaterialApp(
        useInheritedMediaQuery: true,
        locale: preferencesController.locale.value,
        navigatorKey: navigatorKey,
        // Note: DevicePreview overrides locale, but fallback is useful
        fallbackLocale: const Locale('en'),
        translations: AppLanguages(),
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.of(context).lightTheme,
        darkTheme: AppTheme.of(context).darkTheme,
        themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
        initialRoute: AppRoutes.splash,
        getPages: AppPages.pages,
        // home: AdminPane(),
      );
    });
  }
}

