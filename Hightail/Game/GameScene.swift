import SpriteKit
import UIKit

/// Side-view escape. The runner stays put; the road moves.
/// Crossing the gate ends the stretch. Nothing else ends the game.
final class GameScene: SKScene {
    let stretch: Stretch

    var onProgress: ((CGFloat, Int) -> Void)?
    var onClear: (() -> Void)?
    var onCaught: (() -> Void)?
    var onJump: (() -> Void)?
    var onRoll: (() -> Void)?
    var onKnock: (() -> Void)?
    var onHit: (() -> Void)?

    private let world = SKNode()
    private let props = SKNode()
    private let runner = SKNode()
    private let body = SKShapeNode(rectOf: CGSize(width: Stage.runWidth, height: Stage.runHeight), cornerRadius: 5)
    private let head = SKShapeNode(circleOfRadius: 5)
    private let scarf = SKShapeNode(rectOf: CGSize(width: 10, height: 4), cornerRadius: 1)
    private let shadow = SKShapeNode(ellipseOf: CGSize(width: 20, height: 5))

    private var ribbons: [Ribbon] = []
    private var hazards: [Hazard] = []
    private var cursor = 0
    private var exitNode: SKNode?
    private let exitWorldX: CGFloat
    private var exitArmed = false

    private var footY: CGFloat = Stage.groundY
    private var verticalVelocity: CGFloat = 0
    private var onGround = true
    private var rolling = false
    private var rollLeft: CGFloat = 0
    private var distance: CGFloat = 0
    private var lives = 3
    private var invulnerable: CGFloat = 0
    private var shake: CGFloat = 0
    private var reportWait: CGFloat = 0
    private var lastTime: TimeInterval = 0
    private var running = true
    private var built = false

    init(stretch: Stretch) {
        self.stretch = stretch
        exitWorldX = stretch.length
        super.init(size: Stage.sceneSize)
        scaleMode = .aspectFill
        anchorPoint = .zero
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("Hightail builds its scene in code")
    }

    override func didMove(to view: SKView) {
        view.ignoresSiblingOrder = true
        view.preferredFramesPerSecond = 60
        guard !built else { return }
        built = true
        backgroundColor = Palette.ink
        addChild(world)
        laySky()
        layRoad()
        props.zPosition = 6
        world.addChild(props)
        layRunner()
        layMoon()
    }

    func jump() {
        guard running, onGround else { return }
        onGround = false
        rolling = false
        verticalVelocity = Stage.jumpVelocity
        onJump?()
    }

    @discardableResult
    func roll() -> Bool {
        guard running, onGround else { return false }
        rolling = true
        rollLeft = 0.42
        onRoll?()
        return true
    }

    override func update(_ currentTime: TimeInterval) {
        guard built, running else { return }
        if lastTime == 0 {
            lastTime = currentTime
            return
        }
        let dt = CGFloat(min(0.032, currentTime - lastTime))
        lastTime = currentTime
        step(dt, time: currentTime)
    }

    private func step(_ dt: CGFloat, time: TimeInterval) {
        if invulnerable > 0 { invulnerable -= dt }
        runner.alpha = (invulnerable > 0 && Int(invulnerable * 14) % 2 == 0) ? 0.35 : 1

        if !onGround {
            verticalVelocity += Stage.gravity * dt
            footY += verticalVelocity * dt
            if footY <= Stage.groundY {
                footY = Stage.groundY
                verticalVelocity = 0
                onGround = true
            }
        }
        if rolling {
            rollLeft -= dt
            if rollLeft <= 0 || !onGround { rolling = false }
        }

        let dx = stretch.speed * dt
        distance += dx
        for ribbon in ribbons { ribbon.step(dx) }
        spawn()
        syncHazards(time)
        layoutRunner()
        shakeRoad(dt)

        if reachedGate() {
            finishClear()
            return
        }
        if invulnerable <= 0 {
            collide()
        }
        report(dt)
    }

    private func spawn() {
        let lead = size.width - Stage.playerX + 80
        while cursor < stretch.spawns.count {
            let spawn = stretch.spawns[cursor]
            if spawn.distance > distance + lead { break }
            let hazard = Hazard(spawn: spawn)
            hazards.append(hazard)
            props.addChild(hazard.node)
            if let pole = hazard.pole { props.addChild(pole) }
            cursor += 1
        }
        if !exitArmed && stretch.length - distance <= lead {
            let gate = makeGate()
            exitNode = gate
            props.addChild(gate)
            exitArmed = true
        }
    }

    private func syncHazards(_ time: TimeInterval) {
        for hazard in hazards {
            if hazard.struck {
                if hazard.node.parent == nil { hazard.gone = true }
                if hazard.kind == .enemy { continue }
            }
            let rect = hazard.rect(distance: distance, time: time)
            hazard.node.position = CGPoint(x: rect.midX, y: rect.midY)
            hazard.pole?.position = CGPoint(x: rect.midX, y: Stage.groundY + 78)
            if rect.maxX < -100 {
                hazard.node.removeFromParent()
                hazard.pole?.removeFromParent()
                hazard.gone = true
            }
        }
        hazards.removeAll { $0.gone }
        if let gate = exitNode {
            let left = Stage.playerX + (exitWorldX - distance)
            gate.position = CGPoint(x: left + 28, y: Stage.groundY + 110)
        }
    }

    private func collide() {
        let body = runnerBox()
        for hazard in hazards where !hazard.struck {
            if hazard.kind == .gap && !onGround { continue }
            let box = hazard.rect(distance: distance, time: lastTime).insetBy(dx: 2, dy: 2)
            if body.intersects(box) {
                if rolling && hazard.kind == .enemy {
                    knockDown(hazard)
                } else {
                    strike(hazard)
                    if !running { return }
                }
            }
        }
    }

    private func knockDown(_ hazard: Hazard) {
        hazard.struck = true
        hazard.node.run(.sequence([
            .group([
                .rotate(toAngle: -.pi / 2, duration: 0.14),
                .moveBy(x: 48, y: 6, duration: 0.18),
            ]),
            .fadeOut(withDuration: 0.12),
            .removeFromParent(),
        ]))
        onKnock?()
    }

    private func strike(_ hazard: Hazard) {
        hazard.struck = true
        hazard.node.run(.sequence([.fadeOut(withDuration: 0.12), .removeFromParent()]))
        hazard.pole?.run(.sequence([.fadeOut(withDuration: 0.12), .removeFromParent()]))
        lives -= 1
        invulnerable = 1.15
        shake = 0.16
        onHit?()
        reportNow()
        if lives <= 0 {
            running = false
            onCaught?()
        }
    }

    private func reachedGate() -> Bool {
        guard exitArmed else { return false }
        let left = Stage.playerX + (exitWorldX - distance)
        let gate = CGRect(x: left, y: Stage.groundY, width: 56, height: 220)
        return runnerBox().intersects(gate)
    }

    private func finishClear() {
        running = false
        reportNow()
        onClear?()
    }

    private func runnerBox() -> CGRect {
        let height = rolling ? Stage.rollHeight : Stage.runHeight
        let reach: CGFloat = rolling ? 12 : 0
        return CGRect(
            x: Stage.playerX - Stage.runWidth / 2,
            y: footY,
            width: Stage.runWidth + reach,
            height: height
        ).insetBy(dx: 2, dy: 1)
    }

    private func layoutRunner() {
        let height = rolling ? Stage.rollHeight : Stage.runHeight
        let bob: CGFloat = (onGround && !rolling) ? CGFloat(sin(Double(distance) * 0.045)) * 1.2 : 0
        runner.position = CGPoint(x: Stage.playerX, y: footY)
        body.position = CGPoint(x: 1, y: height / 2 + bob)
        body.yScale = height / Stage.runHeight
        body.xScale = rolling ? 1.35 : 1
        body.fillColor = rolling ? Palette.sodium : Palette.ivory
        if rolling {
            let t = 1 - max(0, rollLeft) / 0.42
            runner.zRotation = -t * .pi * 2
        } else {
            runner.zRotation = 0
        }
        head.isHidden = rolling
        scarf.isHidden = rolling
        shadow.isHidden = !onGround
        shadow.alpha = onGround ? 0.35 : 0
    }

    private func shakeRoad(_ dt: CGFloat) {
        shake = max(0, shake - dt)
        guard shake > 0 else {
            world.position = .zero
            return
        }
        let mag = shake * 36
        world.position = CGPoint(
            x: CGFloat.random(in: -mag...mag),
            y: CGFloat.random(in: -mag * 0.35...mag * 0.35)
        )
    }

    private func report(_ dt: CGFloat) {
        reportWait -= dt
        if reportWait <= 0 { reportNow() }
    }

    private func reportNow() {
        reportWait = 0.08
        onProgress?(min(1, distance / stretch.length), lives)
    }

    private func laySky() {
        let sky = SKSpriteNode(texture: Sky.texture, size: Stage.sceneSize)
        sky.position = CGPoint(x: Stage.sceneSize.width / 2, y: Stage.sceneSize.height / 2)
        sky.zPosition = -30
        world.addChild(sky)
    }

    private func layMoon() {
        let moon = SKShapeNode(circleOfRadius: 16)
        moon.fillColor = SKColor(red: 0.93, green: 0.90, blue: 0.82, alpha: 0.92)
        moon.strokeColor = .clear
        moon.position = CGPoint(x: 704, y: 318)
        moon.zPosition = -20
        world.addChild(moon)
    }

    private func layRoad() {
        let city = Ribbon(width: 980, factor: 0.32) { RoadArt.city(width: 980) }
        let lamps = Ribbon(width: 900, factor: 0.62) { RoadArt.lamps(width: 900) }
        let ground = Ribbon(width: 844, factor: 1) { RoadArt.ground(width: 844) }
        for ribbon in [city, lamps, ground] {
            for node in ribbon.nodes { world.addChild(node) }
            ribbons.append(ribbon)
        }
    }

    private func layRunner() {
        runner.zPosition = 10
        shadow.fillColor = .black
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 2, y: 3)
        shadow.zPosition = -1

        body.fillColor = Palette.ivory
        body.strokeColor = .clear
        scarf.fillColor = Palette.sodium
        scarf.strokeColor = .clear
        scarf.position = CGPoint(x: 5, y: 16)
        scarf.zRotation = -0.5

        head.fillColor = Palette.ivory
        head.strokeColor = .clear
        head.position = CGPoint(x: 5, y: Stage.runHeight - 1)
        let eye = SKShapeNode(circleOfRadius: 1.6)
        eye.fillColor = Palette.ink
        eye.strokeColor = .clear
        eye.position = CGPoint(x: 3, y: 1)
        head.addChild(eye)

        runner.addChild(shadow)
        runner.addChild(body)
        runner.addChild(scarf)
        runner.addChild(head)
        world.addChild(runner)
        layoutRunner()
    }

    private func makeGate() -> SKNode {
        let node = SKNode()
        node.zPosition = 0
        let wash = SKShapeNode(rectOf: CGSize(width: 120, height: 240), cornerRadius: 8)
        wash.fillColor = Palette.escape.withAlphaComponent(0.14)
        wash.strokeColor = Palette.escape.withAlphaComponent(0.0)
        node.addChild(wash)

        let beam = SKShapeNode(rectOf: CGSize(width: 10, height: 220), cornerRadius: 2)
        beam.fillColor = Palette.escape
        beam.strokeColor = .clear
        beam.glowWidth = 6
        node.addChild(beam)

        let cap = SKShapeNode(rectOf: CGSize(width: 64, height: 8), cornerRadius: 2)
        cap.fillColor = Palette.escape
        cap.strokeColor = .clear
        cap.position = CGPoint(x: 0, y: 108)
        node.addChild(cap)

        let label = SKLabelNode(text: "OUT")
        label.fontName = "AvenirNext-Bold"
        label.fontSize = 16
        label.fontColor = Palette.ivory
        label.verticalAlignmentMode = .center
        label.position = CGPoint(x: 28, y: 108)
        node.addChild(label)
        return node
    }
}

private enum Stage {
    static let groundY: CGFloat = 86
    static let playerX: CGFloat = 210
    static let runHeight: CGFloat = 36
    static let runWidth: CGFloat = 18
    static let rollHeight: CGFloat = 14
    static let gravity: CGFloat = -2100
    static let jumpVelocity: CGFloat = 640
    static let sceneSize = CGSize(width: 844, height: 390)
}

private enum Palette {
    static let ink = SKColor(red: 0.047, green: 0.063, blue: 0.086, alpha: 1)
    static let asphalt = SKColor(red: 0.102, green: 0.122, blue: 0.153, alpha: 1)
    static let curb = SKColor(red: 0.20, green: 0.22, blue: 0.26, alpha: 1)
    static let ivory = SKColor(red: 0.957, green: 0.937, blue: 0.902, alpha: 1)
    static let sodium = SKColor(red: 0.941, green: 0.639, blue: 0.369, alpha: 1)
    static let escape = SKColor(red: 0.490, green: 0.808, blue: 0.627, alpha: 1)
    static let wood = SKColor(red: 0.545, green: 0.365, blue: 0.243, alpha: 1)
    static let woodDark = SKColor(red: 0.365, green: 0.235, blue: 0.157, alpha: 1)
    static let metal = SKColor(red: 0.62, green: 0.66, blue: 0.71, alpha: 1)
    static let pit = SKColor(red: 0.02, green: 0.025, blue: 0.035, alpha: 1)
}

private enum Sky {
    static let texture: SKTexture = {
        let size = CGSize(width: 8, height: 390)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let colors = [
                UIColor(red: 0.16, green: 0.09, blue: 0.08, alpha: 1).cgColor,
                UIColor(red: 0.07, green: 0.07, blue: 0.10, alpha: 1).cgColor,
                UIColor(red: 0.025, green: 0.032, blue: 0.055, alpha: 1).cgColor,
            ] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            guard let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.42, 1]) else { return }
            ctx.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: 0, y: 0),
                end: CGPoint(x: 0, y: size.height),
                options: []
            )
        }
        return SKTexture(image: image)
    }()
}

private final class Ribbon {
    let nodes: [SKNode]
    let width: CGFloat
    let factor: CGFloat

    init(width: CGFloat, factor: CGFloat, make: () -> SKNode) {
        self.width = width
        self.factor = factor
        let first = make()
        let second = make()
        first.position = .zero
        second.position = CGPoint(x: width, y: 0)
        nodes = [first, second]
    }

    func step(_ dx: CGFloat) {
        let shift = dx * factor
        for node in nodes {
            node.position.x -= shift
            if node.position.x <= -width {
                node.position.x += width * 2
            }
        }
    }
}

private enum RoadArt {
    static func ground(width: CGFloat) -> SKNode {
        let tile = SKNode()
        tile.zPosition = 4
        let slab = SKShapeNode(rect: CGRect(x: 0, y: 0, width: width, height: Stage.groundY))
        slab.fillColor = Palette.asphalt
        slab.strokeColor = .clear
        tile.addChild(slab)
        let curb = SKShapeNode(rect: CGRect(x: 0, y: Stage.groundY - 6, width: width, height: 6))
        curb.fillColor = Palette.curb
        curb.strokeColor = .clear
        tile.addChild(curb)
        var x: CGFloat = 24
        while x < width {
            let dash = SKShapeNode(rect: CGRect(x: x, y: Stage.groundY + 14, width: 28, height: 3), cornerRadius: 1)
            dash.fillColor = Palette.ivory.withAlphaComponent(0.28)
            dash.strokeColor = .clear
            tile.addChild(dash)
            x += 78
        }
        return tile
    }

    static func city(width: CGFloat) -> SKNode {
        let tile = SKNode()
        tile.zPosition = 0
        var seed: UInt64 = 0xA11E
        func roll() -> UInt64 {
            seed = seed &* 1664525 &+ 1013904223
            return seed
        }
        var x: CGFloat = 0
        while x < width {
            let blockWidth = CGFloat(34 + roll() % 58)
            let blockHeight = CGFloat(70 + roll() % 130)
            let block = SKShapeNode(rect: CGRect(x: x, y: Stage.groundY, width: blockWidth, height: blockHeight))
            let shade = CGFloat(roll() % 18) / 255
            block.fillColor = SKColor(red: 0.07 + shade, green: 0.08 + shade, blue: 0.11 + shade, alpha: 1)
            block.strokeColor = .clear
            tile.addChild(block)
            var wy = Stage.groundY + 14
            while wy < Stage.groundY + blockHeight - 16 {
                var wx = x + 8
                while wx < x + blockWidth - 10 {
                    if roll() % 3 != 0 {
                        let window = SKShapeNode(rect: CGRect(x: wx, y: wy, width: 5, height: 7))
                        let lit = roll() % 4 == 0
                        window.fillColor = lit ? Palette.sodium.withAlphaComponent(0.85) : SKColor(white: 0.18, alpha: 0.5)
                        window.strokeColor = .clear
                        tile.addChild(window)
                    }
                    wx += 12
                }
                wy += 16
            }
            x += blockWidth + CGFloat(8 + roll() % 16)
        }
        return tile
    }

    static func lamps(width: CGFloat) -> SKNode {
        let tile = SKNode()
        tile.zPosition = 2
        var x: CGFloat = 70
        while x < width {
            let pole = SKShapeNode(rect: CGRect(x: x, y: Stage.groundY, width: 3, height: 118))
            pole.fillColor = SKColor(white: 0.16, alpha: 1)
            pole.strokeColor = .clear
            tile.addChild(pole)
            let lamp = SKShapeNode(circleOfRadius: 7)
            lamp.fillColor = Palette.sodium
            lamp.strokeColor = Palette.sodium.withAlphaComponent(0.4)
            lamp.glowWidth = 10
            lamp.position = CGPoint(x: x + 1.5, y: Stage.groundY + 124)
            tile.addChild(lamp)
            x += 220
        }
        return tile
    }
}

private final class Hazard {
    let kind: ObstacleKind
    let worldX: CGFloat
    let width: CGFloat
    let node: SKNode
    let pole: SKNode?
    var struck = false
    var gone = false

    init(spawn: ObstacleSpawn) {
        kind = spawn.kind
        worldX = spawn.distance
        width = spawn.width
        let built = HazardVisual.make(kind: spawn.kind, width: spawn.width)
        node = built.node
        pole = built.pole
        node.position = CGPoint(x: -400, y: 0)
    }

    func rect(distance: CGFloat, time: TimeInterval) -> CGRect {
        let left = Stage.playerX + (worldX - distance)
        switch kind {
        case .crate:
            return CGRect(x: left, y: Stage.groundY, width: width, height: 34)
        case .stack:
            return CGRect(x: left, y: Stage.groundY, width: width, height: 64)
        case .enemy:
            return CGRect(x: left, y: Stage.groundY, width: width, height: 32)
        case .rail:
            // Opening is below ground + 22. The slab continues above a jump,
            // so a jump always overlaps it and a roll always clears it.
            return CGRect(x: left, y: Stage.groundY + 22, width: width, height: 200)
        case .gap:
            return CGRect(x: left, y: Stage.groundY - 6, width: width, height: 22)
        case .sweeper:
            let bob = CGFloat(sin(time * 2.1 + Double(worldX) * 0.002))
            let mid = Stage.groundY + 41 + bob * 12
            return CGRect(x: left, y: mid - 11, width: width, height: 22)
        }
    }
}

private enum HazardVisual {
    static func make(kind: ObstacleKind, width: CGFloat) -> (node: SKNode, pole: SKNode?) {
        switch kind {
        case .crate:
            return (box(width: width, height: 34, stacked: false), nil)
        case .stack:
            return (box(width: width, height: 64, stacked: true), nil)
        case .enemy:
            return (enemy(width: width), nil)
        case .rail:
            return (shutter(width: width), nil)
        case .gap:
            let hole = SKShapeNode(rectOf: CGSize(width: width, height: 16), cornerRadius: 3)
            hole.fillColor = Palette.pit
            hole.strokeColor = Palette.curb
            hole.lineWidth = 2
            return (hole, nil)
        case .sweeper:
            let pole = SKShapeNode(rectOf: CGSize(width: 3, height: 120))
            pole.fillColor = SKColor(white: 0.22, alpha: 1)
            pole.strokeColor = .clear
            return (bar(width: width, height: 22, color: Palette.sodium, chevrons: false), pole)
        }
    }

    private static func shutter(width: CGFloat) -> SKNode {
        let node = SKNode()
        let slab = SKShapeNode(rectOf: CGSize(width: width, height: 200), cornerRadius: 3)
        slab.fillColor = SKColor(red: 0.16, green: 0.18, blue: 0.22, alpha: 1)
        slab.strokeColor = .clear
        node.addChild(slab)
        let lip = SKShapeNode(rectOf: CGSize(width: width, height: 6), cornerRadius: 2)
        lip.fillColor = Palette.sodium
        lip.strokeColor = .clear
        lip.position = CGPoint(x: 0, y: -97)
        node.addChild(lip)
        return node
    }

    private static func enemy(width: CGFloat) -> SKNode {
        let node = SKNode()
        let torso = SKShapeNode(rectOf: CGSize(width: max(14, width * 0.72), height: 20), cornerRadius: 4)
        torso.fillColor = SKColor(red: 0.62, green: 0.18, blue: 0.16, alpha: 1)
        torso.strokeColor = .clear
        torso.position = CGPoint(x: 0, y: -4)
        let head = SKShapeNode(circleOfRadius: 5.5)
        head.fillColor = SKColor(red: 0.82, green: 0.28, blue: 0.22, alpha: 1)
        head.strokeColor = .clear
        head.position = CGPoint(x: 2, y: 10)
        let visor = SKShapeNode(rectOf: CGSize(width: 7, height: 2), cornerRadius: 1)
        visor.fillColor = Palette.sodium
        visor.strokeColor = .clear
        visor.position = CGPoint(x: 1, y: 0)
        head.addChild(visor)
        node.addChild(torso)
        node.addChild(head)
        return node
    }

    private static func box(width: CGFloat, height: CGFloat, stacked: Bool) -> SKNode {
        let node = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 4)
        node.fillColor = Palette.wood
        node.strokeColor = Palette.woodDark
        node.lineWidth = 3
        if stacked {
            let seam = SKShapeNode(rectOf: CGSize(width: width - 4, height: 3))
            seam.fillColor = Palette.woodDark
            seam.strokeColor = .clear
            node.addChild(seam)
        }
        return node
    }

    private static func bar(width: CGFloat, height: CGFloat, color: SKColor, chevrons: Bool) -> SKNode {
        let node = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 3)
        node.fillColor = color
        node.strokeColor = .clear
        if chevrons {
            let marks = max(1, Int(width / 16))
            for i in 0..<marks {
                let mark = SKShapeNode(rectOf: CGSize(width: 4, height: height - 6))
                mark.fillColor = Palette.ink.withAlphaComponent(0.55)
                mark.strokeColor = .clear
                mark.zRotation = 0.6
                mark.position = CGPoint(x: -width / 2 + 12 + CGFloat(i) * 16, y: 0)
                node.addChild(mark)
            }
        }
        return node
    }
}
