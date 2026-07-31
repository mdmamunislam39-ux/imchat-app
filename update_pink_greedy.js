const fs = require('fs');

const filePath = 'c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\audio_rooms_v2\\widgets\\pink_greedy_game_sheet.dart';
let content = fs.readFileSync(filePath, 'utf8');

// Replace "Result" with "Sonuç"
content = content.replace(/const Text\('Result'/g, "const Text('Sonuç'");
content = content.replace(/'Result of Round /g, "'Sonuç of Round ");

// Replace center circle text
content = content.replace(
  /Text\([\s\S]*?'Round \',[\s\S]*?style: const TextStyle\([\s\S]*?color: Colors\.white,[\s\S]*?fontSize: 13,[\s\S]*?fontWeight: FontWeight\.bold\),[\s\S]*?\),/g,
  Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.yellowAccent,
                    boxShadow: [
                      BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2)),
                    ],
                  ),
                  child: const Text(
                    'Zaman Seçin',
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
);

content = content.replace(
  /Container\([\s\S]*?padding:[\s\S]*?const EdgeInsets\.symmetric\(horizontal: 18, vertical: 5\),[\s\S]*?decoration: BoxDecoration\([\s\S]*?color: _isSuper \? const Color\(0xFF4A0066\) : Colors\.pink\[900\],[\s\S]*?borderRadius: BorderRadius\.circular\(20\),[\s\S]*?border: _isSuper \? Border\.all\(color: Colors\.white24\) : null,[\s\S]*?\),[\s\S]*?child: Text\([\s\S]*?'\$\{timeLeft\}s',[\s\S]*?style: const TextStyle\([\s\S]*?color: Colors\.white,[\s\S]*?fontSize: 18,[\s\S]*?fontWeight: FontWeight\.bold\),[\s\S]*?\),[\s\S]*?\),/g,
  Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFF00FF),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(50),
                      bottomRight: Radius.circular(50),
                    ),
                  ),
                  child: Text(
                    '\s',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
);


fs.writeFileSync(filePath, content, 'utf8');
console.log('Update done');
