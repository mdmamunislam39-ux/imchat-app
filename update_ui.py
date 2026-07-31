import re

file_path = r'c:\imchat-new-own-dev\imchat-new-own-dev\lib\screens\audio_rooms_v2\widgets\pink_greedy_game_sheet.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Update win text to xMultiplier
content = re.sub(r"'win': 'Win (\d+) Times'", r"'win': 'x\1'", content)

# Change header text to Greedy Pink with specific font style
header_replacement = '''Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              _buildIconButton(Icons.watch_later_rounded, () {}),
              const SizedBox(width: 8),
              _buildIconButton(Icons.volume_up_rounded, () {}),
            ],
          ),
          const Text(
            'Greedy Pink',
            style: TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.bold,
              fontFamily: 'serif',
            ),
          ),
          _buildIconButton(Icons.help_outline, () {}),
        ],
      ),
    );
  }'''
content = re.sub(r'Widget _buildHeader\(\) \{.*?(?=Widget _buildIconButton)', header_replacement + '\n\n  ', content, flags=re.DOTALL)

# Update build method for background
build_replacement = '''@override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF3B0B3C), Color(0xFF65154C), Color(0xFF901859)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 12),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: _buildWheelArea(),
                  ),
                  const SizedBox(height: 8),
                  _buildPrizeArea(),
                  const SizedBox(height: 8),
                  _buildBettingArea(),
                  const SizedBox(height: 12),
                  _buildFooter(),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }'''
content = re.sub(r'@override\s+Widget build\(BuildContext context\) \{.*?(?=Widget _buildHeader)', build_replacement + '\n\n  ', content, flags=re.DOTALL)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Updated build and header")
