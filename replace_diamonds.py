import os
import re

lib_dir = r'c:\imchat-new-own-dev\imchat-new-own-dev\lib'
import_stmt = "import 'package:chat_messenger/components/dynamic_diamond_icon.dart';\n"

pattern = re.compile(r"Image\.asset\(\s*['\"]assets/images/diamond_icon\.png['\"]\s*(.*?)\)")

for root, _, files in os.walk(lib_dir):
    for file in files:
        if file.endswith('.dart') and file not in ['dynamic_diamond_icon.dart', 'dynamic_bean_icon.dart']:
            filepath = os.path.join(root, file)
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            
            if 'assets/images/diamond_icon.png' in content:
                def repl(m):
                    args = m.group(1).strip()
                    if args.startswith(','):
                        args = args[1:].strip()
                    return f'DynamicDiamondIcon({args})'
                
                new_content, count = pattern.subn(repl, content)
                
                if count > 0:
                    if 'dynamic_diamond_icon.dart' not in new_content:
                        imports = list(re.finditer(r'^import .*?;', new_content, re.MULTILINE))
                        if imports:
                            last_import = imports[-1]
                            insert_pos = last_import.end() + 1
                            new_content = new_content[:insert_pos] + import_stmt + new_content[insert_pos:]
                        else:
                            new_content = import_stmt + new_content
                    
                    with open(filepath, 'w', encoding='utf-8') as f:
                        f.write(new_content)
                    print(f'Updated {filepath} ({count} occurrences)')
