import SpriteKit
import SwiftUI
import UIKit

@MainActor
final class GameModel: ObservableObject {
    enum Phase: Equatable {
        case menu, playing, cleared, caught, escaped
    }

    @Published var phase: Phase = .menu
    @Published var stretchIndex = 1
    @Published var lives = 3
    @Published var progress: CGFloat = 0
    @Published var unlocked: Int
    @Published var score = 0
    @Published var best: Int
    @Published var runID = UUID()

    private let unlockKey = "hightail.unlocked"
    private let bestKey = "hightail.best"

    init() {
        let stored = UserDefaults.standard.integer(forKey: "hightail.unlocked")
        unlocked = stored == 0 ? 1 : min(LevelCatalog.count, max(1, stored))
        best = UserDefaults.standard.integer(forKey: "hightail.best")
    }

    var stretch: Stretch { LevelCatalog.stretch(stretchIndex) }

    func start(_ index: Int, keepScore: Bool = false) {
        guard index >= 1, index <= unlocked else { return }
        stretchIndex = index
        lives = 3
        progress = 0
        if !keepScore { score = 0 }
        runID = UUID()
        phase = .playing
    }

    func note(progress: CGFloat, lives: Int, score: Int) {
        self.progress = progress
        self.lives = lives
        self.score = score
        if score > best {
            best = score
            UserDefaults.standard.set(best, forKey: bestKey)
        }
    }

    func didClear() {
        if stretchIndex >= LevelCatalog.count {
            unlocked = LevelCatalog.count
            persist()
            phase = .escaped
        } else {
            unlocked = max(unlocked, stretchIndex + 1)
            persist()
            phase = .cleared
        }
    }

    func didCatch() {
        phase = .caught
    }

    func retry() {
        start(stretchIndex, keepScore: true)
    }

    func next() {
        start(stretchIndex + 1, keepScore: true)
    }

    func toMap() {
        phase = .menu
    }

    private func persist() {
        UserDefaults.standard.set(unlocked, forKey: unlockKey)
    }
}

struct RootView: View {
    @StateObject private var model = GameModel()

    var body: some View {
        ZStack {
            Color.ink.ignoresSafeArea()
            switch model.phase {
            case .menu:
                MapScreen(model: model)
            case .playing:
                PlaySession(model: model)
                    .id(model.runID)
            case .cleared:
                ResultCard(
                    kicker: "Stretch \(model.stretch.index) clear",
                    title: "\(model.stretch.name) is behind you.",
                    message: "Keep going. The gate at the end of the bridge is the only ending.",
                    primary: "Next stretch",
                    primaryAction: model.next,
                    secondary: "Map",
                    secondaryAction: model.toMap
                )
            case .caught:
                ResultCard(
                    kicker: "Not this stretch",
                    title: "They closed the gap.",
                    message: "The stretch resets. The exit doesn't.",
                    primary: "Retry",
                    primaryAction: model.retry,
                    secondary: "Map",
                    secondaryAction: model.toMap
                )
            case .escaped:
                EscapedScreen(again: model.toMap)
            }
        }
    }
}

private struct MapScreen: View {
    @ObservedObject var model: GameModel

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        HStack(alignment: .center, spacing: 28) {
            VStack(alignment: .leading, spacing: 14) {
                Text("HIGHTAIL")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ivory)
                Text("Eight runs. Each one gets meaner. You win when you get out.")
                    .font(.system(size: 16, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.ivory.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: { model.start(model.unlocked) }) {
                    Text(model.unlocked == 1 ? "Hit the alley" : "Continue")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ink)
                        .frame(minWidth: 180, minHeight: 52)
                        .background(Color.escape, in: Capsule())
                }
                .buttonStyle(.plain)
                Text("Tap the top half to jump. Hold it for a higher one, or tap again in the air. Hold the bottom half to roll. Jump on an animal for points. A fast roll pays more.")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.ivory.opacity(0.5))
                if model.best > 0 {
                    Text("Best \(model.best)")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.sodium.opacity(0.85))
                }
            }
            .frame(maxWidth: 340, alignment: .leading)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(LevelCatalog.stretches, id: \.index) { stretch in
                    StretchCell(stretch: stretch, unlocked: model.unlocked) {
                        model.start(stretch.index)
                    }
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 18)
    }
}

private struct StretchCell: View {
    let stretch: Stretch
    let unlocked: Int
    let start: () -> Void

    private var open: Bool { stretch.index <= unlocked }
    private var frontier: Bool { stretch.index == unlocked }

    var body: some View {
        Button(action: { if open { start() } }) {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(format: "%02d", stretch.index))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(frontier ? Color.sodium : Color.ivory.opacity(open ? 0.7 : 0.35))
                Text(stretch.name)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ivory.opacity(open ? 1 : 0.4))
                Text(stretch.blurb)
                    .font(.system(size: 11, weight: .regular, design: .rounded))
                    .foregroundStyle(Color.ivory.opacity(open ? 0.55 : 0.28))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.white.opacity(open ? 0.06 : 0.03), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(frontier ? Color.sodium.opacity(0.8) : Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!open)
        .accessibilityLabel("\(stretch.name). \(open ? stretch.blurb : "Locked")")
    }
}

private struct PlaySession: View {
    @ObservedObject var model: GameModel
    @State private var scene: GameScene?
    private let jumpHaptic = UIImpactFeedbackGenerator(style: .light)
    private let rollHaptic = UIImpactFeedbackGenerator(style: .soft)
    private let knockHaptic = UIImpactFeedbackGenerator(style: .rigid)
    private let hitHaptic = UINotificationFeedbackGenerator()
    private let clearHaptic = UINotificationFeedbackGenerator()

    var body: some View {
        GeometryReader { geo in
            ZStack {
                if let scene {
                    SpriteHost(scene: scene)
                        .ignoresSafeArea()
                    Color.clear
                        .contentShape(Rectangle())
                        .gesture(gesture(scene, height: geo.size.height))
                    zoneLabels
                    hud
                }
            }
        }
        .onAppear(perform: boot)
    }

    private func boot() {
        guard scene == nil else { return }
        jumpHaptic.prepare()
        rollHaptic.prepare()
        knockHaptic.prepare()
        let next = GameScene(stretch: model.stretch)
        next.restoreScore(model.score)
        next.onProgress = { progress, lives, score in
            DispatchQueue.main.async {
                model.note(progress: progress, lives: lives, score: score)
            }
        }
        next.onScore = { score in
            DispatchQueue.main.async {
                model.note(progress: model.progress, lives: model.lives, score: score)
            }
        }
        next.onJump = { jumpHaptic.impactOccurred() }
        next.onRoll = { rollHaptic.impactOccurred() }
        next.onKnock = { knockHaptic.impactOccurred() }
        next.onHit = { hitHaptic.notificationOccurred(.error) }
        next.onClear = {
            clearHaptic.notificationOccurred(.success)
            DispatchQueue.main.async { model.didClear() }
        }
        next.onCaught = {
            DispatchQueue.main.async { model.didCatch() }
        }
        scene = next
    }

    private func gesture(_ scene: GameScene, height: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                scene.beginTouch(jumpZone: value.startLocation.y < height * 0.5)
            }
            .onEnded { _ in
                scene.endTouch()
            }
    }

    private var zoneLabels: some View {
        VStack {
            Text("HOLD TO JUMP")
                .padding(.top, 34)
            Spacer()
            Text("HOLD TO ROLL")
                .padding(.bottom, 16)
        }
        .font(.system(size: 11, weight: .bold, design: .rounded))
        .tracking(1.6)
        .foregroundStyle(Color.ivory.opacity(model.progress < 0.22 ? 0.55 : 0.18))
        .allowsHitTesting(false)
    }

    private var hud: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("STRETCH \(model.stretch.index)  ·  \(model.stretch.name.uppercased())")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(Color.ivory.opacity(0.7))
                    Text(model.progress < 0.2 ? model.stretch.hint : "The gate is ahead.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.ivory.opacity(0.9))
                }
                .allowsHitTesting(false)
                Spacer()
                Text("\(model.score)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ivory)
                    .allowsHitTesting(false)
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(index < model.lives ? Color.sodium : Color.white.opacity(0.15))
                            .frame(width: 8, height: 8)
                    }
                }
                .allowsHitTesting(false)
                Button(action: model.toMap) {
                    Text("Leave")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ivory.opacity(0.75))
                        .frame(minWidth: 44, minHeight: 36)
                }
                .buttonStyle(.plain)
            }
            progressBar
                .allowsHitTesting(false)
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 8)
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.1))
                Capsule()
                    .fill(Color.escape)
                    .frame(width: max(8, geo.size.width * model.progress))
            }
        }
        .frame(height: 5)
        .accessibilityLabel("Progress to the gate")
        .accessibilityValue("\(Int(model.progress * 100)) percent")
    }
}

private struct SpriteHost: UIViewRepresentable {
    let scene: SKScene

    func makeUIView(context: Context) -> SKView {
        let view = SKView()
        view.ignoresSiblingOrder = true
        view.preferredFramesPerSecond = 60
        view.presentScene(scene)
        return view
    }

    func updateUIView(_ view: SKView, context: Context) {
        if view.scene !== scene {
            view.presentScene(scene)
        }
    }
}

private struct ResultCard: View {
    let kicker: String
    let title: String
    let message: String
    let primary: String
    let primaryAction: () -> Void
    let secondary: String
    let secondaryAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(kicker.uppercased())
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(1.4)
                .foregroundStyle(Color.sodium)
            Text(title)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ivory)
            Text(message)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 12) {
                Button(action: primaryAction) {
                    Text(primary)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ink)
                        .frame(minWidth: 140, minHeight: 48)
                        .background(Color.escape, in: Capsule())
                }
                .buttonStyle(.plain)
                Button(action: secondaryAction) {
                    Text(secondary)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.ivory)
                        .frame(minWidth: 88, minHeight: 48)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 6)
        }
        .padding(24)
        .frame(maxWidth: 460, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct EscapedScreen: View {
    let again: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("YOU MADE IT")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .tracking(2)
                .foregroundStyle(Color.escape)
            Text("The bridge is behind you.")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ivory)
            Text("No more crates, no more rails, no one left in the lane. That is the end of the run.")
                .font(.system(size: 17, weight: .regular, design: .rounded))
                .foregroundStyle(Color.ivory.opacity(0.72))
                .frame(maxWidth: 520, alignment: .leading)
            Button(action: again) {
                Text("Run it back")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ink)
                    .frame(minWidth: 200, minHeight: 52)
                    .background(Color.ivory, in: Capsule())
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(36)
    }
}

extension Color {
    static let ink = Color(red: 0.047, green: 0.063, blue: 0.086)
    static let ivory = Color(red: 0.957, green: 0.937, blue: 0.902)
    static let sodium = Color(red: 0.941, green: 0.639, blue: 0.369)
    static let escape = Color(red: 0.490, green: 0.808, blue: 0.627)
}
