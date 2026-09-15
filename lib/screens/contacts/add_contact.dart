import 'package:chat_messenger/api/contact_api.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/helpers/app_helper.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
//import 'package:contacts_service/contacts_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts_service/flutter_contacts_service.dart';
import 'package:get/get.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:chat_messenger/screens/contacts/friend_request_screen.dart';
import 'package:chat_messenger/controllers/auth_controller.dart';
import 'package:chat_messenger/routes/app_routes.dart';
import 'package:permission_handler/permission_handler.dart';

// class AddNewContactScreen extends StatefulWidget {
//   AddNewContactScreen();

//   @override
//   _AddNewContactScreenState createState() => _AddNewContactScreenState();
// }

// class _AddNewContactScreenState extends State<AddNewContactScreen> {
//   List<Contact> _contacts = [];
//   bool _permissionDenied = false;

//   @override
//   void initState() {
//     super.initState();
//     _fetchContacts();
//   }

//   Future<void> _requestContactPermission() async {
//     var status = await Permission.contacts.status;
//     if (status.isDenied) {
//       await Permission.contacts.request();
//     }
//     if (status.isPermanentlyDenied) {
//       setState(() {
//         _permissionDenied = true;
//       });
//     }
//   }

//   Future<void> _fetchContacts() async {
//     await _requestContactPermission();
//     var permissionStatus = await Permission.contacts.status;
//     if (permissionStatus.isGranted) {
//       Iterable<Contact> contacts = await ContactsService.getContacts();
//       setState(() {
//         _contacts = contacts.toList();
//       });
//     } else {
//       setState(() {
//         _permissionDenied = true;
//       });
//     }
//   }

//   Future<List<String>> getAppUsers() async {
//     List<String> appUsers = [];
//     QuerySnapshot usersSnapshot =
//         await FirebaseFirestore.instance.collection('Users').get();
//     for (var doc in usersSnapshot.docs) {
//       appUsers.add(doc['number']);
//     }
//     return appUsers;
//   }

//   matchUser() async {
//     List<String> contactNumbers = [];
//     for (var contact in _contacts) {
//       contact.phones?.forEach((phone) {
//         contactNumbers.add(phone.value ?? '');
//       });
//     }
//     List<String> appUsers = await getAppUsers();
//     List<String> matchedUsers =
//         contactNumbers.where((contact) => appUsers.contains(contact)).toList();
//     debugPrint(matchedUsers);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Add Contact'),
//       ),
//       body: _permissionDenied
//           ? Center(
//               child: Text('data'),
//             )
//           // ? Center(
//           //     child: Column(
//           //       mainAxisAlignment: MainAxisAlignment.center,
//           //       children: [
//           //         Text(
//           //           '${AppLocalizations.of(context)!.permission_is_required_to_access_contacts_please_enable_contacts_permission_to_add_members_to_your_group}',
//           //           textAlign: TextAlign.center,
//           //           style: TextStyle(fontSize: 16, color: Colors.black54),
//           //         ),
//           //         SizedBox(height: 20),
//           //         ElevatedButton(
//           //           onPressed: _openAppSettings,
//           //           child: Text('${AppLocalizations.of(context)!.open_app_settings}'),
//           //         ),
//           //       ],
//           //     ),
//           //   )
//           : _contacts.isEmpty
//               ? Center(child: CircularProgressIndicator())
//               : ListView.builder(
//                   itemCount: _contacts.length,
//                   itemBuilder: (context, index) {
//                     var contact = _contacts[index];
//                     return ListTile(
//                       title: Text(contact.displayName ?? ''),
//                       subtitle: Text(contact.phones!.isNotEmpty
//                           ? contact.phones!.first.value!
//                           : 'No phone number'),
//                       onTap: () => check,
//                     );
//                   },
//                 ),
//     );
//   }
// }

class AddNewContactScreen extends StatefulWidget {
  const AddNewContactScreen({super.key});

  @override
  State<AddNewContactScreen> createState() => _AddNewContactScreenState();
}

class _AddNewContactScreenState extends State<AddNewContactScreen> {
  List<ContactInfo> _contacts = [];
  List<ContactInfo> _matchedContacts = [];
  List<ContactInfo> _unmatchedContacts = [];
  bool _isLoading = true;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _fetchContacts();
  }

  Future<void> _requestContactPermission() async {
    var status = await Permission.contacts.status;
    if (status.isDenied) {
      status = await Permission.contacts.request();
    }
    if (status.isPermanentlyDenied) {
      if (!mounted) return;
      setState(() {
        _permissionDenied = true;
      });
    }
  }

  Future<void> _fetchContacts() async {
    await _requestContactPermission();
    var permissionStatus = await Permission.contacts.status;

    if (permissionStatus.isGranted) {
      Iterable<ContactInfo> contacts =
          await FlutterContactsService.getContacts();
      if (!mounted) return;
      setState(() {
        _contacts = contacts.toList();
      });
      await _matchUser();
      if (!mounted) return;
    } else {
      if (!mounted) return;
      setState(() {
        _permissionDenied = true;
      });
    }

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  Future<List<String>> getAppUsers(List<String> contactNumbers) async {
    final uniqueNumbers = contactNumbers
        .where((n) => n.isNotEmpty)
        .toSet()
        .toList();
    List<String> appUsers = [];

    // Firestore 'in' query supports up to 30 items at a time
    for (int i = 0; i < uniqueNumbers.length; i += 30) {
      int end = (i + 30 < uniqueNumbers.length) ? i + 30 : uniqueNumbers.length;
      List<String> chunk = uniqueNumbers.sublist(i, end);

      try {
        QuerySnapshot usersSnapshot = await FirebaseFirestore.instance
            .collection('Users')
            .where('number', whereIn: chunk)
            .get();

        for (var doc in usersSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>?;
          if (data != null && data.containsKey('number')) {
            appUsers.add(data['number'].toString());
          }
        }
      } catch (e) {
        debugPrint('Error fetching contact batch: $e');
      }
    }
    return appUsers;
  }

  Future<void> _matchUser() async {
    List<String> contactNumbers = [];
    for (var contact in _contacts) {
      contact.phones?.forEach((phone) {
        contactNumbers.add(
          phone.value!.replaceAll(RegExp(r'\s+|-'), ''),
        ); // Normalize phone numbers
      });
    }
    List<String> appUsers = await getAppUsers(contactNumbers);
    if (!mounted) return;

    List<ContactInfo> matchedContacts = [];
    List<ContactInfo> unmatchedContacts = [];

    for (var contact in _contacts) {
      var phoneNumber = contact.phones!.isNotEmpty
          ? contact.phones!.first.value!.replaceAll(RegExp(r'\s+|-'), '')
          : '';
      if (appUsers.contains(phoneNumber)) {
        matchedContacts.add(contact); // Add to matched list
      } else {
        unmatchedContacts.add(contact); // Add to unmatched list
      }
    }

    if (!mounted) return;
    setState(() {
      _matchedContacts = matchedContacts;
      _unmatchedContacts = unmatchedContacts;
    });
  }

  //query for recieve user and change map data to User
  Future getUserData(String phoneNumber) async {
    try {
      // Query Firestore collection 'Users' where 'number' matches 'phoneNumber'
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('Users')
          .where('number', isEqualTo: phoneNumber)
          .get();

      // Check if documents exist
      if (querySnapshot.docs.isNotEmpty) {
        // Return the userId of the first matching document
        Map<String, dynamic> data =
            querySnapshot.docs.first.data() as Map<String, dynamic>;

        // Convert the Map to a User object using User.fromMap
        User user = User.fromMap(data);
        return user;
      } else {
        debugPrint('No user found with this phone number');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      return null; // Return null if an error occurs
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add Contact')),
      body: _permissionDenied
          ? Center(child: Text('Permission is required to access contacts.'))
          : _isLoading
          ? Center(child: CircularProgressIndicator())
          : _contacts.isEmpty
          ? Center(child: Text('No contacts found.'))
          : ListView.builder(
              itemCount:
                  _matchedContacts.length + _unmatchedContacts.length + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: primaryColor.withValues(alpha: 0.1),
                      child: const Icon(IconlyBold.user3, color: primaryColor),
                    ),
                    title: Text(
                      'new_group'.tr,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onTap: () {
                      Get.toNamed(AppRoutes.groups);
                    },
                  );
                }
                if (index == 1) {
                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('Users')
                        .doc(AuthController.instance.currentUser.userId)
                        .collection('friend_requests')
                        .snapshots(),
                    builder: (context, snapshot) {
                      int requestCount = snapshot.hasData
                          ? snapshot.data!.docs.length
                          : 0;
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.orange.withValues(alpha: 0.1),
                          child: const Icon(
                            Icons.person_add,
                            color: Colors.orange,
                          ),
                        ),
                        title: Row(
                          children: [
                            Text(
                              'add_request'.tr,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (requestCount > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  requestCount.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        onTap: () {
                          Get.to(() => const FriendRequestScreen());
                        },
                      );
                    },
                  );
                }

                final contactIndex = index - 2;
                ContactInfo contact;
                bool isMatched;

                // Show matched users first
                if (contactIndex < _matchedContacts.length) {
                  contact = _matchedContacts[contactIndex];
                  isMatched = true;
                } else {
                  contact =
                      _unmatchedContacts[contactIndex -
                          _matchedContacts.length];
                  isMatched = false;
                }

                var phoneNumber = contact.phones!.isNotEmpty
                    ? contact.phones!.first.value!.replaceAll(
                        RegExp(r'\s+|-'),
                        '',
                      ) // Normalize phone numbers
                    : '';

                return ListTile(
                  title: Text(contact.displayName ?? ''),
                  subtitle: Text(
                    phoneNumber.isNotEmpty ? phoneNumber : 'No phone number',
                  ),
                  trailing: phoneNumber != 'No phone number'
                      ? isMatched
                            ? Container(
                                width: 75,
                                decoration: BoxDecoration(
                                  border: Border.all(color: primaryColor),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(5.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: [
                                      Icon(
                                        Icons.messenger_outline,
                                        size: 17,
                                        color: Colors.blue,
                                      ),
                                      Text('Chat'),
                                    ],
                                  ),
                                ),
                              ) // Call icon for matched user
                            : Container(
                                height: 30,
                                width: 65,
                                decoration: BoxDecoration(
                                  border: Border.all(color: primaryColor),
                                ),
                                child: Align(
                                  alignment: Alignment.center,
                                  child: Text('Invite'),
                                ),
                              )
                      : null, // Email icon for unmatched user
                  onTap: () async {
                    if (isMatched) {
                      // Handle call action for matched user
                      var user = await getUserData(phoneNumber);

                      if (!context.mounted) return;
                      FocusScope.of(context).unfocus();

                      // Send friend request
                      await ContactApi.sendFriendRequest(
                        targetUserId: user.userId,
                      );
                    } else {
                      AppHelper.openMessageApp(phoneNumber, 'message');
                      // Handle email action for unmatched user
                    }
                  },
                );
              },
            ),
    );
  }
}
