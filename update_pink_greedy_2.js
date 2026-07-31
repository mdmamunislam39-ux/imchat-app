const fs = require('fs');

const filePath = 'c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\audio_rooms_v2\\widgets\\pink_greedy_game_sheet.dart';
let content = fs.readFileSync(filePath, 'utf8');

// Replace "Available Coins" or similar with "Kalan madeni paralar"
// Wait, the current text is just the diamond count, there's no "Available Coins" label in the footer.
// Let's check _buildBettingArea() and _buildPrizeArea()

// Prize Area (Pizza and Salad)
// We need to change the style to match bubbles.

content = content.replace(
  /borderRadius: BorderRadius\.circular\(14\)/g,
  "shape: BoxShape.circle"
);
content = content.replace(
  /borderRadius: BorderRadius\.circular\(16\)/g,
  "shape: BoxShape.circle" // For prize area
);

// We want to add the text "Miktarı seçin -> Yemeği seçin" in betting area
// and "Kalan madeni paralar" in footer? Wait, footer currently just has "Result".
// Let's rewrite _buildBettingArea and _buildFooter entirely.

const bettingAreaReplacement = Widget _buildBettingArea() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFF007F),
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'Miktarı seçin -> Yemeği seçin',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFF00FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: (_isSuper ? superChips : normalChips).map((amount) {
                  return GestureDetector(
                    onTap: () {
                      if (isBettingOpen) {
                        setState(() {
                          selectedChip = amount;
                        });
                      }
                    },
                    child: _buildChip(amount),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF007F),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Kalan madeni paralar', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                              StreamBuilder<DocumentSnapshot>(
                                stream: FirebaseFirestore.instance.collection('Users').doc(currentUserId).snapshots(),
                                builder: (context, snapshot) {
                                  int diamonds = 0;
                                  if (snapshot.hasData && snapshot.data!.exists) {
                                    final data = snapshot.data!.data() as Map<String, dynamic>;
                                    diamonds = data['diamonds'] ?? 0;
                                  }
                                  return Text(diamonds.toString(), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold));
                                }
                              ),
                            ],
                          ),
                          Container(
                            decoration: const BoxDecoration(color: Colors.amber, shape: BoxShape.circle),
                            child: const Icon(Icons.add, color: Colors.deepOrange, size: 20),
                          )
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF007F),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          const Text('Bugün kazandım', style: TextStyle(color: Colors.amber, fontSize: 10, fontWeight: FontWeight.bold)),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance.collection('pink_greedy_game_leaderboard').doc('daily').collection(todayDate).where('userId', isEqualTo: currentUserId).snapshots(),
                            builder: (context, snapshot) {
                              int won = 0;
                              if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                                final data = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                                won = data['totalWon'] ?? 0;
                              }
                              return Text(won.toString(), style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold));
                            }
                          ),
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ],
          ),
        )
      ],
    );
  }
  
  // Replace old _buildFooter with new one
  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFC200FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('Sonuç', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  ...history.map((e) {
                    final imgPath = _getFoodImageFromEmoji(e);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2.0),
                      child: imgPath != null
                          ? Image.asset(
                              imgPath,
                              width: 20,
                              height: 20,
                              errorBuilder: (context, error, stackTrace) =>
                                  Text(e, style: const TextStyle(fontSize: 16)),
                            )
                          : Text(e, style: const TextStyle(fontSize: 16)),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  };

content = content.replace(/Widget _buildBettingArea\(\) \{[\s\S]*?Widget _buildFooter\(\) \{[\s\S]*?Widget _buildResultBox\(/, bettingAreaReplacement + '\n\n  Widget _buildResultBox(');

fs.writeFileSync(filePath, content, 'utf8');
console.log('Update done part 2');
