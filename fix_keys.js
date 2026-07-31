const fs = require('fs');

const problems = [
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\audio_rooms_v2\\widgets\\waiting_list_bottom_sheet.dart","message":"Parameter 'key' could be a super parameter","startLine":14},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\audio_rooms_v2\\widgets\\ludo_game_widget.dart","message":"Parameter 'key' could be a super parameter","startLine":17},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\audio_rooms_v2\\widgets\\ludo\\ludo_board_widget.dart","message":"Parameter 'key' could be a super parameter","startLine":119},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\audio_rooms_v2\\widgets\\ludo\\ludo_dice_widget.dart","message":"Parameter 'key' could be a super parameter","startLine":12},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\audio_rooms_v2\\widgets\\ludo\\ludo_lobby_widget.dart","message":"Parameter 'key' could be a super parameter","startLine":13},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\audio_rooms_v2\\widgets\\ludo\\ludo_setup_bottom_sheet.dart","message":"Parameter 'key' could be a super parameter","startLine":8},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\audio_rooms_v2\\widgets\\voting\\voting_result_sheet.dart","message":"Parameter 'key' could be a super parameter","startLine":10},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\audio_rooms_v2\\widgets\\voting\\voting_setup_sheet.dart","message":"Parameter 'key' could be a super parameter","startLine":10},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\audio_rooms_v2\\widgets\\voting\\voting_widget.dart","message":"Parameter 'key' could be a super parameter","startLine":14},
  {"path":"c:\\imchat-new-own-dev\\imchat-new-own-dev\\lib\\screens\\audio_rooms_v2\\widgets\\youtube_selection_sheet.dart","message":"Parameter 'key' could be a super parameter","startLine":6}
];

const grouped = {};
problems.forEach(p => {
  if (!grouped[p.path]) grouped[p.path] = [];
  grouped[p.path].push(p);
});

for (const path of Object.keys(grouped)) {
  if (!fs.existsSync(path)) continue;
  let content = fs.readFileSync(path, 'utf8');
  let lines = content.split('\n');
  let modified = false;

  const fileProblems = grouped[path];
  fileProblems.sort((a, b) => b.startLine - a.startLine);

  for (const p of fileProblems) {
    const lineIndex = p.startLine - 1;
    if (lineIndex < 0 || lineIndex >= lines.length) continue;
    let line = lines[lineIndex];

    if (p.message.includes("Parameter 'key' could be a super parameter")) {
      // Trying to replace `{Key? key,` with `{super.key,` and remove `: super(key: key)`
      if (line.includes('Key? key')) {
        line = line.replace(/Key\?\s*key/g, 'super.key');
        line = line.replace(/:\s*super\s*\(\s*key\s*:\s*key\s*\)/g, '');
        lines[lineIndex] = line;
        modified = true;
      }
    }
  }

  if (modified) {
    fs.writeFileSync(path, lines.join('\n'), 'utf8');
    console.log(`Fixed keys in ${path}`);
  }
}
