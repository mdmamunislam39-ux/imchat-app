import 'package:chat_messenger/screens/contacts/number_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_contacts_service/flutter_contacts_service.dart';
import 'package:chat_messenger/api/contact_api.dart';
import 'package:chat_messenger/components/custom_appbar.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';

// class ContactSearchScreen extends StatelessWidget {
//   ContactSearchScreen({super.key});
//   // String countryCode = '+1';
//   // String isoCountryCode = 'US';

//   @override
//   Widget build(BuildContext context) {
//     final controller = Get.put(ContactSearchController());

//     return Scaffold(
//       // appBar: CustomAppBar(
//       //   title: Text("search_contact".tr),
//       // ),

//       body: SafeArea(
//         child: Column(
//           children: [
//             Row(
//               children: [
//                 IconButton(onPressed: (){
//                   Get.back();
//                 }, icon: Icon(Icons.arrow_back)),
//                 Expanded(
//                   child: Form(
//                         key: controller.formKey2,
//                         child: Padding(
//                           padding: const EdgeInsets.symmetric(horizontal: 15),
//                           child: TextFormField(
//                             autofocus: true,
//                              onChanged: (value) {
//                                     controller.searchContactForName();
//                                   },
//                             onFieldSubmitted: (String value) =>
//                                 controller.searchContactForName(),
//                             textInputAction: TextInputAction.search,
//                             validator: (val) {
//                               if (val!.isEmpty) {
//                                 return "name can't be null";
//                               }

//                               return null;
//                             },
//                             inputFormatters: AppHelper.usernameFormatter,
//                             controller: controller.usernameController,
//                             decoration: InputDecoration(
//                               hintText: 'search name',
//                               // prefixIcon: const Icon(Icons.alternate_email),
//                               suffixIcon: IconButton(
//                                // bgColor: secondaryColor,
//                                // icon: IconlyLight.search,
//                                icon: Icon(Icons.search),
//                                 onPressed: () => controller.searchContactForName(),
//                               ),
//                             ),
//                           ),
//                         ),
//                       ),
//                 )
//               ],
//             ),

//             // Row(
//             //   mainAxisAlignment: MainAxisAlignment.center,
//             //   children: [
//             //     ElevatedButton(
//             //       onPressed: () {
//             //         controller.changeView(0);
//             //       },
//             //       child: Text('Number',style: TextStyle(color: Colors.black),),
//             //       style: ButtonStyle(
//             //         backgroundColor: WidgetStateProperty.all(
//             //           Colors.white,
//             //         ),
//             //       ),
//             //     ),
//             //     SizedBox(width: 5,),
//             //     ElevatedButton(
//             //       onPressed: () {
//             //         controller.changeView(1); // Show second view
//             //       },
//             //       child: Text('Name',style: TextStyle(color: Colors.black)),
//             //       style: ButtonStyle(
//             //         backgroundColor: WidgetStateProperty.all(
//             //           Colors.white,
//             //         ),
//             //       ),
//             //     ),
//             //   ],
//             // ),
//             // SizedBox(height: 20),
//             // Searh Contact
//             // Obx(() {
//             //   return controller.selectedView.value == 0
//             //       ? Container(
//             //           padding: const EdgeInsets.symmetric(
//             //             horizontal: defaultPadding,
//             //             vertical: defaultPadding,
//             //           ),
//             //           color: Theme.of(context).colorScheme.primaryContainer,
//             //           child: Form(
//             //             key: controller.formKey,
//             //             child: Row(
//             //               children: [
//             //                 CountryCodePicker(
//             //                   onChanged: (val) {
//             //                     controller.countryCode.value = val.toString();
//             //                     controller.isoCountryCode.value = val.code!;
//             //                   },
//             //                   textStyle:
//             //                       TextStyle(fontSize: 16, color: primaryColor),
//             //                   dialogTextStyle:
//             //                       TextStyle(fontSize: 12, color: primaryColor),
//             //                   initialSelection: 'BD',
//             //                   favorite: ['+39', 'US'],
//             //                   showCountryOnly: false,
//             //                   showOnlyCountryWhenClosed: false,
//             //                   alignLeft: false,
//             //                 ),
//             //                 Expanded(
//             //                   child: TextFormField(
//             //                     autofocus: true,
//             //                     onChanged: (value) {
//             //                       controller.searchContactForNumber();
//             //                     },
//             //                     onFieldSubmitted: (String value) =>
//             //                         controller.searchContactForNumber(),
//             //                     textInputAction: TextInputAction.search,
//             //                     validator: (val) {
//             //                       if (val!.isEmpty) {
//             //                         return "number can't be null";
//             //                       }
//             //                       if (val.length > 10) {
//             //                         return 'check your number';
//             //                       }
//             //                       return null;
//             //                     },
//             //                     inputFormatters: AppHelper.usernameFormatter,
//             //                     controller: controller.numberController,
//             //                     decoration: InputDecoration(
//             //                       hintText: 'enter phone number',
//             //                       // prefixIcon: const Icon(Icons.alternate_email),
//             //                       suffixIcon: FloatingButton(
//             //                         bgColor: secondaryColor,
//             //                         icon: IconlyLight.search,
//             //                         onPress: () =>
//             //                             controller.searchContactForNumber(),
//             //                       ),
//             //                     ),
//             //                   ),
//             //                 ),
//             //               ],
//             //             ),
//             //           ),
//             //         )
//             //       : Form(
//             //           key: controller.formKey2,
//             //           child: Padding(
//             //             padding: const EdgeInsets.symmetric(horizontal: 15),
//             //             child: TextFormField(
//             //               autofocus: true,
//             //                onChanged: (value) {
//             //                       controller.searchContactForName();
//             //                     },
//             //               onFieldSubmitted: (String value) =>
//             //                   controller.searchContactForName(),
//             //               textInputAction: TextInputAction.search,
//             //               validator: (val) {
//             //                 if (val!.isEmpty) {
//             //                   return "name can't be null";
//             //                 }

//             //                 return null;
//             //               },
//             //               inputFormatters: AppHelper.usernameFormatter,
//             //               controller: controller.usernameController,
//             //               decoration: InputDecoration(
//             //                 hintText: 'enter name',
//             //                 // prefixIcon: const Icon(Icons.alternate_email),
//             //                 suffixIcon: FloatingButton(
//             //                   bgColor: secondaryColor,
//             //                   icon: IconlyLight.search,
//             //                   onPress: () => controller.searchContactForName(),
//             //                 ),
//             //               ),
//             //             ),
//             //           ),
//             //         );
//             // }),

//             InkWell(
//               onTap: () {
//                 Get.to(()=>NumberSearchScreen());
//               },
//               child: ListTile(
//                 leading: Icon(Icons.person_add,color: primaryColor,size: 20,),
//                 title: Text('Add Friends'),
//                 trailing: Icon(Icons.arrow_forward_ios,size: 15,),
//               ),
//             ),

//             // Contact result
//             Obx(() {
//               // Check loading
//               if (
//                 //controller.selectedView.value == 0
//                  // ?
//                    controller.isLoading2.value
//                   //: controller.isLoading2.value
//                   ) {
//                 return const Padding(
//                   padding: EdgeInsets.only(top: 50),
//                   child: LoadingIndicator(size: 50),
//                 );
//               } else if (controller.contact.value == null) {
//                 return Padding(
//                   padding: const EdgeInsets.only(top: 50),
//                   child: NoData(
//                     iconData: IconlyLight.search,
//                     text: 'search'.tr,
//                   ),
//                 );
//               }
//               // Get contact
//               final User user = controller.contact.value!;

//               return ContactCard(
//                 user: user,
//                 onPress: () {
//                   // Closes keyboard
//                   FocusScope.of(context).unfocus();

//                   // Add contact to list
//                   ContactApi.addContact(userId: user.userId);

//                   // Go to messages page
//                   RoutesHelper.toMessages(user: user).then((_) {
//                     Get.back(); // Closes contacts page
//                     Get.back(); // Closes search contacts page
//                   });
//                 },
//               );
//             }),
//           ],
//         ),
//       ),
//     );
//   }
// }

import 'package:cloud_firestore/cloud_firestore.dart';
//import 'package:contacts_service/contacts_service.dart';

class ContactSearchScreen extends StatefulWidget {
  const ContactSearchScreen({super.key});

  @override
  State<ContactSearchScreen> createState() => _ContactSearchScreenState();
}

class _ContactSearchScreenState extends State<ContactSearchScreen> {
  List<ContactInfo> _contacts = [];
  List<ContactInfo> _matchedContacts = [];
  List<ContactInfo> _filteredMatchedContacts = [];
  bool _isLoading = true;
  bool _permissionDenied = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _filteredMatchedContacts.clear();
    _fetchContacts();
    _searchController.addListener(_filterMatchedContacts);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _requestContactPermission() async {
    var status = await Permission.contacts.status;
    if (status.isDenied) {
      status = await Permission.contacts.request();
    }
    if (status.isPermanentlyDenied) {
      setState(() {
        _permissionDenied = true;
      });
    }
  }

  Future<void> _fetchContacts() async {
    await _requestContactPermission();
    var permissionStatus = await Permission.contacts.status;

    if (permissionStatus.isGranted) {
      Iterable<ContactInfo> contacts = await FlutterContactsService.getContacts();
      setState(() {
        _contacts = contacts.toList();
      });
      await _matchUser();
    } else {
      setState(() {
        _permissionDenied = true;
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<List<Map<String, dynamic>>> getAppUsers() async {
    List<Map<String, dynamic>> appUsers = [];
    QuerySnapshot usersSnapshot =
        await FirebaseFirestore.instance.collection('Users').get();
    for (var doc in usersSnapshot.docs) {
      appUsers.add(doc.data() as Map<String, dynamic>);
    }
    return appUsers;
  }

  Future<void> _matchUser() async {
    List<Map<String, dynamic>> appUsers = await getAppUsers();

    List<ContactInfo> matchedContacts = [];
    List<ContactInfo> unmatchedContacts = [];

    for (var contact in _contacts) {
      var displayName = contact.displayName ?? '';
      bool isMatched = appUsers.any((user) =>
          user['fullname'] != null &&
          user['fullname'].toLowerCase() == displayName.toLowerCase());

      if (isMatched) {
        matchedContacts.add(contact);
      } else {
        unmatchedContacts.add(contact);
      }
    }

    setState(() {
      _matchedContacts = matchedContacts;
      _filteredMatchedContacts = matchedContacts;
      //  _unmatchedContacts = unmatchedContacts;
    });
  }

  void _filterMatchedContacts() {
    String query = _searchController.text.toLowerCase();

    setState(() {
      _filteredMatchedContacts = _matchedContacts
          .where((contact) =>
              (contact.displayName ?? '').toLowerCase().contains(query))
          .toList();
    });
    check();
    
  }
  Future<void> check()async{
    if (_permissionDenied) return;
    List<ContactInfo> contacts = await FlutterContactsService.getContacts(
  query: _searchController.text.toLowerCase().toString()
);
 debugPrint(contacts.toString());
  debugPrint(contacts.length.toString());
  }

  Future getUserData(String displayName) async {
    try {
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('Users')
          .where('fullname', isGreaterThanOrEqualTo: displayName.toLowerCase())
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        Map<String, dynamic> data =
            querySnapshot.docs.first.data() as Map<String, dynamic>;

        User user = User.fromMap(data);
        return user;
      } else {
        debugPrint('No user found with this display name');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching user data: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: Text("search_contact".tr),
      ),
      body:
       _permissionDenied
          ? Center(
              child: Text('Permission is required to access contacts.'),
            )
          :
           _isLoading
              ? Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Enter name',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8.0),
                          ),
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        Get.to(() => NumberSearchScreen());
                      },
                      child: ListTile(
                        leading: Icon(
                          Icons.person_add,
                          color: primaryColor,
                          size: 20,
                        ),
                        title: Text('Add Friends'),
                        trailing: Icon(
                          Icons.arrow_forward_ios,
                          size: 15,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _filteredMatchedContacts.isEmpty
                          ? Center(child: Text('No matched users found.'))
                          : ListView.builder(
                              itemCount: _filteredMatchedContacts.length,
                              itemBuilder: (context, index) {
                                var contact = _filteredMatchedContacts[index];
                                var displayName = contact.displayName ?? '';

                                return ListTile(
                                  title: Text(displayName),
                                  // subtitle: Text(contact.phones?.first.value.toString()??'aa'),
                                  onTap: () async {
                                    var user = await getUserData(displayName);
                                    debugPrint(user.toString());
                                    
                                    if (!context.mounted) return;
                                    FocusScope.of(context).unfocus();

                                    if (user != null) {
                                      ContactApi.sendFriendRequest(
                                          targetUserId: user.userId);
                                    }
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
