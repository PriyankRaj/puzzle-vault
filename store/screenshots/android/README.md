# Regenerating these screenshots

Captured from the `bhasha_test` Android emulator (`emulator-5554`), resized
to a modern phone profile for the capture since the AVD's native
resolution (320×640) is too low-quality for a store listing:

```bash
flutter emulators --launch bhasha_test
# wait for boot, then:
adb -s emulator-5554 shell wm size 1080x2280   # snaps to 1080x1920 (9:16)
adb -s emulator-5554 shell wm density 440

flutter build apk --debug
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s emulator-5554 shell am start -n com.katariya.topgames/.MainActivity

# navigate the app, then for each screen:
adb -s emulator-5554 exec-out screencap -p > store/screenshots/android/NN_name.png

# afterwards, restore the emulator's normal display:
adb -s emulator-5554 shell wm size reset
adb -s emulator-5554 shell wm density reset
```

Screenshots are flattened to RGB (no alpha channel) before use, since Play
Store screenshot uploads shouldn't carry one:

```python
from PIL import Image
im = Image.open(path).convert("RGB")
im.save(path)
```

Tapping through the UI via `adb shell input tap` on this emulator has
historically been flaky for anything requiring precision (see
`CONTEXT.md`) — verify each screenshot actually shows the intended screen
before relying on it, rather than assuming the tap landed correctly.
