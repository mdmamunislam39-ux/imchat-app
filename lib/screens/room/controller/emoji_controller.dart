
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class EmojiController extends GetxController with GetSingleTickerProviderStateMixin {
  final tabTitles = ['Free', 'Customize', 'Activity'];
  late TabController tabController;

  var selectedTabIndex = 0.obs;
  var emojis = [].obs;

  // Track selection state for each item
  var selectedIndexes = <int, bool>{}.obs;

  void toggleBorder(int index) {
    selectedIndexes[index] = !(selectedIndexes[index] ?? false);
    selectedIndexes.refresh(); // Notify UI
  }

  bool isSelected(int index) => selectedIndexes[index] ?? false;

  @override
  void onInit() {
    super.onInit();
    tabController = TabController(length: tabTitles.length, vsync: this);
    tabController.addListener(() {
      if (tabController.indexIsChanging) return;
      selectedTabIndex.value = tabController.index;
      fetchEmojis(tabTitles[tabController.index]);
    });
    fetchEmojis(tabTitles[0]);
  }

  void fetchEmojis(String tabName) async{
    // Your logic here: e.g., Firebase query by `tabName`
    debugPrint('Fetching gifts for $tabName');
    // Example mock data:
    final snapshot = await FirebaseFirestore.instance
          .collection('emoji')
          .doc(tabName)
          .get();

    emojis.value = snapshot.data()?['emojis'] ?? [];
    selectedIndexes.clear(); 
  }

  @override
  void onClose() {
    tabController.dispose();
    super.onClose();
  }
}

