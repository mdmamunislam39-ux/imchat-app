import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:get/get.dart';

import 'package:chat_messenger/components/cached_circle_avatar.dart';
import 'package:chat_messenger/components/custom_appbar.dart';
import 'package:chat_messenger/components/loading_indicator.dart';
import 'package:chat_messenger/components/sent_time.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/helpers/routes_helper.dart';
import 'package:chat_messenger/models/chat.dart';
import 'package:chat_messenger/models/group.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/screens/contacts/controllers/contact_controller.dart';
import 'package:chat_messenger/screens/contacts/number_search.dart';
import 'package:chat_messenger/screens/room/roomprofile_screen.dart';
import 'package:chat_messenger/tabs/chats/controllers/chat_controller.dart';
import 'package:chat_messenger/tabs/groups/controllers/group_controller.dart';

import 'components/contact_card.dart';

class ContactSearchScreen extends StatefulWidget {
  const ContactSearchScreen({super.key});

  @override
  State<ContactSearchScreen> createState() => _ContactSearchScreenState();
}

class _ContactSearchScreenState extends State<ContactSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  bool _isSearchingFirestore = false;

  // Real-time matched results
  List<User> _matchedUsers = [];
  List<Chat> _matchedChats = [];
  List<Group> _matchedGroups = [];

  String get _currentUserId => AuthController.instance.currentUser.userId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _debounce?.cancel();
      setState(() {
        _isSearchingFirestore = false;
        _matchedUsers.clear();
        _matchedChats.clear();
        _matchedGroups.clear();
      });
      return;
    }

    // Step 1: Immediate local in-memory search (instant)
    _performLocalSearch(query);

    // Step 2: Debounced Firestore remote search (300ms)
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _performRemoteSearch(query);
    });
  }

  void _performLocalSearch(String query) {
    final q = query.toLowerCase();

    // 1. Search local contacts
    final List<User> localUsers = [];
    final Set<String> addedUserIds = <String>{};

    if (Get.isRegistered<ContactController>()) {
      final contactCtrl = Get.find<ContactController>();
      for (final user in contactCtrl.contacts) {
        if (user.userId == _currentUserId) continue;
        if (user.fullname.toLowerCase().contains(q) ||
            user.number.toLowerCase().contains(q) ||
            user.searchId.toLowerCase().contains(q)) {
          localUsers.add(user);
          addedUserIds.add(user.userId);
        }
      }
    }

    // 2. Search local chats for user names & messages
    final List<Chat> localChats = [];
    if (Get.isRegistered<ChatController>()) {
      final chatCtrl = Get.find<ChatController>();
      for (final chat in chatCtrl.chats) {
        final receiver = chat.receiver;
        if (receiver != null && receiver.userId != _currentUserId) {
          // If user name matches and not in user list yet
          if (receiver.fullname.toLowerCase().contains(q) ||
              receiver.number.toLowerCase().contains(q) ||
              receiver.searchId.toLowerCase().contains(q)) {
            if (!addedUserIds.contains(receiver.userId)) {
              localUsers.add(receiver);
              addedUserIds.add(receiver.userId);
            }
          }

          // If message content matches query
          if (chat.lastMsg.toLowerCase().contains(q)) {
            localChats.add(chat);
          }
        }
      }
    }

    // 3. Search local groups for group name & message
    final List<Group> localGroups = [];
    if (Get.isRegistered<GroupController>()) {
      final groupCtrl = Get.find<GroupController>();
      for (final group in groupCtrl.groups) {
        final matchesName = group.name.toLowerCase().contains(q);
        final matchesMsg = group.lastMsg?.textMsg.toLowerCase().contains(q) ?? false;
        if (matchesName || matchesMsg) {
          localGroups.add(group);
        }
      }
    }

    setState(() {
      _matchedUsers = localUsers;
      _matchedChats = localChats;
      _matchedGroups = localGroups;
    });
  }

  Future<void> _performRemoteSearch(String query) async {
    if (!mounted) return;
    setState(() {
      _isSearchingFirestore = true;
    });

    final q = query.trim();
    final Map<String, User> remoteUsers = {};

    // Keep existing matched users
    for (final user in _matchedUsers) {
      remoteUsers[user.userId] = user;
    }

    try {
      // 1. Search Users collection in Firestore
      final variations = <String>{
        q,
        q.toLowerCase(),
        if (q.isNotEmpty) q[0].toUpperCase() + q.substring(1).toLowerCase(),
      };

      for (final v in variations) {
        final snapshot = await FirebaseFirestore.instance
            .collection('Users')
            .where('fullname', isGreaterThanOrEqualTo: v)
            .where('fullname', isLessThanOrEqualTo: '$v\uf8ff')
            .limit(15)
            .get();

        for (final doc in snapshot.docs) {
          if (doc.id != _currentUserId) {
            final user = User.fromMap(doc.data());
            remoteUsers[user.userId] = user;
          }
        }
      }

      // If query is digits, also search by searchId or phone number
      if (RegExp(r'^[0-9+]+$').hasMatch(q)) {
        final snapshotId = await FirebaseFirestore.instance
            .collection('Users')
            .where('searchId', isEqualTo: q)
            .limit(5)
            .get();
        for (final doc in snapshotId.docs) {
          if (doc.id != _currentUserId) {
            final user = User.fromMap(doc.data());
            remoteUsers[user.userId] = user;
          }
        }

        final snapshotPhone = await FirebaseFirestore.instance
            .collection('Users')
            .where('number', isEqualTo: q)
            .limit(5)
            .get();
        for (final doc in snapshotPhone.docs) {
          if (doc.id != _currentUserId) {
            final user = User.fromMap(doc.data());
            remoteUsers[user.userId] = user;
          }
        }
      }

      // 2. Search deeper into recent messages of active chats if query >= 2 characters
      final List<Chat> deeperChatMatches = List<Chat>.from(_matchedChats);
      if (q.length >= 2 && Get.isRegistered<ChatController>()) {
        final chatCtrl = Get.find<ChatController>();
        final topChats = chatCtrl.chats.take(10).toList();

        for (final chat in topChats) {
          final receiverId = chat.receiver?.userId;
          if (receiverId == null || receiverId.isEmpty) continue;

          // Check if already in matched chats
          if (deeperChatMatches.any((c) => c.receiver?.userId == receiverId)) {
            continue;
          }

          try {
            final msgDocs = await FirebaseFirestore.instance
                .collection('Users')
                .doc(_currentUserId)
                .collection('Chats')
                .doc(receiverId)
                .collection('Messages')
                .orderBy('sentAt', descending: true)
                .limit(15)
                .get();

            for (final mDoc in msgDocs.docs) {
              final text = (mDoc.data()['textMsg'] ?? '').toString();
              if (text.toLowerCase().contains(q.toLowerCase())) {
                deeperChatMatches.add(Chat(
                  senderId: chat.senderId,
                  receiver: chat.receiver,
                  lastMsg: text,
                  sentAt: (mDoc.data()['sentAt'] as Timestamp?)?.toDate() ?? chat.sentAt,
                  unread: 0,
                ));
                break;
              }
            }
          } catch (_) {}
        }
      }

      if (mounted && _searchController.text.trim() == query) {
        setState(() {
          _matchedUsers = remoteUsers.values.toList();
          _matchedChats = deeperChatMatches;
          _isSearchingFirestore = false;
        });
      }
    } catch (e) {
      debugPrint('Error performing remote search: $e');
      if (mounted) {
        setState(() {
          _isSearchingFirestore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasQuery = _searchController.text.trim().isNotEmpty;
    final hasResults = _matchedUsers.isNotEmpty ||
        _matchedChats.isNotEmpty ||
        _matchedGroups.isNotEmpty;

    return Scaffold(
      appBar: CustomAppBar(
        title: Text("search_contact".tr),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Input Box
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                controller: _searchController,
                autofocus: false,
                decoration: InputDecoration(
                  hintText: 'Enter name or message...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: hasQuery
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 20),
                          onPressed: () {
                            _searchController.clear();
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ),

            // Add Friends Row
            InkWell(
              onTap: () {
                Get.to(() => const NumberSearchScreen());
              },
              child: const ListTile(
                leading: Icon(
                  Icons.person_add,
                  color: primaryColor,
                  size: 22,
                ),
                title: Text(
                  'Add Friends',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 15,
                  color: Colors.grey,
                ),
              ),
            ),

            const Divider(height: 1, thickness: 1, color: Color(0xFFEEEEEE)),

            // Subtle Linear Loading Indicator for remote search
            if (_isSearchingFirestore)
              const LinearProgressIndicator(
                minHeight: 2,
                backgroundColor: Colors.transparent,
              ),

            // Content Area
            Expanded(
              child: hasQuery
                  ? _buildSearchResults(hasResults)
                  : _buildDefaultContactsView(),
            ),
          ],
        ),
      ),
    );
  }

  /// When query is empty, show user's contact list so screen is never blank
  Widget _buildDefaultContactsView() {
    final ContactController contactCtrl = Get.isRegistered<ContactController>()
        ? Get.find<ContactController>()
        : Get.put(ContactController());

    return Obx(() {
      if (contactCtrl.isLoading.value) {
        return const Center(child: LoadingIndicator());
      }

      final contacts = contactCtrl.sortedContacts;
      if (contacts.isEmpty) {
        return Center(
          child: Text(
            'no_contacts'.tr,
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
        );
      }

      return ListView(
        physics: const BouncingScrollPhysics(),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              'My Contacts (${contacts.length})',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          ...contacts.map((user) => ContactCard(
                user: user,
                onPress: () {
                  RoutesHelper.toMessages(user: user);
                },
              )),
          const SizedBox(height: 16),
        ],
      );
    });
  }

  /// When query is present, show categorized real-time results
  Widget _buildSearchResults(bool hasResults) {
    if (!hasResults && !_isSearchingFirestore) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(IconlyLight.search, size: 50, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              'No matched users or messages found.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
            ),
          ],
        ),
      );
    }

    final ContactController? contactCtrl = Get.isRegistered<ContactController>()
        ? Get.find<ContactController>()
        : null;
    final Set<String> contactIds =
        contactCtrl?.contacts.map((u) => u.userId).toSet() ?? {};

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        // 1. Users & Contacts Section
        if (_matchedUsers.isNotEmpty) ...[
          _buildSectionHeader('Users & Contacts (${_matchedUsers.length})'),
          ..._matchedUsers.map((user) {
            final bool isContact = contactIds.contains(user.userId);
            return ListTile(
              leading: CachedCircleAvatar(
                imageUrl: user.photoUrl,
                radius: 22,
                isOnline: user.isOnline,
                lastActive: user.lastActive?.millisecondsSinceEpoch,
                showFrame: false,
              ),
              title: Row(
                children: [
                  Flexible(
                    child: Text(
                      user.fullname,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (user.isVerified == true) ...[
                    const SizedBox(width: 4),
                    const Icon(Icons.verified, size: 16, color: Colors.blue),
                  ],
                ],
              ),
              subtitle: Text(
                user.bio.isNotEmpty
                    ? user.bio
                    : (user.searchId.isNotEmpty
                        ? 'ID: ${user.searchId}'
                        : (user.number.isNotEmpty ? user.number : 'imChat User')),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isContact)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Text(
                        'Contact',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(
                      IconlyLight.chat,
                      color: primaryColor,
                      size: 22,
                    ),
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      RoutesHelper.toMessages(user: user);
                    },
                  ),
                ],
              ),
              onTap: () {
                FocusScope.of(context).unfocus();
                Get.to(() => ProfilePageForRoom(
                      userID: user.userId,
                      userName: user.fullname,
                      userImage: user.photoUrl,
                    ));
              },
            );
          }),
        ],

        // 2. Messages Section
        if (_matchedChats.isNotEmpty) ...[
          _buildSectionHeader('Messages (${_matchedChats.length})'),
          ..._matchedChats.map((chat) {
            final receiver = chat.receiver;
            return ListTile(
              leading: CachedCircleAvatar(
                imageUrl: receiver?.photoUrl ?? '',
                radius: 22,
                showFrame: false,
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      receiver?.fullname ?? 'Unknown',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  SentTime(time: chat.sentAt),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: RichText(
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  text: _highlightMatch(
                    chat.lastMsg,
                    _searchController.text.trim(),
                  ),
                ),
              ),
              onTap: () {
                FocusScope.of(context).unfocus();
                if (receiver != null) {
                  RoutesHelper.toMessages(user: receiver);
                }
              },
            );
          }),
        ],

        // 3. Groups Section
        if (_matchedGroups.isNotEmpty) ...[
          _buildSectionHeader('Groups (${_matchedGroups.length})'),
          ..._matchedGroups.map((group) {
            return ListTile(
              leading: CachedCircleAvatar(
                imageUrl: group.photoUrl,
                radius: 22,
                showFrame: false,
              ),
              title: Text(
                group.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
              subtitle: group.lastMsg?.textMsg != null && group.lastMsg!.textMsg.isNotEmpty
                  ? Text(
                      group.lastMsg!.textMsg,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    )
                  : Text(
                      '${group.members.length} members',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: Colors.grey,
              ),
              onTap: () {
                FocusScope.of(context).unfocus();
                RoutesHelper.toMessages(
                  isGroup: true,
                  groupId: group.groupId,
                );
              },
            );
          }),
        ],

        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade100,
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.grey.shade700,
        ),
      ),
    );
  }

  /// Highlight the matched substring in message text
  TextSpan _highlightMatch(String text, String query) {
    if (query.isEmpty) {
      return TextSpan(
        text: text,
        style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final List<TextSpan> spans = [];

    int start = 0;
    while (true) {
      final index = lowerText.indexOf(lowerQuery, start);
      if (index < 0) {
        spans.add(TextSpan(
          text: text.substring(start),
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
        ));
        break;
      }

      if (index > start) {
        spans.add(TextSpan(
          text: text.substring(start, index),
          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
        ));
      }

      spans.add(TextSpan(
        text: text.substring(index, index + query.length),
        style: const TextStyle(
          color: primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 13,
        ),
      ));

      start = index + query.length;
    }

    return TextSpan(children: spans);
  }
}
