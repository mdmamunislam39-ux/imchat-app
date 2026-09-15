import 'package:flutter/material.dart';
import 'package:get/get.dart';

import 'package:chat_messenger/screens/calling/controller/call_controller.dart';
import 'package:chat_messenger/screens/calling/helper/call_helper.dart';
import 'package:chat_messenger/tabs/groups/controllers/group_call_controller.dart';

class CallTimer extends StatelessWidget {
  final CallController? controller;
  final TextStyle? style;

  const CallTimer({
    super.key,
    this.controller,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final CallController? activeController =
        controller ?? (Get.isRegistered<CallController>() ? Get.find<CallController>() : null);

    if (activeController == null) {
      return Text(
        '00:00',
        style: style ?? const TextStyle(color: Colors.white, fontSize: 18),
      );
    }

    return Obx(
      () => Text(
        CallHelper.formatTime(activeController.seconds.value),
        style: style ?? const TextStyle(color: Colors.white, fontSize: 18),
      ),
    );
  }
}

class CallTimerForGroupCall extends StatelessWidget {
  final GroupCallController? controller;
  final TextStyle? style;

  const CallTimerForGroupCall({
    super.key,
    this.controller,
    this.style,
  });

  @override
  Widget build(BuildContext context) {
    final GroupCallController? activeController =
        controller ?? (Get.isRegistered<GroupCallController>() ? Get.find<GroupCallController>() : null);

    if (activeController == null) {
      return Text(
        '00:00',
        style: style ?? const TextStyle(color: Colors.white, fontSize: 18),
      );
    }

    return Obx(
      () => Text(
        CallHelper.formatTime(activeController.seconds.value),
        style: style ?? const TextStyle(color: Colors.white, fontSize: 18),
      ),
    );
  }
}