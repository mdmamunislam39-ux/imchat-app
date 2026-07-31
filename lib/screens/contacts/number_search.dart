import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_iconly/flutter_iconly.dart';
import 'package:chat_messenger/api/contact_api.dart';
import 'package:chat_messenger/components/custom_appbar.dart';
import 'package:chat_messenger/components/loading_indicator.dart';
import 'package:chat_messenger/components/no_data.dart';
import 'package:chat_messenger/config/theme_config.dart';
import 'package:chat_messenger/helpers/app_helper.dart';
import 'package:chat_messenger/models/user.dart';
import 'package:get/get.dart';

import 'components/contact_card.dart';
import 'controllers/contact_search_controller.dart';

class NumberSearchScreen extends StatelessWidget {
  const NumberSearchScreen({super.key});
  // String countryCode = '+1';
  // String isoCountryCode = 'US';

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(ContactSearchController());

    return Scaffold(
      appBar: CustomAppBar(
        title: Text("Add Friends"),
      ),

      body: SafeArea(
        child: Column(
          children: [
            Form(
              key: controller.formKey,
              child: Row(
               // mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CountryCodePicker(
                    onChanged: (val) {
                      controller.countryCode.value = val.toString();
                      controller.isoCountryCode.value = val.code!;
                    },
                    textStyle:
                        TextStyle(fontSize: 16, color: primaryColor),
                    dialogTextStyle:
                        TextStyle(fontSize: 12, color: primaryColor),
                    initialSelection: 'BD',
                    favorite: ['+39', 'US'],
                    showCountryOnly: false,
                    showOnlyCountryWhenClosed: false,
                    alignLeft: false,
                  ),
                  Expanded(
                    child: TextFormField(
                      autofocus: true,
                      // onChanged: (value) {
                      //   controller.searchContactForNumber();
                      // },
                      onChanged: (value) {
                        debugPrint(controller.numberController.text[0]);
                        if (controller.numberController.text[0]=='0') {
                          debugPrint('matchhhhhhhhh');
                         var a = controller.numberController.text.substring(1);
                         debugPrint(a);
                        }
                       // controller.numberController.text[0].replaceRange(0, 1, '');
                       // debugPrint(controller.numberController.text.trim());

                      },
                      onFieldSubmitted: (String value) =>
                          controller.searchContactForNumber(),
                      textInputAction: TextInputAction.search,
                      validator: (val) {
                        if (val!.isEmpty) {
                          return "number can't be null";
                        }
                        if (val.length > 10) {
                          return 'check your number';
                        }
                        return null;
                      },
                      inputFormatters: AppHelper.usernameFormatter,
                      controller: controller.numberController,
                      decoration: InputDecoration(
                        hintText: 'search number',
                        // prefixIcon: const Icon(Icons.alternate_email),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.search),
                          onPressed: () =>
                              controller.searchContactForNumber(),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            //Searh Contact

            // Contact result
            Obx(() {
              // Check loading
              if (
                  //controller.selectedView.value == 0
                  // ?
                  controller.isLoading.value
                  //: controller.isLoading2.value
                  ) {
                return const Padding(
                  padding: EdgeInsets.only(top: 50),
                  child: LoadingIndicator(size: 50),
                );
              } else if (controller.contact.value == null) {
                return Padding(
                  padding: const EdgeInsets.only(top: 50),
                  child: NoData(
                    iconData: IconlyLight.search,
                    text: 'search'.tr,
                  ),
                );
              }
              // Get contact
              final User user = controller.contact.value!;

              return ContactCard(
                user: user,
                onPress: () {
                  // Closes keyboard
                  FocusScope.of(context).unfocus();

                  // Send friend request
                  ContactApi.sendFriendRequest(targetUserId: user.userId);
                },
              );
            }),
          ],
        ),
      ),
    );
  }
}
