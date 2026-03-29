import re

with open('app/src/main/java/com/example/hackathon/GymApp.kt', 'r', encoding='utf-8') as f:
    text = f.read()

target = r'''                fun getPoint\(landmarkType: Int\): androidx\.compose\.ui\.geometry\.Offset\? \{
                    val lm = pose\.getPoseLandmark\(landmarkType\) \?: return null
                    val x = if \(isFrontCamera\) \{
                        imageSize\.width - lm\.position\.x
                    \} else \{
                        lm\.position\.x
                    \}'''

new_text = r'''                fun getPoint(landmarkType: Int): androidx.compose.ui.geometry.Offset? {
                    val lm = pose.getPoseLandmark(landmarkType) ?: return null
                    val x = if (isMirrored) {
                        imageSize.width - lm.position.x
                    } else {
                        lm.position.x
                    }'''

text = re.sub(target, new_text, text, count=1)

with open('app/src/main/java/com/example/hackathon/GymApp.kt', 'w', encoding='utf-8') as f:
    f.write(text)
