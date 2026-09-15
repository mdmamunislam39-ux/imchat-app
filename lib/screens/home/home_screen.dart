// import 'package:flutter/material.dart';
// import 'package:chat_messenger/api/user_api.dart';
// import 'package:chat_messenger/components/badge_indicator.dart';
// import 'package:chat_messenger/controllers/preferences_controller.dart';
// import 'package:chat_messenger/controllers/report_controller.dart';
// import 'package:chat_messenger/tabs/calls/components/clear_calls_button.dart';
// import 'package:chat_messenger/tabs/calls/controller/call_history_controller.dart';
// import 'package:chat_messenger/tabs/groups/controllers/group_controller.dart';
// import 'package:chat_messenger/tabs/stories/controller/story_controller.dart';
// import 'package:chat_messenger/theme/app_theme.dart';
// import 'package:chat_messenger/controllers/auth_controller.dart';
// import 'package:chat_messenger/config/app_config.dart';
// import 'package:chat_messenger/helpers/ads/ads_helper.dart';
// import 'package:chat_messenger/helpers/ads/banner_ad_helper.dart';
// import 'package:chat_messenger/models/user.dart';
// import 'package:chat_messenger/components/app_logo.dart';
// import 'package:chat_messenger/components/cached_circle_avatar.dart';
// import 'package:chat_messenger/routes/app_routes.dart';
// import 'package:chat_messenger/tabs/chats/controllers/chat_controller.dart';
// import 'package:chat_messenger/services/firebase_messaging_service.dart';
// import 'package:chat_messenger/config/theme_config.dart';
// import 'package:flutter_iconly/flutter_iconly.dart';
// import 'package:get/get.dart';

// import 'components/search_chat_input.dart';
// import 'controller/home_controller.dart';

// class HomeScreen extends StatefulWidget {
//   const HomeScreen({super.key});

//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }

// class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
//   @override
//   void initState() {
//     // Init other controllers
//     Get.put(ReportController(), permanent: true);
//     Get.put(PreferencesController(), permanent: true);

//     // Load Ads
//    // AdsHelper.loadAds(interstitial: false);

//     // Listen to incoming firebase push notifications
//     FirebaseMessagingService.initFirebaseMessagingUpdates();

//     // Update user presence
//     UserApi.updateUserPresenceInRealtimeDb();

//     WidgetsBinding.instance.addObserver(this);
//     super.initState();
//   }

//   @override
//   void dispose() {
//     WidgetsBinding.instance.removeObserver(this);
//     super.dispose();
//   }

//   // <-- Handle the user presence -->
//   @override
//   void didChangeAppLifecycleState(AppLifecycleState state) {
//     super.didChangeAppLifecycleState(state);
//     switch (state) {
//       case AppLifecycleState.resumed:
//         // Set User status Online
//         UserApi.updateUserPresence(true);
//         break;
//       case AppLifecycleState.inactive:
//       case AppLifecycleState.paused:
//       case AppLifecycleState.detached:
//       case AppLifecycleState.hidden:
//         // Set User status Offline
//         UserApi.updateUserPresence(false);
//         break;
//     }
//   }
//   // END

//   @override
//   Widget build(BuildContext context) {
//     // Get Controllers
//     final HomeController homeController = Get.find();
//     final ChatController chatController = Get.find();
//     final GroupController groupController = Get.find();
//     final CallHistoryController callController = Get.find();
//     final StoryController storyController = Get.find();

//     // Others
//     final bool isDarkMode = AppTheme.of(context).isDarkMode;
//     final Color color = isDarkMode ? primaryColor : Colors.white;

//     return Obx(() {
//       // Get page index
//       final int pageIndex = homeController.pageIndex.value;
//       // Get current user
//       final User currentUer = AuthController.instance.currentUser;

//       return Scaffold(
//         appBar: AppBar(
//           centerTitle: false,
//           toolbarHeight: pageIndex == 0 ? 80 : 65,
//           title: Row(
//             children: [
//               // App logo
//               AppLogo(width: 35, height: 35),
//               const SizedBox(width: 16),
//               // App name
//               Text(
//                 AppConfig.appName,
//                 style: Theme.of(context)
//                     .textTheme
//                     .titleLarge!
//                     .copyWith(color: color, fontSize: 20),
//               ),
//             ],
//           ),
//           actions: [
//             // Change Theme Mode
//             if (pageIndex == 0)
//               Padding(
//                 padding: const EdgeInsets.only(right: 8),
//                 child: IconButton(
//                   onPressed: () =>
//                       PreferencesController.instance.isDarkMode.toggle(),
//                   icon: const Icon(Icons.brightness_6, color: Colors.white),
//                 ),
//               ),

//             // Clear call log
//             if (pageIndex == 3) const ClearCallsButton(),

//             // Go to session page
//             if (pageIndex == 4)
//               Padding(
//                 padding: const EdgeInsets.only(right: 8),
//                 child: IconButton(
//                   onPressed: () => Get.toNamed(AppRoutes.session),
//                   icon: const Icon(IconlyLight.logout, color: Colors.white),
//                 ),
//               ),
//           ],
//         ),
//         body: SafeArea(
//           child: Column(
//             children: [
//               // Search Chats
//               if (pageIndex == 0) const SearchChatInput(),
//               // Show Banner Ad
//               if (pageIndex != 0)
//               //  BannerAdHelper.showBannerAd(margin: pageIndex == 1 ? 8 : 0),
//               // Show the body content
//               Expanded(child: homeController.pages[pageIndex]),
//             ],
//           ),
//         ),

//         bottomNavigationBar: BottomNavigationBar(
//           currentIndex: pageIndex,
//           onTap: (int index) {
//             homeController.pageIndex.value = index;
//             // View stories
//             if (index == 2) {
//               storyController.viewStories();
//             }
//             // View calls
//             if (index == 3) {
//               callController.viewCalls();
//             }
//           },
//           type: BottomNavigationBarType.fixed,
//           items: [
//             // Chats
//             BottomNavigationBarItem(
//               label: 'chats'.tr,
//               icon: BadgeIndicator(
//                 icon: pageIndex == 0 ? IconlyBold.chat : IconlyLight.chat,
//                 isNew: chatController.newMessage,
//               ),
//             ),
//             // Groups
//             BottomNavigationBarItem(
//               label: 'groups'.tr,
//               icon: BadgeIndicator(
//                 icon: pageIndex == 1 ? IconlyBold.user3 : IconlyLight.user3,
//                 isNew: groupController.newMessage,
//               ),
//             ),
//             // Stories
//             BottomNavigationBarItem(
//               label: 'stories'.tr,
//               icon: BadgeIndicator(
//                 icon: IconlyBold.play,
//                 isNew: storyController.hasUnviewedStories,
//                 iconSize: 45,
//                 iconColor: primaryColor,
//               ),
//             ),
//             // Calls
//             BottomNavigationBarItem(
//               label: 'calls'.tr,
//               icon: BadgeIndicator(
//                 icon: pageIndex == 3 ? IconlyBold.call : IconlyLight.call,
//                 isNew: callController.newCalls.isNotEmpty,
//               ),
//             ),
//             // Profile account
//             BottomNavigationBarItem(
//               label: 'profile'.tr,
//               icon: CachedCircleAvatar(
//                 imageUrl: currentUer.photoUrl,
//                 iconSize: currentUer.photoUrl.isEmpty ? 22 : null,
//                 borderColor: pageIndex == 4
//                     ? primaryColor
//                     : primaryColor.withValues(alpha: 0.5),
//                 radius: 12,
//               ),
//             ),
//           ],
//         ),
//       );
//     });
//   }
// }

import 'dart:async';
import 'dart:io';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:chat_messenger/api/user_api.dart';
import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/controllers/preferences_controller.dart';
import 'package:chat_messenger/controllers/report_controller.dart';
import 'package:chat_messenger/models/call.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/audio_rooms_v2_integration.dart';
import 'package:chat_messenger/screens/audio_rooms_v2/audio_rooms_v2_screen.dart';
import 'package:chat_messenger/screens/calling/components/call_timer.dart';
import 'package:chat_messenger/screens/calling/incoming_call_screen.dart';
import 'package:chat_messenger/screens/calling/controller/call_controller.dart';
import 'package:chat_messenger/screens/calling/video_call_screen.dart';
import 'package:chat_messenger/screens/calling/voice_call_screen.dart';
import 'package:chat_messenger/screens/contacts/contacts_screen.dart';
import 'package:chat_messenger/screens/contacts/number_search.dart';

import 'package:chat_messenger/tabs/chats/chats_screen.dart';
import 'package:chat_messenger/tabs/chats/controllers/chat_controller.dart';
import 'package:chat_messenger/tabs/groups/screens/group_video_call.dart';
import 'package:chat_messenger/tabs/groups/screens/groups_screen.dart';
import 'package:chat_messenger/tabs/profile/profile_screen.dart';
import 'package:chat_messenger/tabs/stories/stories_screen.dart';
import 'package:chat_messenger/tabs/stories/add_story_screen.dart';
import 'package:chat_messenger/tabs/stories/controller/story_controller.dart';
import 'package:chat_messenger/theme/app_theme.dart';
import 'package:chat_messenger/routes/app_routes.dart';
import 'package:chat_messenger/services/firebase_messaging_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'controller/home_controller.dart';
import 'package:chat_messenger/services/global_settings_service.dart';
import 'package:chat_messenger/screens/news_feed/news_feed_screen.dart';
import 'package:chat_messenger/services/app_theme_service.dart';
import 'package:chat_messenger/services/deep_link_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:chat_messenger/screens/room/wallet_screen.dart';
import 'package:chat_messenger/screens/room/roomprofile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.passController, this.routeVideo});

  final CallController? passController;
  final String? routeVideo;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late TabController _tabController;
  final RxInt _currentTabIndex = 0.obs;

  //check app-version
  var box = GetStorage();
  void getAppVersion() {
    //version - collection
    CollectionReference collectionReference =
        FirebaseFirestore.instance.collection('version');
    var version = box.read('version');
    collectionReference.doc('000000').get().then((value) {
      bool androidUpdate = value['android_update'];
      bool iosUpdate = value['ios_update'];
      String androidVersion = value['android_version'];
      String iosVersion = value['ios_version'];

      if (Platform.isIOS && version != iosVersion) {
        return showDialog(
            barrierDismissible: iosUpdate == true ? false : true,
            context: context,
            builder: (context) {
              if (!mounted) return const SizedBox.shrink();
              return Dialog(
                child: SizedBox(
                  height: 160,
                  child: Padding(
                    padding: const EdgeInsets.all(15.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Text(
                          'Update App Version',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w600),
                        ),
                        Text(
                            'A new version of the app has arrived please update now to continue'),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: ElevatedButton(
                              onPressed: () async {
                                try {
                                  final url = Uri.parse('iosAppUrl');
                                  if (await canLaunchUrl(url)) {
                                    await launchUrl(url,
                                        mode: LaunchMode.externalApplication);
                                  }
                                } catch (e) {
                                  SnackBar(content: Text(e.toString()));
                                }
                              },
                              child: Text('Continue')),
                        )
                      ],
                    ),
                  ),
                ),
              );
            });
      } else {
        if (Platform.isAndroid && version != androidVersion) {
          return showDialog(
              //barrierDismissible: true,
              barrierDismissible: androidUpdate == true ? false : true,
              context: context,
              builder: (context) {
                if (!mounted) return const SizedBox.shrink();
                return Dialog(
                  child: SizedBox(
                    height: 180,
                    child: Padding(
                      padding: const EdgeInsets.all(15.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Text(
                            'Update App Version',
                            style: TextStyle(
                                fontSize: 20, fontWeight: FontWeight.w600),
                          ),
                          Text(
                              'A new version of the app has arrived please update now to continue'),
                          Align(
                            alignment: Alignment.bottomRight,
                            child: ElevatedButton(
                                onPressed: () async {
                                  try {
                                    final url = Uri.parse('androidAppUrl');
                                    if (await canLaunchUrl(url)) {
                                      await launchUrl(url,
                                          mode: LaunchMode.externalApplication);
                                    }
                                  } catch (e) {
                                    SnackBar(content: Text(e.toString()));
                                  }
                                },
                                child: Text('Continue')),
                          )
                        ],
                      ),
                    ),
                  ),
                );
              });
        }
      }
    });
  }

// check my story
  Future<String?> checkMyStory() async {
    try {
      // Get the current user
      final User currentUser = AuthController.instance.currentUser;

      // Fetch the document for the current user's stories
      DocumentSnapshot docSnapshot = await FirebaseFirestore.instance
          .collection('Stories')
          .doc(currentUser.userId)
          .get();

      // Check if document exists and has data
      if (docSnapshot.exists && docSnapshot.data() != null) {
        var data = docSnapshot.data() as Map<String, dynamic>;
        var images = data['images'];

        // Ensure 'images' is a valid list and has at least one element
        if (images is List && images.isNotEmpty) {
          // Get the last image URL
          var storyUrl = images[images.length - 1]['imageUrl'];
          return storyUrl; // Return the story URL
        } else {
          debugPrint('No images found');
          return null;
        }
      } else {
        debugPrint('No story found for the current user');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching story: $e');
      return null;
    }
  }

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      _currentTabIndex.value = _tabController.index;
      if (mounted) setState(() {});
    });
    // Init other controllers
    Get.put(ReportController(), permanent: true);
    Get.put(PreferencesController(), permanent: true);
    // Load Ads
    // AdsHelper.loadAds(interstitial: false);

    // Listen to incoming firebase push notifications
    FirebaseMessagingService.initFirebaseMessagingUpdates();

    // Update user presence
    UserApi.updateUserPresenceInRealtimeDb();

    // Commented out to prevent the update dialog during development
    // getAppVersion();

    _listenToCallState();

    // Check and process any pending deep links (e.g. room, post, or event)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      DeepLinkService.checkPendingDeepLinks();
    });

    // Request Permissions
    _requestAppPermissions();

    super.initState();
  }

  Future<void> _requestAppPermissions() async {
    // Request only the essential permissions on startup
    await [
      Permission.notification,
      Permission.microphone,
      Permission.location,
      Permission.photos,
      Permission.videos,
      Permission.camera,
    ].request();
  }

  @override
  void dispose() {
    _tabController.dispose();
    callSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // <-- Handle the user presence -->
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    switch (state) {
      case AppLifecycleState.resumed:
        // Set User status Online
        UserApi.updateUserPresence(true);
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // Set User status Offline
        UserApi.updateUserPresence(false);
        break;
    }
  }
  // END

  // exit app
  Future<bool> _onWillPop() async {
    if (_tabController.index != 0) {
      // If not on the chat tab
      _tabController.animateTo(0); // Switch to the chat tab (index 1)
      return Future.value(false); // Prevent exiting the app
    } else {
      // Show exit confirmation dialog when on the chat tab
      return (await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text('Exit App?'),
              content: Text('Do you want to exit the app?'),
              actions: <Widget>[
                TextButton(
                  child: Text('No'),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                TextButton(
                  child: Text('Yes'),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            ),
          )) ??
          false;
    }
  }

  // Firestore listener stream
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? callSubscription;

  RxString callState = ''.obs;
  RxString groupcallState = ''.obs;

  void _listenToCallState() async {
    // Listen to Firestore changes
    try {
      Map<String, dynamic>? callData = box.read('callIsActive'); // Nullable map

// Check if callData is null or empty before converting to Call object
      if (callData != null && callData.isNotEmpty) {
        Call call = Call.fromMap(data: callData);

        // Proceed with the Firebase listener
        callSubscription = FirebaseFirestore.instance
            .collection('Calls')
            .doc(call.effectiveChannelName)
            .snapshots()
            .listen((snapshot) {
          if (!snapshot.exists) {
            callState.value = '';
            box.remove('callIsActive');
            return;
          }
          // Get the 'state' field from Firestore document safely
          String? state = snapshot.data()?['state']; // Nullable
          if (state != null) {
            callState.value = state; // Update the observable state

            // Perform actions based on state value
            if (state == 'decline' || state == 'ended' || state == 'missed' || state == 'cancel') {
              callState.value = '';
              box.remove('callIsActive');
            }
          }
        });
      } else {
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  void groupCallState() async {
    // Listen to Firestore changes
    try {
      Map<String, dynamic>? callData =
          box.read('groupIsActive'); // Nullable map

// Check if callData is null or empty before converting to Call object
      if (callData != null && callData.isNotEmpty) {
        Call call = Call.fromMap(data: callData);

        // Proceed with the Firebase listener
        callSubscription = FirebaseFirestore.instance
            .collection('GroupCalls')
            .doc(call.effectiveChannelName)
            .snapshots()
            .listen((snapshot) {
          if (!snapshot.exists) {
            groupcallState.value = '';
            box.remove('groupIsActive');
            return;
          }
          // Get the 'state' field from Firestore document safely
          String? state = snapshot.data()?['state']; // Nullable
          if (state != null) {
            groupcallState.value = state; // Update the observable state

            // Perform actions based on state value
            if (state == 'decline' || state == 'ended' || state == 'missed' || state == 'cancel') {
              groupcallState.value = '';
              box.remove('groupIsActive');
            }
          }
        });
      } else {}
    } catch (e) {
      debugPrint('444444444');
      debugPrint(e.toString());
      debugPrint('44444444');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get Controllers
    final HomeController homeController = Get.find();
    final StoryController storyController = Get.find();

    // Others
    final bool isDarkMode = AppTheme.of(context).isDarkMode;

    return Obx(() {
      final GlobalSettingsService settingsService =
          Get.find<GlobalSettingsService>();
      final AppThemeService themeService = Get.find<AppThemeService>();

      // Track tab bar icon URLs and screen themes in the outer Obx to force TabBar rebuilds in real-time
      final _ = [
        themeService.tabChatIconUrl.value,
        themeService.tabHomeIconUrl.value,
        themeService.tabGlobeIconUrl.value,
        themeService.tabContactsIconUrl.value,
        themeService.searchIconUrl.value,
        themeService.trophyIconUrl.value,
        themeService.screenBgColors.values.toList(),
        themeService.screenTextColors.values.toList(),
        themeService.screenSecondaryTextColors.values.toList(),
        themeService.screenBgUrls.values.toList(),
      ];

      if (settingsService.maintenanceMode.value) {
        return Scaffold(
          backgroundColor: const Color(0xFF0F0F1A),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.amberAccent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.construction,
                      color: Colors.amberAccent,
                      size: 80,
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'App Under Maintenance',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'We are performing scheduled maintenance to improve your experience. Please check back later.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 16,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      }

      // for one to one call
      Map<String, dynamic> callData = box.read('callIsActive') ?? {};
      // Convert the Map to Call object
      Call call = Call.fromMap(data: callData);
      // for group call
      Map<String, dynamic> callDataForgroupCall =
          box.read('groupIsActive') ?? {};
      // Convert the Map to Call object
      Call groupCall = Call.fromMap(data: callDataForgroupCall);

      final int pageIndex = homeController.pageIndex.value;
      // Get current user
      final User currentUer = AuthController.instance.currentUser;

      final String currentScreenKey = _currentTabIndex.value == 1
          ? 'room'
          : (pageIndex == 4 ? 'profile' : 'home');
      final String? currentBgUrl =
          themeService.getScreenBgUrl(currentScreenKey);
      final Color? currentBgColor =
          themeService.getScreenColor(currentScreenKey);
      final bool isLightScreenBg = currentBgColor != null
          ? (currentBgColor.computeLuminance() > 0.5)
          : (!isDarkMode && _currentTabIndex.value != 1);

      final Color? currentTextColor =
          themeService.getScreenTextColor(currentScreenKey) ??
              (isLightScreenBg ? Colors.black87 : Colors.white);
      final Color? currentSecondaryTextColor =
          themeService.getScreenSecondaryTextColor(currentScreenKey) ??
              (isLightScreenBg ? Colors.black54 : Colors.grey);

      return WillPopScope(
        onWillPop: _onWillPop,
        child: Container(
          decoration: (currentBgUrl != null && currentBgUrl.isNotEmpty)
              ? BoxDecoration(
                  image: DecorationImage(
                    image: CachedNetworkImageProvider(currentBgUrl),
                    fit: BoxFit.cover,
                  ),
                )
              : null,
          child: Scaffold(
            backgroundColor: (currentBgUrl != null && currentBgUrl.isNotEmpty)
                ? Colors.transparent
                : (_currentTabIndex.value == 1
                    ? (currentBgColor ?? const Color(0xFF120C1C))
                    : (currentBgColor ??
                        (isDarkMode ? Colors.black : Colors.white))),
            appBar: AppBar(
              systemOverlayStyle: isLightScreenBg
                  ? SystemUiOverlayStyle.dark
                  : SystemUiOverlayStyle.light,
              backgroundColor: _currentTabIndex.value == 1
                  ? Colors.transparent
                  : (isDarkMode ? Colors.black : Colors.white),
              elevation: 0,
              automaticallyImplyLeading: false,
              title: Row(
                children: [
                  InkWell(
                    onTap: () {
                      if (_currentTabIndex.value == 1) {
                        Get.to(() => UserWalletScreen(currentUser: currentUer));
                      } else if (_currentTabIndex.value == 0) {
                        Get.to(() => ProfileScreen());
                      } else {
                        Get.to(() => ProfilePageForRoom(
                              userID: currentUer.userId,
                              userName: currentUer.fullname,
                              userImage: currentUer.photoUrl,
                            ));
                      }
                    },
                    child: CachedCircleAvatar(
                      imageUrl: currentUer.photoUrl,
                      iconSize: currentUer.photoUrl.isEmpty ? 22 : null,
                      borderColor: pageIndex == 4
                          ? primaryColor
                          : primaryColor.withValues(alpha: 0.5),
                      radius: 18,
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: currentTextColor ??
                          ((_currentTabIndex.value == 1 || isDarkMode)
                              ? Colors.white
                              : primaryColor),
                      dividerColor: Colors.transparent,
                      labelColor: currentTextColor ??
                          ((_currentTabIndex.value == 1 || isDarkMode)
                              ? Colors.white
                              : Colors.black),
                      unselectedLabelColor:
                          currentSecondaryTextColor ?? Colors.grey,
                      indicatorWeight: 5,
                      indicatorSize: TabBarIndicatorSize.tab,
                      tabs: [
                        Tab(
                          icon: Obx(() {
                            final chatCtrl = Get.isRegistered<ChatController>()
                                ? Get.find<ChatController>()
                                : null;
                            final unread = chatCtrl?.totalUnreadCount ?? 0;
                            
                            final bool isSelected = _currentTabIndex.value == 0;
                            final double iconSize = isSelected ? 38.0 : 30.0;
                            
                            final customIconUrl = themeService.tabChatIconUrl.value;
                            final iconWidget = customIconUrl.isNotEmpty
                                ? Opacity(
                                    opacity: isSelected ? 1.0 : 0.6,
                                    child: CachedNetworkImage(
                                      imageUrl: customIconUrl,
                                      width: iconSize,
                                      height: iconSize,
                                      fit: BoxFit.contain,
                                      placeholder: (context, url) => SizedBox(
                                        width: iconSize,
                                        height: iconSize,
                                        child: const Center(
                                          child: SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 1.5),
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) {
                                        final Color fallbackColor = isSelected
                                            ? (currentTextColor ??
                                                (isLightScreenBg ? Colors.black87 : Colors.white))
                                            : (currentSecondaryTextColor ?? Colors.grey);
                                        return Icon(Icons.chat, size: iconSize, color: fallbackColor);
                                      },
                                    ),
                                  )
                                : Icon(
                                    Icons.chat, 
                                    size: iconSize, 
                                    color: isSelected
                                        ? (currentTextColor ??
                                            ((_currentTabIndex.value == 1 || isDarkMode)
                                                ? Colors.white
                                                : Colors.black))
                                        : (currentSecondaryTextColor ?? Colors.grey),
                                  );

                            return Stack(
                              clipBehavior: Clip.none,
                              children: [
                                iconWidget,
                                if (unread > 0)
                                  Positioned(
                                    top: -6,
                                    right: -8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      constraints: const BoxConstraints(
                                          minWidth: 18, minHeight: 18),
                                      child: Text(
                                        unread > 99 ? '99+' : '$unread',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          }),
                        ),
                        Tab(
                          icon: Obx(() {
                            final bool isSelected = _currentTabIndex.value == 1;
                            final double iconSize = isSelected ? 38.0 : 30.0;

                            final customIconUrl = themeService.tabHomeIconUrl.value;
                            return customIconUrl.isNotEmpty
                                ? Opacity(
                                    opacity: isSelected ? 1.0 : 0.6,
                                    child: CachedNetworkImage(
                                      imageUrl: customIconUrl,
                                      width: iconSize,
                                      height: iconSize,
                                      fit: BoxFit.contain,
                                      placeholder: (context, url) => SizedBox(
                                        width: iconSize,
                                        height: iconSize,
                                        child: const Center(
                                          child: SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 1.5),
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) {
                                        final Color fallbackColor = isSelected
                                            ? (currentTextColor ??
                                                (isLightScreenBg ? Colors.black87 : Colors.white))
                                            : (currentSecondaryTextColor ?? Colors.grey);
                                        return Icon(CupertinoIcons.house_fill, size: iconSize, color: fallbackColor);
                                      },
                                    ),
                                  )
                                : Icon(
                                    CupertinoIcons.house_fill,
                                    size: iconSize,
                                    color: isSelected
                                        ? (currentTextColor ??
                                            ((_currentTabIndex.value == 1 || isDarkMode)
                                                ? Colors.white
                                                : Colors.black))
                                        : (currentSecondaryTextColor ?? Colors.grey),
                                  );
                          }),
                        ),
                        Tab(
                          icon: Obx(() {
                            final bool isSelected = _currentTabIndex.value == 2;
                            final double iconSize = isSelected ? 38.0 : 30.0;

                            final customIconUrl = themeService.tabGlobeIconUrl.value;
                            return customIconUrl.isNotEmpty
                                ? Opacity(
                                    opacity: isSelected ? 1.0 : 0.6,
                                    child: CachedNetworkImage(
                                      imageUrl: customIconUrl,
                                      width: iconSize,
                                      height: iconSize,
                                      fit: BoxFit.contain,
                                      placeholder: (context, url) => SizedBox(
                                        width: iconSize,
                                        height: iconSize,
                                        child: const Center(
                                          child: SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 1.5),
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) {
                                        final Color fallbackColor = isSelected
                                            ? (currentTextColor ??
                                                (isLightScreenBg ? Colors.black87 : Colors.white))
                                            : (currentSecondaryTextColor ?? Colors.grey);
                                        return Icon(CupertinoIcons.globe, size: iconSize, color: fallbackColor);
                                      },
                                    ),
                                  )
                                : Icon(
                                    CupertinoIcons.globe,
                                    size: iconSize,
                                    color: isSelected
                                        ? (currentTextColor ??
                                            ((_currentTabIndex.value == 1 || isDarkMode)
                                                ? Colors.white
                                                : Colors.black))
                                        : (currentSecondaryTextColor ?? Colors.grey),
                                  );
                          }),
                        ),
                        Tab(
                          icon: Obx(() {
                            final bool isSelected = _currentTabIndex.value == 3;
                            final double iconSize = isSelected ? 38.0 : 30.0;

                            final customIconUrl = themeService.tabContactsIconUrl.value;
                            return customIconUrl.isNotEmpty
                                ? Opacity(
                                    opacity: isSelected ? 1.0 : 0.6,
                                    child: CachedNetworkImage(
                                      imageUrl: customIconUrl,
                                      width: iconSize,
                                      height: iconSize,
                                      fit: BoxFit.contain,
                                      placeholder: (context, url) => SizedBox(
                                        width: iconSize,
                                        height: iconSize,
                                        child: const Center(
                                          child: SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 1.5),
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) {
                                        final Color fallbackColor = isSelected
                                            ? (currentTextColor ??
                                                (isLightScreenBg ? Colors.black87 : Colors.white))
                                            : (currentSecondaryTextColor ?? Colors.grey);
                                        return Icon(Icons.contacts, size: iconSize, color: fallbackColor);
                                      },
                                    ),
                                  )
                                : Icon(
                                    Icons.contacts,
                                    size: iconSize,
                                    color: isSelected
                                        ? (currentTextColor ??
                                            ((_currentTabIndex.value == 1 || isDarkMode)
                                                ? Colors.white
                                                : Colors.black))
                                        : (currentSecondaryTextColor ?? Colors.grey),
                                  );
                          }),
                        ),
                      ],
                    ),
                  ),
                  // Settings Icon
                ],
              ),
            ),
            body: Theme(
              data: Theme.of(context).copyWith(
                textTheme: currentTextColor != null
                    ? Theme.of(context).textTheme.apply(
                        bodyColor: currentTextColor,
                        displayColor: currentTextColor,
                      )
                    : null,
              ),
              child: SafeArea(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Chats Screen
                    Column(
                      children: [
                        Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: 100,
                            child: InkWell(
                                onTap: () {
                                  Get.to(() => const AddStoryScreen());
                                },
                                child: _buildStoryItem(
                                    "Add a story", Icons.camera_alt)),
                          ),
                          Expanded(
                              child: SizedBox(
                                  height: 100, child: StoriesScreen())),
                        ],
                      ),
                      // const HomeEventBanner(), // Removed as requested: Events should not show here by default
                      // if (box.read('callIsActive') == true)
                      //   InkWell(
                      //     onTap: () {
                      // Call? getCallFromStorage() {
                      //   final Map<String, dynamic>? storedCallData = box
                      //       .read('call'); // Retrieve the map from storage
                      //   if (storedCallData != null) {
                      //     return Call.fromMap(
                      //         data:
                      //             storedCallData); // Convert the map back to a Call object
                      //   }
                      //   return null; // Return null if no call data is found
                      // }

                      // void fetchCallDetails() {
                      //   Call? savedCall = getCallFromStorage();
                      //   if (savedCall != null) {
                      //     debugPrint(
                      //         'Retrieved Call: ${savedCall.callerName} is calling ${savedCall.receiverName}');
                      //   } else {
                      //     debugPrint('No call details found in storage');
                      //   }
                      // }

                      // Get.toNamed(AppRoutes.voiceCall, arguments: {
                      //   'call': box.read('call'),
                      // });
                      // fetchCallDetails();
                      //   },
                      //   child: Container(
                      //     height: 25,
                      //     width: double.maxFinite,
                      //     color: Colors.green,
                      //     child: Text('Tap to return call'),
                      //   ),
                      // ),
                      if (groupcallState.value == 'running')
                        Container(
                          height: 40,
                          width: double.maxFinite,
                          color: Colors.green,
                          child: Center(
                              child: InkWell(
                            onTap: () {
                              Get.to(() => GroupCallScreen(
                                  isVideo: groupCall.isVideo, call: groupCall));
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.call),
                                SizedBox(
                                  width: 15,
                                ),
                                Text('Tap to return call'),
                                CallTimerForGroupCall(),
                              ],
                            ),
                          )),
                        ),
                      Expanded(flex: 5, child: ChatsScreen()),

                      bottomBar()
                    ],
                  ),
                  // Voice Room Explore Screen (Replacing GroupsScreen)
                  Obx(() => Get.find<GlobalSettingsService>()
                          .isVoiceRoomEnabled
                          .value
                      ? const AudioRoomsV2Screen(showAppBar: false)
                      : const Center(
                          child: Text(
                            'Voice Rooms are currently disabled by the Admin',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )),

                  // News Feed Screen (Placed exactly between Explore and Contacts)
                  const NewsFeedScreen(),

                  // Calls Screen Placeholder
                  Column(
                    children: [
                      Expanded(child: const ContactsScreen()),
                      bottomBar()
                    ],
                  )
                ],
              ),
            ),
          ),
          floatingActionButton: (widget.routeVideo == 'video' &&
                  widget.passController != null)
                ? SizedBox(
                    height: 200,
                    width: 200,
                    child: InkWell(
                      onTap: () {
                        Get.to(() => VideoCallScreen(call: call));
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          AgoraVideoView(
                            controller: VideoViewController.remote(
                              rtcEngine: widget.passController!.engine,
                              canvas: VideoCanvas(
                                uid: widget.passController!.remoteUid.value,
                                // uid: controller.remoteUid.value,
                              ),
                              connection: RtcConnection(
                                  // channelId: call.callerId
                                  channelId: widget.passController?.call.effectiveChannelName ?? 'abcd1'),
                            ),
                          ),
                          Positioned(
                            child: Center(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  IconButton(
                                    icon: Icon(Icons.zoom_out_map,
                                        color: Colors.white, size: 30),
                                    onPressed: () {
                                      Get.to(() => VideoCallScreen(call: call));
                                    },
                                  ),
                                  SizedBox(
                                    height: 20,
                                  ),
                                  CallTimer(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : Obx(() {
                    //  _listenToCallState();

                    if (callState.value == 'calling') {
                      if (call.receiverId == currentUer.userId) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 60),
                          child: FloatingActionButton.extended(
                              onPressed: () {
                                Get.to(() => IncommingCallScreen(call: call));
                              },
                              label: Text('Tap to view Call',
                                  style: TextStyle(color: Colors.white))),
                        );
                      } else {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 60),
                          child: FloatingActionButton.extended(
                              onPressed: () {
                                if (call.isVideo) {
                                  Get.to(() => VideoCallScreen(call: call));
                                } else {
                                  Get.to(() => VoiceCallScreen(call: call));
                                }
                              },
                              label: Text('Call Ringing',
                                  style: TextStyle(color: Colors.white))),
                        );
                      }
                    } else if (callState.value == 'running' &&
                            call.callerId == currentUer.userId ||
                        call.receiverId == currentUer.userId) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 60),
                        child: FloatingActionButton.extended(
                            backgroundColor: primaryColor,
                            onPressed: () {
                              if (call.isVideo) {
                                Get.to(() => VideoCallScreen(call: call));
                              } else {
                                Get.to(() => VoiceCallScreen(call: call));
                              }
                            },
                            label: Column(
                              children: [
                                CallTimer(),
                                Text(
                                  'Call Active',
                                  style: TextStyle(color: Colors.white),
                                ),
                              ],
                            )),
                      );
                    } else {
                      return SizedBox.shrink();
                    }
                  }),
          ),
        ),
      );
    });
  }

  Widget bottomBar() {
    return Align(
      alignment: Alignment.bottomCenter,
      child: SizedBox(
        height: 60,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) {
                        return Container(
                          height: 300,
                          width: double.maxFinite, // Takes full width
                          padding: EdgeInsets.all(6),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 6, right: 6),
                                child: Align(
                                  alignment: Alignment.topRight,
                                  child: InkWell(
                                    onTap: () => Get.back(),
                                    child: CircleAvatar(
                                        backgroundColor: primaryColor,
                                        radius: 14,
                                        child: Center(
                                            child: Icon(
                                          Icons.close,
                                          size: 20,
                                        ))),
                                  ),
                                ),
                              ),
                              IconButton(
                                  onPressed: () {
                                    Get.back(); // Close the modal first
                                    AudioRoomsV2Integration
                                        .navigateToAudioRooms();
                                  },
                                  icon: Row(
                                    children: [
                                      Icon(
                                        Icons.voice_chat,
                                        size: 20,
                                      ),
                                      SizedBox(
                                        width: 10,
                                      ),
                                      Text('Audio Rooms v2')
                                    ],
                                  )),
                              IconButton(
                                  onPressed: () {
                                    Get.to(() => GroupsScreen());
                                  },
                                  icon: Row(
                                    children: [
                                      Icon(
                                        Icons.group_add,
                                        size: 20,
                                      ),
                                      SizedBox(
                                        width: 10,
                                      ),
                                      Text('New Group')
                                    ],
                                  )),
                              IconButton(
                                  onPressed: () {
                                    Get.to(() => NumberSearchScreen());
                                  },
                                  icon: Row(
                                    children: [
                                      Icon(
                                        Icons.person_add,
                                        size: 20,
                                      ),
                                      SizedBox(
                                        width: 10,
                                      ),
                                      Text('Add Friends')
                                    ],
                                  )),
                              IconButton(
                                  onPressed: () {
                                    Get.back();
                                    Get.toNamed(AppRoutes.contacts);
                                  },
                                  icon: Row(
                                    children: [
                                      Icon(
                                        Icons.contacts,
                                        size: 20,
                                      ),
                                      SizedBox(
                                        width: 10,
                                      ),
                                      Text('My Friends')
                                    ],
                                  )),
                              IconButton(
                                  onPressed: () {
                                    Get.to(() => ProfileScreen());
                                  },
                                  icon: Row(
                                    children: [
                                      Icon(
                                        Icons.menu,
                                        size: 20,
                                      ),
                                      SizedBox(
                                        width: 10,
                                      ),
                                      Text('More')
                                    ],
                                  )),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  icon: Icon(
                    Icons.add,
                    size: 32,
                    color: primaryColor,
                  )),
              IconButton(
                  onPressed: () {
                    Get.toNamed(AppRoutes.contactSearch);
                  },
                  icon: Icon(
                    Icons.search,
                    size: 32,
                    color: primaryColor,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  // Single story item widget
  Widget _buildStoryItem(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          CircleAvatar(
            backgroundColor: primaryColor,
            radius: 30,
            child: Icon(
              icon,
              size: 30,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 5),
          Text(title, style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }

  //  Widget story() {
  //   return FutureBuilder<String?>(
  //     future: checkMyStory(),
  //     builder: (context, snapshot) {
  //       if (snapshot.connectionState == ConnectionState.waiting) {
  //         return CircularProgressIndicator(); // Show loading while waiting for data
  //       } else if (snapshot.hasError) {
  //         return Text('Error loading story');
  //       } else {
  //         // Ternary operation for checking the story
  //         return snapshot.data != null
  //             ? Padding(
  //               padding: const EdgeInsets.all(8.0),
  //               child: Column(
  //                 children: [
  //                   ClipRRect(
  //                     borderRadius: BorderRadius.circular(99),
  //                     child: CircleAvatar(
  //                       radius: 30,
  //                       child: Image.network(snapshot.data!,))),
  //                   SizedBox(height: 5),
  //                         Text('My Story', style: TextStyle(fontSize: 12)),
  //                 ],
  //               ),
  //             ) // Show the image if storyUrl exists
  //             : _buildStoryItem("My Story", Icons.person); // Show text if no story or images found
  //       }
  //     },
  //   );
  // }
}
