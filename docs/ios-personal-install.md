# Dry Trying on your own iPhone (free, no App Store)

The full game, installed straight from this Mac over a USB cable, signed with a free Apple ID ("Personal Team").
Free installs stop opening after **7 days**; plug the phone in and press Play in Xcode again to renew (your save stays).
TestFlight (send it to the phone without a cable, 90-day builds) needs the paid Apple Developer Program, $99/yr.

## Once

1. **Install Xcode**: App Store app on the Mac, search "Xcode", Get. Big download. Open it once and let it install
   its extra parts (it asks; pick iOS).
2. **Sign in**: Xcode > Settings (Cmd+,) > Accounts > the + button > Apple ID > your normal Apple ID.
   A team called "Your Name (Personal Team)" appears.
3. **Phone**: plug the iPhone into the Mac with its cable, unlock it, tap **Trust** and enter the phone's passcode.
4. **Developer Mode** (iOS 16+): on the phone, Settings > Privacy & Security > Developer Mode (at the very bottom) > on.
   The phone restarts; after it, tap Turn On. (If the switch isn't there yet, it shows up after step 6 tries once.)

## Each build

5. In Terminal, in the game folder: `./tools/ios_build.sh`. It makes `build/ios/DryTrying.xcodeproj` and opens it.
6. In Xcode: click **DryTrying** at the top of the left list > **Signing & Capabilities** tab > tick
   **Automatically manage signing** > Team: **Your Name (Personal Team)**. If it says the bundle id is taken, change
   `com.averyblue.drytrying` to anything unique (e.g. add your initials).
7. At the top of the Xcode window pick your iPhone as the run target, then press the **Play** button (Cmd+R).
8. The first time, the phone says "Untrusted Developer": Settings > General > **VPN & Device Management** > your
   Apple ID > **Trust**. Press Play in Xcode again (or tap the app icon).

Free Personal Team limits: 3 apps per phone at once, the 7-day expiry above.

## Notes

- The preset is `iOS` in `export_presets.cfg` (export project only, placeholder team `ABCDE12345`;
  `./tools/ios_build.sh TEAMID` fills a real one for that build only). Icon: `assets/ios/icon_1024.png` from
  `tools/make_ios_icon.gd` (nearest-neighbor 16x of `icon.png`, no alpha). Landscape only (sensor landscape).
- Touch controls are the game's own (`TouchControls`: joystick left half, JUMP right half, pause top right).
- Saves live in the app (`user://` = the app's Documents); deleting the app deletes the save.
- Store release later needs the paid program, a final bundle id (M8) and the port-time checks in
  [spring-cleaning/phase5-platform.md](spring-cleaning/phase5-platform.md).
