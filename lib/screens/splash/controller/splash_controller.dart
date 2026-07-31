import 'package:get/get.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:get_storage/get_storage.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:chat_messenger/services/leaderboard_service.dart';

class SplashController extends GetxController {
  // Init Auth controller
  final auth = Get.put(AuthController(), permanent: true);

  @override
  void onInit() async {
    super.onInit();
    // Future.delayed(Duration(seconds: 3),(){
    //      Get.to(()=> PhoneVerificationScreen());
    // });
    _loadData();
    _getAppVersion();

    // Check leaderboards (Frontend Temporary Approach)
    Get.put(LeaderboardService()).checkAndResetLeaderboards();
  }

  Future<void> _loadData() async {
    // Auth user account
    await auth.checkUserAccount();
  }

  // app version checker
  var box = GetStorage();
  String? _version;

  void _getAppVersion() async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    final version = packageInfo.version;

    _version = version;
    box.write('version', _version);
  }
}
