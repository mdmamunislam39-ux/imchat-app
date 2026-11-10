import 'package:chat_messenger/models/group.dart';
import 'package:chat_messenger/models/story/story.dart';
import 'package:chat_messenger/screens/auth/phone/phone_verification.dart';
import 'package:chat_messenger/screens/contacts/contact_search_screen.dart';
import 'package:chat_messenger/screens/contacts/contacts_screen.dart';
import 'package:chat_messenger/screens/contacts/select_contacts_screen.dart';
import 'package:chat_messenger/screens/messages/message_screen.dart';
import 'package:chat_messenger/screens/welcome/welcome_screen.dart';
import 'package:chat_messenger/tabs/groups/screens/create_group_screen.dart';
import 'package:chat_messenger/tabs/groups/screens/groups_screen.dart';
import 'package:chat_messenger/tabs/groups/screens/edit_group_screen.dart';
import 'package:chat_messenger/tabs/groups/screens/group_details_screen.dart';
import 'package:chat_messenger/tabs/groups/screens/group_video_call.dart';
import 'package:chat_messenger/tabs/profile/edit_profile_screen.dart';
import 'package:chat_messenger/tabs/profile/profile_view_screen.dart';
import 'package:chat_messenger/tabs/stories/add_story_screen.dart';
import 'package:chat_messenger/tabs/stories/story_editor_screen.dart';
import 'package:chat_messenger/tabs/stories/story_view_screen.dart';
import 'package:chat_messenger/tabs/stories/write_story_screen.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/models/call.dart';
import 'package:chat_messenger/screens/auth/password/binding/forgot_pwd_binding.dart';
import 'package:chat_messenger/screens/auth/signin-or-signup/signin_or_signup_screen.dart';
import 'package:chat_messenger/screens/auth/signup/verify_email_screen.dart';
import 'package:chat_messenger/screens/blocked/blocked_account_screen.dart';
import 'package:chat_messenger/screens/calling/incoming_call_screen.dart';
import 'package:chat_messenger/screens/calling/video_call_screen.dart';
import 'package:chat_messenger/screens/calling/voice_call_screen.dart';
import 'package:chat_messenger/screens/home/binding/home_binding.dart';
import 'package:chat_messenger/screens/auth/signin/binding/signin_binding.dart';
import 'package:chat_messenger/screens/auth/signup/bindings/signup_binding.dart';
import 'package:chat_messenger/screens/auth/signup/bindings/signup_with_email_binding.dart';
import 'package:chat_messenger/screens/about/about_screen.dart';
import 'package:chat_messenger/screens/auth/password/forgot_password_screen.dart';
import 'package:chat_messenger/screens/auth/signup/signup_with_email_screen.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/screens/home/home_screen.dart';
import 'package:chat_messenger/screens/record-video/record_video_screen.dart';
import 'package:chat_messenger/screens/session/session_screen.dart';
import 'package:chat_messenger/screens/auth/signin/signin_screen.dart';
import 'package:chat_messenger/screens/auth/signup/signup_screen.dart';
import 'package:chat_messenger/screens/splash/splash_screen.dart';
import 'package:chat_messenger/screens/splash/binding/splash_binding.dart';

import 'app_routes.dart';
import 'package:chat_messenger/screens/settings/notification_settings_screen.dart';
import 'package:chat_messenger/screens/settings/settings_screen.dart' as chat_settings;

abstract class AppPages {
  //
  // <-- Pages list -->
  //
  static final pages = [
    GetPage(
      name: AppRoutes.splash,
      binding: SplashBinding(),
      page: () => const SplashScreen(),
    ),
    GetPage(
      name: AppRoutes.welcome,
      page: () => const WelcomeScreen(),
    ),
    GetPage(
      name: AppRoutes.signInOrSignUp,
      page: () => const SigninOrSignupScreen(),
    ),
    GetPage(
      name: AppRoutes.signIn,
      binding: SignInBinding(),
      page: () => const SignInScreen(),
    ),
    GetPage(
      name: AppRoutes.signUp,
      binding: SignUpBinding(),
      page: () {
        final args = Get.arguments;
        final number = args['number'];
        return SignUpScreen(number: number);
      },
    ),
    GetPage(
      name: AppRoutes.forgotPassword,
      binding: ForgotPasswordBinding(),
      page: () => const ForgotPasswordScreen(),
    ),
    GetPage(
      name: AppRoutes.signUpWithEmail,
      binding: SignUpWithEmailBinding(),
      page: () => const SignUpWithEmailScreen(),
    ),
    GetPage(
      name: AppRoutes.verifyEmail,
      page: () => const VerifyEmailScreen(),
    ),
    GetPage(
      name: AppRoutes.home,
      binding: HomeBinding(),
      page: () =>  HomeScreen(),
    ),
    GetPage(
      name: AppRoutes.recordVideo,
      page: () => const RecordVideoScreen(),
    ),
    GetPage(
      name: AppRoutes.messages,
      page: () {
        final args = Get.arguments;
        final bool isGroup = args['isGroup'];
        final User? user = args?['user'];
        final String? groupId = args['groupId'];

        return MessageScreen(
          isGroup: isGroup,
          user: user,
          groupId: groupId,
        );
      },
    ),
    GetPage(
      name: AppRoutes.videoCall,
      page: () {
        final args = Get.arguments;
        final Call call = args['call'];
        return VideoCallScreen(call: call);
      },
    ),
    GetPage(
      name: AppRoutes.voiceCall,
      page: () {
        final args = Get.arguments;
        final Call call = args['call'];
        return VoiceCallScreen(call: call);
      },
    ),
    GetPage(
      name: AppRoutes.incomingCall,
      page: () {
        final args = Get.arguments;
        final Call call = args['call'];
        return IncommingCallScreen(call: call);
      },
    ),
    GetPage(
      name: AppRoutes.groupCall,
      page: () {
        final args = Get.arguments;
        final Call call = args['call'];
        final bool isVideo = args['isVideo'] ?? call.isVideo;
        final List<User>? recipients = args['recipients'];
        return GroupCallScreen(
          isVideo: isVideo,
          call: call,
          recipients: recipients,
        );
      },
    ),
    GetPage(
      name: AppRoutes.session,
      page: () => const SesssionScreen(),
    ),
    GetPage(
      name: AppRoutes.about,
      page: () => const AboutScreen(),
    ),
    GetPage(
      name: AppRoutes.blockedAccount,
      page: () => const BlockedAccountScreen(),
    ),
    GetPage(
      name: AppRoutes.contacts,
      page: () => const ContactsScreen(showAppBar: true),
    ),
    GetPage(
      name: AppRoutes.groups,
      page: () => const GroupsScreen(),
    ),
    GetPage(
      name: AppRoutes.contactSearch,
      page: () =>  ContactSearchScreen(),
    ),
    GetPage(
      name: AppRoutes.createGroup,
      page: () {
        final args = Get.arguments;
        final bool isBroadcast = args['isBroadcast'];
        return CreateGroupScreen(isBroadcast: isBroadcast);
      },
    ),
    GetPage(
      name: AppRoutes.groupDetails,
      page: () => const GroupDetailsScreen(),
    ),
    GetPage(
      name: AppRoutes.editGroup,
      page: () {
        final args = Get.arguments;
        final Group group = args['group'];
        return EditGroupScreen(group: group);
      },
    ),
    GetPage(
      name: AppRoutes.editProfile,
      page: () => const EditProfileScreen(),
    ),
    GetPage(
      name: AppRoutes.profileView,
      page: () {
        final args = Get.arguments;
        final User user = args['user'];
        final bool isGroup = args['isGroup'];
        return ProfileViewScreen(user: user, isGroup: isGroup);
      },
    ),
    GetPage(
      name: AppRoutes.selectContacts,
      page: () {
        final args = Get.arguments;
        final String title = args['title'];
        final bool showGroups = args?['showGroups'] ?? false;
        return SelectContactsScreen(title: title, showGroups: showGroups);
      },
    ),
    GetPage(
      name: AppRoutes.writeStory,
      page: () => const WriteStoryScreen(),
    ),
    GetPage(
      name: AppRoutes.addStory,
      page: () => const AddStoryScreen(),
    ),
    GetPage(
      name: AppRoutes.storyEditor,
      page: () {
        final args = Get.arguments;
        return StoryEditorScreen(imageFile: args['imageFile']);
      },
    ),
    GetPage(
      name: AppRoutes.storyView,
      page: () {
        final args = Get.arguments;
        final Story story = args['story'];
        return StoryViewScreen(story: story);
      },
    ),

    //for phone 
    GetPage(
      name: AppRoutes.phoneSignIn,
      binding: SignInBinding(),
      page: () => PhoneVerificationScreen(),
    ),
    GetPage(
      name: AppRoutes.settings,
      page: () => const chat_settings.SettingsScreen(),
    ),
    GetPage(
      name: AppRoutes.notificationSettings,
      page: () => const NotificationSettingsScreen(),
    ),

   
  ];
}
