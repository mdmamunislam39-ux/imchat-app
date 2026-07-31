const fs = require('fs');
const path = require('path');

const libDir = path.join(__dirname, 'lib');
const importStmt = "import 'package:chat_messenger/components/dynamic_diamond_icon.dart';\n";

const pattern = /Image\.asset\(\s*['"]assets\/images\/diamond_icon\.png['"]\s*([\s\S]*?)\)/g;

function walk(dir) {
    let results = [];
    const list = fs.readdirSync(dir);
    list.forEach(file => {
        file = path.join(dir, file);
        const stat = fs.statSync(file);
        if (stat && stat.isDirectory()) {
            results = results.concat(walk(file));
        } else {
            if (file.endsWith('.dart') && !file.endsWith('dynamic_diamond_icon.dart') && !file.endsWith('dynamic_bean_icon.dart')) {
                results.push(file);
            }
        }
    });
    return results;
}

const files = walk(libDir);

files.forEach(file => {
    let content = fs.readFileSync(file, 'utf8');
    if (content.includes('assets/images/diamond_icon.png')) {
        let count = 0;
        let newContent = content.replace(pattern, (match, args) => {
            count++;
            args = args.trim();
            if (args.startsWith(',')) {
                args = args.substring(1).trim();
            }
            return `DynamicDiamondIcon(${args})`;
        });

        if (count > 0) {
            if (!newContent.includes('dynamic_diamond_icon.dart')) {
                const importRegex = /^import .*?;/gm;
                let lastIndex = 0;
                let match;
                while ((match = importRegex.exec(newContent)) !== null) {
                    lastIndex = match.index + match[0].length;
                }
                
                if (lastIndex > 0) {
                    newContent = newContent.substring(0, lastIndex) + '\n' + importStmt + newContent.substring(lastIndex);
                } else {
                    newContent = importStmt + newContent;
                }
            }
            
            fs.writeFileSync(file, newContent, 'utf8');
            console.log(`Updated ${file} (${count} occurrences)`);
        }
    }
});
