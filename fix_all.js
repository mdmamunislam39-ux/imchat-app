const fs = require('fs');
const path = require('path');

function walk(dir) {
  let results = [];
  const list = fs.readdirSync(dir);
  list.forEach(function (file) {
    file = path.join(dir, file);
    const stat = fs.statSync(file);
    if (stat && stat.isDirectory()) {
      results = results.concat(walk(file));
    } else {
      if (file.endsWith('.dart')) results.push(file);
    }
  });
  return results;
}

const files = walk('lib');

files.forEach(file => {
  let content = fs.readFileSync(file, 'utf8');
  let originalContent = content;

  // 1. Replace .withOpacity( with .withValues(alpha: 
  content = content.replace(/\.withOpacity\(/g, '.withValues(alpha: ');

  // 2. Replace print( with debugPrint(
  // Need to be careful not to replace things like `print(something)` if it's commented, but it's fine.
  if (content.match(/[^a-zA-Z0-9_]print\(/)) {
    content = content.replace(/([^a-zA-Z0-9_])print\(/g, '$1debugPrint(');
    content = content.replace(/^print\(/gm, 'debugPrint(');

    // Check if material or foundation is imported
    if (!content.includes('package:flutter/material.dart') && !content.includes('package:flutter/foundation.dart')) {
      content = "import 'package:flutter/material.dart';\n" + content;
    }
  }

  // 3. Fix Parameter 'key' could be a super parameter
  // We look for patterns like:
  // const MyWidget({Key? key, required this.foo}) : super(key: key);
  // and convert to:
  // const MyWidget({super.key, required this.foo});

  // A simple regex for the common case:
  // ({Key? key, ...}) : super(key: key); -> ({super.key, ...});
  content = content.replace(/\{(\s*)Key\?\s*key\s*,/g, '{$1super.key,');
  content = content.replace(/\{(\s*)Key\?\s*key(\s*)\}/g, '{$1super.key$2}');
  content = content.replace(/:\s*super\s*\(\s*key\s*:\s*key\s*\)/g, '');

  if (content !== originalContent) {
    fs.writeFileSync(file, content, 'utf8');
    console.log('Modified ' + file);
  }
});
