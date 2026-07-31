
import 'package:chat_messenger/screens/room/controller/emoji_controller.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class EmojiBottomSheet extends StatelessWidget {
  final Function ontapEmojiSend;
  EmojiBottomSheet(this.ontapEmojiSend, {super.key});
  final EmojiController controller = Get.put(EmojiController());

  @override
Widget build(BuildContext context) {
  return Container(
    height: MediaQuery.of(context).size.height * 0.5,
    //color: darkThemeBgColor,
    padding: const EdgeInsets.all(5),
    child: Column(
      children: [
          TabBar(
              isScrollable: true,
              controller: controller.tabController,
              labelPadding: EdgeInsets.symmetric(horizontal: 8), 
              unselectedLabelColor: Colors.grey,
              labelColor: Colors.black,
              labelStyle: TextStyle(fontWeight: FontWeight.bold),
              dividerColor: Colors.transparent,
              indicatorColor: Colors.green,
              tabs: controller.tabTitles
              .map((title) => Tab(text: title))
              .toList(),
            ),
        const SizedBox(height: 16),
        Expanded(
          child: Obx(() {
            if (controller.emojis.isEmpty) {
              return const Center(child: CircularProgressIndicator());
            }
            final _ = controller.selectedIndexes.values.toList();
            return GridView.builder(
              itemCount: controller.emojis.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 1.1,
              ),
              itemBuilder: (context, index) {
                final emoji = controller.emojis[index];
                
                final isSelected = controller.isSelected(index);
                return GestureDetector(
                  onTap: () {
                    controller.toggleBorder(index);
                    ontapEmojiSend(emoji);
                    Get.back();
                  },
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: isSelected ? Colors.green : Colors.transparent,width: 2)
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child:  Image.network(
                            emoji['emoji_url'] ?? '',
                            fit: BoxFit.cover,
                            height: 25,
                          ),
    ),
                        
                        Padding(
                          padding: const EdgeInsets.only(bottom: 5.0),
                          child: Text('${emoji['emoji_name'] ?? ''}'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }),
        ),
       
        //    Align(alignment: Alignment.bottomRight,child: ElevatedButton(onPressed: (){}, child: Text('Send',style: TextStyle(color: Colors.white),)))
         
      ],
    ),
  );
}

}

