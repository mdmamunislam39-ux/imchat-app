import 'package:flutter/material.dart';

class RouletteRulesSheet extends StatelessWidget {
  const RouletteRulesSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Rules',
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  fontStyle: FontStyle.italic,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.black54),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: ListView(
              children: [
                _buildRuleItem(
                  '1.',
                  'To customize a roulette, click the [edit] icon to enter the editing page and add the possible options as you like for decisions. Just create your roulette and have fun!',
                ),
                const SizedBox(height: 20),
                _buildRuleItem(
                  '2.',
                  'Number Roulette can have up to 9 numbers for decision. For instance, take the numbers as Mic seat order, and when a user on the corresponding Mic seat is picked by the roulette, he/she should complete a task as required.',
                ),
                const SizedBox(height: 20),
                _buildRuleItem(
                  '3.',
                  'Custom Roulette can be used to decide punishment/reward for room games like HeartBeat Party, Auction, Vote, and PK Game.',
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRuleItem(String number, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          number,
          style: const TextStyle(
            color: Colors.blueAccent,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.black87,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}
