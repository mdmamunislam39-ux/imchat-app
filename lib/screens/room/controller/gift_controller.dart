
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class GiftController extends GetxController with GetSingleTickerProviderStateMixin {
  final RxList<String> tabTitles = <String>['Hot', 'Event', 'Lucky', 'Local', 'Privilege', 'Trick', 'Customized'].obs;
  TabController? tabController;

  var selectedTabIndex = 0.obs;
  var gifts = [].obs;

  // Track selection state for each item
  var selectedIndexes = <int, bool>{}.obs;

  StreamSubscription<DocumentSnapshot>? _categoriesSubscription;
  StreamSubscription<DocumentSnapshot>? _giftsSubscription;

  void toggleBorder(int index) {
    selectedIndexes[index] = !(selectedIndexes[index] ?? false);
    selectedIndexes.refresh(); // Notify UI
  }

  bool isSelected(int index) => selectedIndexes[index] ?? false;

  @override
  void onInit() {
    super.onInit();
    _initTabController();
    _listenToCategoriesConfig();
  }

  void _initTabController() {
    tabController?.dispose();
    tabController = TabController(length: tabTitles.length, vsync: this);
    tabController!.addListener(() {
      if (tabController!.indexIsChanging) return;
      selectedTabIndex.value = tabController!.index;
      if (selectedTabIndex.value < tabTitles.length) {
        listenToGifts(tabTitles[selectedTabIndex.value]);
      }
    });
    if (tabTitles.isNotEmpty) {
      listenToGifts(tabTitles[0]);
    }
  }

  void _listenToCategoriesConfig() {
    _categoriesSubscription?.cancel();
    _categoriesSubscription = FirebaseFirestore.instance
        .collection('gift')
        .doc('categories_config')
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final data = snapshot.data()!;
        final rawCategories = data['categories'] ?? data['order'];
        if (rawCategories is List) {
          final List<String> loadedCategories = rawCategories.map((e) => e.toString()).where((e) => e.trim().isNotEmpty).toList();
          if (loadedCategories.isNotEmpty && loadedCategories.toString() != tabTitles.toString()) {
            final currentSelected = tabTitles.isNotEmpty && selectedTabIndex.value < tabTitles.length
                ? tabTitles[selectedTabIndex.value]
                : loadedCategories.first;

            tabTitles.value = loadedCategories;
            
            int newIndex = tabTitles.indexOf(currentSelected);
            if (newIndex == -1) newIndex = 0;

            tabController?.dispose();
            tabController = TabController(length: tabTitles.length, vsync: this, initialIndex: newIndex);
            selectedTabIndex.value = newIndex;

            tabController!.addListener(() {
              if (tabController!.indexIsChanging) return;
              selectedTabIndex.value = tabController!.index;
              if (selectedTabIndex.value < tabTitles.length) {
                listenToGifts(tabTitles[selectedTabIndex.value]);
              }
            });

            listenToGifts(tabTitles[newIndex]);
          }
        }
      }
    }, onError: (e) {
      debugPrint('Error listening to gift categories_config: $e');
    });
  }

  void listenToGifts(String tabName) {
    debugPrint('Listening real-time gifts for $tabName');
    _giftsSubscription?.cancel();
    _giftsSubscription = FirebaseFirestore.instance
        .collection('gift')
        .doc(tabName)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists && snapshot.data() != null) {
        final rawGifts = snapshot.data()?['gifts'] as List? ?? [];
        gifts.value = rawGifts.where((g) {
          if (g is Map) return g['isActive'] ?? true;
          return true;
        }).toList();
      } else {
        gifts.value = [];
      }
      selectedIndexes.clear();
    }, onError: (e) {
      debugPrint('Error listening to gifts for $tabName: $e');
    });
  }

  @override
  void onClose() {
    _categoriesSubscription?.cancel();
    _giftsSubscription?.cancel();
    tabController?.dispose();
    super.onClose();
  }
}


