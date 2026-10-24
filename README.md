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

- Top half of the screen: jump. Clears crates, stacks, and gaps.
- Bottom half: roll. Goes under rails, and knocks a guy in the lane onto his back.
- Sweeper bars still move. Run under them when they are high. Jump them when they are low.

The runner is small on purpose. Three hits restart the stretch. They do not end the game. The game ends when you cross the green gate on stretch 8.

Cleared stretches stay unlocked on this device.
