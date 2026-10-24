# Getaway

An iPhone game about getting away. Eight stretches of road, each one meaner than the last, and a single ending: you clear the bridge.

Built with SwiftUI and SpriteKit. iOS 17. Landscape.

The design — what each stretch teaches, how the numbers stack, and what failure is allowed to mean — is in [DESIGN.md](DESIGN.md). The numbers themselves are in [Getaway/Game/LevelCatalog.swift](Getaway/Game/LevelCatalog.swift).

## Run it

1. Open `Getaway.xcodeproj` in Xcode 16 or newer.
2. Pick any iPhone simulator.
3. Run. The app starts in landscape.
4. To put it on a phone, set your Team under Signing & Capabilities. The simulator does not need one.

## How to play

You run on your own.

- Tap, or JUMP, to clear crates, stacks, and gaps.
- Swipe down, or SLIDE, to go under rails.
- Sweeper bars move. Run under them when they are high. Jump them when they are low.

Three hits restart the stretch. They do not end the game. The game ends when you cross the green gate on stretch 8.

Cleared stretches stay unlocked on this device.
