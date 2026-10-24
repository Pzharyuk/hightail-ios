# Hightail

An iPhone game about getting out. Eight stretches of road, each one meaner than the last, and one ending: you clear the bridge.

Hightail is the American way to say it. You hightail it. The run is over when you're gone, not when you crash.

Built with SwiftUI and SpriteKit. iOS 17. Landscape.

The design — what each stretch teaches, how the numbers stack, and what failure is allowed to mean — is in [DESIGN.md](DESIGN.md). The numbers themselves are in [Hightail/Game/LevelCatalog.swift](Hightail/Game/LevelCatalog.swift).

## Run it

1. Open `Hightail.xcodeproj` in Xcode 16 or newer.
2. Pick any iPhone simulator.
3. Run. The app starts in landscape.
4. To put it on a phone, set your Team under Signing & Capabilities. The simulator does not need one.

## How to play

You run on your own. Where you tap is the control.

- Top half: jump. A quick tap is a short hop. Hold for a long Mario jump, or tap again in the air.
- Bottom half: roll. Hold it and you stay tucked. If you roll off a gap, gravity keeps you falling. Let go and you open back up when you land.
- Animals run on all fours. Jump on their backs for 100. Hold a fast roll into them for 350.

The runner is small on purpose. Three hits restart the stretch. They do not end the game. The game ends when you cross the green gate on stretch 8.

Cleared stretches stay unlocked on this device.
