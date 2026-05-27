import re

with open('app/src/main/java/com/example/hackathon/GymApp.kt', 'r', encoding='utf-8') as f:
    text = f.read()

target = r'''                    try \{
                        var actualMirrored = isFrontCamera
                        if \(!cameraProvider\.hasCamera\(cameraSelector\)\) \{
                            cameraSelector = if \(isFrontCamera\) \{
                                actualMirrored = false
                                androidx\.camera\.core\.CameraSelector\.DEFAULT_BACK_CAMERA
                            \} else \{
                                actualMirrored = true
                                androidx\.camera\.core\.CameraSelector\.DEFAULT_FRONT_CAMERA
                            \}
                        \}
                        
                        // We store whether the finally selected camera is actually the front camera 
                        // so our Canvas knows if it needs to mirror the X axis
                        previewView\.setTag\(androidx\.core\.R\.id\.tag_unhandled_key_event_manager, actualMirrored\)'''

new_text = r'''                    try {
                        var actualMirrored = isFrontCamera
                        if (!cameraProvider.hasCamera(cameraSelector)) {
                            cameraSelector = if (isFrontCamera) {
                                actualMirrored = false
                                androidx.camera.core.CameraSelector.DEFAULT_BACK_CAMERA
                            } else {
                                actualMirrored = true
                                androidx.camera.core.CameraSelector.DEFAULT_FRONT_CAMERA
                            }
                        }
                        isMirrored = actualMirrored'''

text = re.sub(target, new_text, text, count=1)

with open('app/src/main/java/com/example/hackathon/GymApp.kt', 'w', encoding='utf-8') as f:
    f.write(text)
