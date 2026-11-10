import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:chat_messenger/components/loading_indicator.dart';
import 'package:chat_messenger/components/no_data.dart';
import 'package:chat_messenger/models/chat.dart';
import 'package:chat_messenger/tabs/chats/controllers/chat_controller.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:get/get.dart';
import 'package:chat_messenger/helpers/routes_helper.dart';
import 'package:chat_messenger/tabs/groups/controllers/group_controller.dart';
import 'package:chat_messenger/models/group.dart';
import 'package:chat_messenger/tabs/groups/components/group_card.dart';
import 'package:chat_messenger/tabs/chats/controllers/channel_controller.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:chat_messenger/models/message.dart';
import 'package:chat_messenger/api/user_api.dart';
import 'components/chat_card.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  // Vars
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get controllers
    final ChatController controller = Get.find();
    final GroupController groupController = Get.find();
    final ChannelController channelController = Get.find();

    // Other vars
    const padding = EdgeInsets.symmetric(vertical: defaultPadding);

    return Scaffold(
      body: Obx(
        () {
          // Explicitly evaluate all reactive variables to guarantee they register in Obx, preventing "improper use of Obx" exceptions
          final bool chatsLoading = controller.isLoading.value;
          final bool groupsLoading = groupController.isLoading.value;
          final bool channelsLoading = channelController.isLoading.value;
          
          // Triggers observer registration without declaring unused local variables
          controller.chats.length;
          groupController.groups.length;
          channelController.channels.length;
          controller.isSearching.value;

          // Check loading
          if (chatsLoading && groupsLoading && channelsLoading) {
            return const LoadingIndicator();
          }

          // Build a reactive copy of Chats list to modify with dynamic Channel updates
          // Filter out buggy 'Official Channel' fallback chats
          final List<Chat> userChats = List<Chat>.from(controller.chats)
              .where((chat) => chat.receiver?.fullname != 'Official Channel')
              .toList();

          // Merge each OfficialChannel into the userChats, or update the existing one's receiver properties
          for (var channel in channelController.channels) {
            final int index = userChats.indexWhere((chat) => chat.receiver?.userId == channel.id);
            if (index != -1) {
              final existingChat = userChats[index];
              existingChat.receiver = User(
                userId: channel.id,
                fullname: channel.name,
                photoUrl: channel.logo,
                bio: channel.description,
                isVerified: channel.isVerified,
                userType: 'channel',
                level: 'Max',
              );
            } else {
              userChats.add(Chat(
                senderId: channel.id,
                receiver: User(
                  userId: channel.id,
                  fullname: channel.name,
                  photoUrl: channel.logo,
                  bio: channel.description,
                  isVerified: channel.isVerified,
                  userType: 'channel',
                  level: 'Max',
                ),
                lastMsg: channel.description.isNotEmpty ? channel.description : 'Official Notification Channel',
                msgType: MessageType.text,
                sentAt: channel.updatedAt ?? channel.createdAt ?? DateTime.now(),
                unread: 0,
              ));
            }
          }

          // Fallback check to ensure 'official_team' is ALWAYS in the list and has correct name
          final int officialTeamIndex = userChats.indexWhere((chat) => chat.receiver?.userId == 'official_team');
          if (officialTeamIndex != -1) {
            final existing = userChats[officialTeamIndex];
            if (existing.receiver == null ||
                existing.receiver!.fullname.isEmpty ||
                existing.receiver!.fullname == 'User') {
              existing.receiver = UserApi.getOfficialTeamUser(
                customLogo: existing.receiver?.photoUrl,
              );
            }
          } else {
            userChats.add(Chat(
              senderId: 'official_team',
              receiver: UserApi.getOfficialTeamUser(),
              lastMsg: UserApi.officialDefaultBio,
              msgType: MessageType.text,
              sentAt: DateTime.now(),
              unread: 0,
            ));
          }

          List<dynamic> combinedList = [];

          if (controller.isSearching.value) {
            final String text = controller.searchController.text.trim().toLowerCase();
            
            combinedList.addAll(userChats.where((chat) =>
              (chat.receiver?.fullname.toLowerCase().contains(text) ?? false) ||
              chat.lastMsg.toLowerCase().contains(text)
            ));
            
            combinedList.addAll(groupController.groups.where((group) =>
              group.name.toLowerCase().contains(text) ||
              (group.lastMsg?.textMsg.toLowerCase().contains(text) ?? false)
            ));
          } else {
            combinedList.addAll(userChats);
            combinedList.addAll(groupController.groups);
          }

          if (combinedList.isEmpty) {
            return NoData(
              iconData: IconlyBold.chat,
              text: 'no_chats'.tr,
            );
          }

          // Sort the combined list
          combinedList.sort((a, b) {
            bool aIsPinned = false;
            bool bIsPinned = false;
            
            // Assume Official channel is pinned
            if (a is Chat && (a.receiver?.userId == 'official_team' || a.receiver?.userId.startsWith('official_channel_') == true)) aIsPinned = true;
            if (b is Chat && (b.receiver?.userId == 'official_team' || b.receiver?.userId.startsWith('official_channel_') == true)) bIsPinned = true;
            
            if (aIsPinned && !bIsPinned) return -1;
            if (!aIsPinned && bIsPinned) return 1;

            DateTime? timeA = (a is Chat) 
              ? (a.isDeleted ? a.updatedAt : a.sentAt) 
              : (a as Group).lastMsg?.sentAt ?? a.createdAt;
              
            DateTime? timeB = (b is Chat) 
              ? (b.isDeleted ? b.updatedAt : b.sentAt) 
              : (b as Group).lastMsg?.sentAt ?? b.createdAt;
              
            if (timeA == null && timeB == null) return 0;
            if (timeA == null) return 1; // Put nulls at the end
            if (timeB == null) return -1;
            return timeB.compareTo(timeA); // descending
          });

          return ListView.builder(
            shrinkWrap: false,
            padding: padding,
            scrollDirection: Axis.vertical,
            physics: const BouncingScrollPhysics(),
            itemCount: combinedList.length,
            itemBuilder: (_, index) {
              final item = combinedList[index];

              if (item is Chat) {
                return ChatCard(
                  item,
                  onDeleteChat: () {
                    final uid = item.receiver?.userId;
                    if (uid != null && uid.isNotEmpty) {
                      controller.deleteChat(uid);
                    }
                  },
                );
              } else if (item is Group) {
                return GroupCard(
                  group: item,
                  onPress: () => RoutesHelper.toMessages(
                      isGroup: true, groupId: item.groupId),
                );
              }
              return const SizedBox.shrink();
            },
          );
        },
      ),
    );
  }
}
