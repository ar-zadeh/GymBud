import re

with open('app/src/main/java/com/example/hackathon/GymApp.kt', 'r', encoding='utf-8') as f:
    text = f.read()

target = r'''    var imageSize by remember \{ mutableStateOf\(androidx\.compose\.ui\.unit\.IntSize\(1, 1\)\) \}
    var isFrontCamera by remember \{ mutableStateOf\(true\) \}'''

new_text = r'''    var imageSize by remember { mutableStateOf(androidx.compose.ui.unit.IntSize(1, 1)) }
    var isFrontCamera by remember { mutableStateOf(true) }
    var isMirrored by remember { mutableStateOf(true) }'''

text = re.sub(target, new_text, text, count=1)

with open('app/src/main/java/com/example/hackathon/GymApp.kt', 'w', encoding='utf-8') as f:
    f.write(text)
