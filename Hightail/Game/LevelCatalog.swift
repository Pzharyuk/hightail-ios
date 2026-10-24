import CoreGraphics
import Foundation

/// What the runner has to read. Introduced one at a time, then combined.
enum ObstacleKind: String {
    case crate
    case stack
    case rail
    case gap
    case sweeper
    case enemy
}

struct ObstacleSpawn {
    var distance: CGFloat
    var kind: ObstacleKind
    var width: CGFloat
}

struct Stretch {
    let index: Int
    let name: String
    let blurb: String
    let hint: String
    /// Points per second the road moves.
    let speed: CGFloat
    /// World distance from the start line to the gate.
    let length: CGFloat
    let spawns: [ObstacleSpawn]
}

/// The difficulty curve. Edit a row; do not hide numbers in the scene.
enum LevelCatalog {
    static let stretches: [Stretch] = specs.enumerated().map { offset, spec in
        make(index: offset + 1, spec: spec)
    }

    static var count: Int { stretches.count }

    static func stretch(_ index: Int) -> Stretch {
        let clamped = min(max(index, 1), count)
        return stretches[clamped - 1]
    }

    private struct Spec {
        var name: String
        var blurb: String
        var hint: String
        var speed: CGFloat
        var length: CGFloat
        var spacing: CGFloat
        var kinds: [ObstacleKind]
        var combos: Bool
    }

    private static let specs: [Spec] = [
        Spec(
            name: "Alley",
            blurb: "One kind of problem.",
            hint: "Tap the top half of the screen to jump.",
            speed: 300, length: 8600, spacing: 860,
            kinds: [.crate], combos: false
        ),
        Spec(
            name: "Dock",
            blurb: "Rails over the lane.",
            hint: "Tap the bottom half to roll. Don't jump the rails.",
            speed: 345, length: 10200, spacing: 700,
            kinds: [.crate, .rail], combos: false
        ),
        Spec(
            name: "Yard",
            blurb: "The stacks got taller.",
            hint: "Stacks are wider. Jump earlier.",
            speed: 390, length: 11800, spacing: 600,
            kinds: [.crate, .stack, .rail], combos: false
        ),
        Spec(
            name: "Overpass",
            blurb: "The ground goes missing.",
            hint: "Jump the gaps and stay in the air.",
            speed: 440, length: 13600, spacing: 540,
            kinds: [.crate, .rail, .gap], combos: false
        ),
        Spec(
            name: "Sweep",
            blurb: "Guys in the lane.",
            hint: "Roll through them. They go down.",
            speed: 490, length: 15400, spacing: 480,
            kinds: [.crate, .enemy, .rail, .sweeper, .gap], combos: false
        ),
        Spec(
            name: "Scaffold",
            blurb: "They come in pairs now.",
            hint: "Jump, then roll. A roll drops the guys.",
            speed: 545, length: 17200, spacing: 430,
            kinds: [.crate, .enemy, .stack, .rail, .gap, .sweeper], combos: true
        ),
        Spec(
            name: "Highway",
            blurb: "Less road between mistakes.",
            hint: "Same problems. Less time.",
            speed: 600, length: 19600, spacing: 370,
            kinds: [.enemy, .crate, .stack, .rail, .sweeper, .gap], combos: true
        ),
        Spec(
            name: "Bridge",
            blurb: "Everything. Then the gate.",
            hint: "Roll the guys. Jump the rest. The quiet means you're close.",
            speed: 650, length: 23000, spacing: 320,
            kinds: [.enemy, .crate, .stack, .rail, .sweeper, .gap], combos: true
        ),
    ]

    private static func make(index: Int, spec: Spec) -> Stretch {
        Stretch(
            index: index,
            name: spec.name,
            blurb: spec.blurb,
            hint: spec.hint,
            speed: spec.speed,
            length: spec.length,
            spawns: spawns(index: index, spec: spec)
        )
    }

    /// First obstacle after a short runway. Nothing in the last ~2.4 seconds,
    /// so every stretch ends as a clean sprint into the gate.
    private static func spawns(index: Int, spec: Spec) -> [ObstacleSpawn] {
        let quiet = spec.speed * 2.4
        let end = spec.length - quiet
        var distance = spec.speed * 2.0
        var list: [ObstacleSpawn] = []
        var n = 0
        while distance < end {
            let kind = spec.kinds[n % spec.kinds.count]
            list.append(ObstacleSpawn(distance: distance, kind: kind, width: width(kind, index: index, speed: spec.speed)))
            if spec.combos && (kind == .crate || kind == .stack) && spec.kinds.contains(.rail) && n % 2 == 1 {
                let railAt = distance + 230
                if railAt < end {
                    list.append(ObstacleSpawn(distance: railAt, kind: .rail, width: width(.rail, index: index, speed: spec.speed)))
                    distance = railAt
                }
            }
            distance += spec.spacing
            if kind == .gap { distance += 140 }
            n += 1
        }
        return list
    }

    private static func width(_ kind: ObstacleKind, index: Int, speed: CGFloat) -> CGFloat {
        switch kind {
        case .crate: return 34
        case .stack: return 52
        case .enemy: return 28
        case .rail: return 64
        case .sweeper: return 52
        case .gap:
            let want = 130 + CGFloat(max(0, index - 4)) * 22
            return min(want, speed * 0.46)
        }
    }
}
