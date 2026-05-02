import SwiftUI
import MetalKit

struct GlassPanelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.35))
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
            )
    }
}

extension View {
    func glassPanel() -> some View {
        self.modifier(GlassPanelModifier())
    }
}

struct GameMetalView: UIViewRepresentable {
    var engineWrapper: GameEngineWrapper
    var previewLevel: GameLevel? = nil
    var previewScrollSpeed: Float = 0
    var showVehicle: Bool = true
    var showObstacles: Bool = true
    var showChaser: Bool = true
    var shipVerticalOffset: Float = 0
    var preferredFramesPerSecond: Int = 60
    
    final class Coordinator {
        var renderer: GameRenderer?
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    func makeUIView(context: Context) -> MTKView {
        let mtkView = MTKView()
        mtkView.device = MTLCreateSystemDefaultDevice()
        mtkView.preferredFramesPerSecond = preferredFramesPerSecond
        mtkView.isPaused = false
        mtkView.enableSetNeedsDisplay = false
        
        let renderer = GameRenderer(metalKitView: mtkView, engineWrapper: engineWrapper)
        context.coordinator.renderer = renderer
        mtkView.delegate = renderer
        applyConfiguration(to: mtkView, renderer: renderer)
        return mtkView
    }
    
    func updateUIView(_ uiView: MTKView, context: Context) {
        guard let renderer = context.coordinator.renderer else { return }
        applyConfiguration(to: uiView, renderer: renderer)
    }
    
    private func applyConfiguration(to view: MTKView, renderer: GameRenderer) {
        view.preferredFramesPerSecond = preferredFramesPerSecond
        renderer.previewMode = previewLevel != nil
        renderer.forcedLevelType = previewLevel?.rawValue ?? -1
        renderer.previewScrollSpeed = previewScrollSpeed
        renderer.showsVehicle = showVehicle
        renderer.showsObstacles = showObstacles
        renderer.showsChaser = showChaser
        renderer.vehicleVerticalOffset = shipVerticalOffset
        
        if previewLevel == nil {
            applyVisibleLateralLimit(for: view)
        }
    }
    
    private func applyVisibleLateralLimit(for view: MTKView) {
        let playableHalfWidth: Float = 95.0
        engineWrapper.setVisibleLateralLimit(playableHalfWidth)
    }
}

struct TerrainPreviewView: View {
    let level: GameLevel
    var scrollSpeed: Float = 34
    var preferredFramesPerSecond: Int = 30
    
    @State private var previewEngineWrapper = GameEngineWrapper()
    
    var body: some View {
        GameMetalView(
            engineWrapper: previewEngineWrapper,
            previewLevel: level,
            previewScrollSpeed: scrollSpeed,
            showVehicle: false,
            showObstacles: false,
            showChaser: false,
            preferredFramesPerSecond: preferredFramesPerSecond
        )
        .ignoresSafeArea()
        .onAppear {
            syncLevel()
        }
        .onChange(of: level.rawValue) { _ in
            syncLevel()
        }
    }
    
    private func syncLevel() {
        previewEngineWrapper.setLevel(Int32(level.rawValue))
    }
}

struct GameView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var timeElapsed: TimeInterval = 0
    @State private var score: Int = 0
    @State private var runCoins: Int = 0
    @State private var health: Int = 100
    @State private var hudVisible = false
    @State private var steeringValue: Float = 0
    @State private var isGrazing: Bool = false
    @State private var nearMissCount = 0
    @State private var nearMissVisible = false
    @State private var nearMissOpacity: Double = 0
    @State private var wasGrazing = false
    @State private var didBankRunCoins = false
    @State private var deathSequenceStarted = false
    @State private var controlsEnabled = false
    @State private var entryProgress: Double = 1.0
    @State private var isDragging = false
    @State private var activeDragTranslationWidth: CGFloat = 0
    
    let hudTimer = Timer.publish(every: 1.0 / 15.0, on: .main, in: .common).autoconnect()
    
    private var shipDropOffset: Float {
        let remaining = max(0.0, 1.0 - entryProgress)
        return Float(remaining * remaining * 58.0)
    }
    
    private var currentRunSnapshot: RunProgressSnapshot {
        RunProgressSnapshot(
            survivedSeconds: max(0, Int(timeElapsed.rounded(.down))),
            bankedCoins: runCoins,
            nearMisses: nearMissCount,
            score: score
        )
    }

    private var lifeFraction: CGFloat {
        CGFloat(max(0, min(100, health))) / 100.0
    }

    private var armorFraction: CGFloat {
        CGFloat(max(0, min(5, appState.equippedShip.stats.armor))) / 5.0
    }

    private func combatStatusTopPadding(for topInset: CGFloat) -> CGFloat {
        max(topInset + 78, 126)
    }
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                GameMetalView(
                    engineWrapper: appState.engine,
                    showVehicle: true,
                    showObstacles: true,
                    showChaser: true,
                    shipVerticalOffset: shipDropOffset,
                    preferredFramesPerSecond: 60
                )
                .ignoresSafeArea()
                
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                activeDragTranslationWidth = value.translation.width
                                isDragging = true
                                guard controlsEnabled else { return }
                                updateSteering(forDragWidth: value.translation.width)
                            }
                            .onEnded { _ in
                                isDragging = false
                                activeDragTranslationWidth = 0
                                steeringValue = 0
                                appState.engine.setSteering(0)
                            }
                    )
                    .ignoresSafeArea()
                
                if !controlsEnabled {
                    entryOverlay
                        .allowsHitTesting(false)
                }
                
                hudLayer(topInset: proxy.safeAreaInsets.top)
            }
        }
        .onAppear {
            beginRunPresentation()
        }
        .onChange(of: controlsEnabled) { enabled in
            if enabled && isDragging {
                updateSteering(forDragWidth: activeDragTranslationWidth)
            }
        }
        .onReceive(hudTimer) { _ in
            score = Int(appState.engine.getScore())
            runCoins = Int(appState.engine.getCoins())
            health = Int(appState.engine.getVehicleHealth())
            let nowGrazing = appState.engine.getIsGrazing()
            timeElapsed = TimeInterval(appState.engine.getTotalTime())
            
            if wasGrazing && !nowGrazing {
                nearMissCount += 1
                nearMissVisible = true
                withAnimation(.easeIn(duration: 0.05)) {
                    nearMissOpacity = 1.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    withAnimation(.easeOut(duration: 0.7)) {
                        nearMissOpacity = 0
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    nearMissVisible = false
                }
            }
            wasGrazing = nowGrazing
            isGrazing = nowGrazing
            
            if health <= 0 {
                beginDeathSequenceIfNeeded()
            }
        }
    }
    
    private var entryOverlay: some View {
        VStack(spacing: 10) {
            Text(appState.selectedLevel.name)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.72))
                .tracking(3)
            
            Text("DROP IN")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .tracking(2)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(Color.black.opacity(0.24))
                .overlay(
                    RoundedRectangle(cornerRadius: 26)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.35), radius: 24, y: 12)
        .opacity(max(0.0, 1.0 - entryProgress * 1.35))
    }
    
    private func hudLayer(topInset: CGFloat) -> some View {
        VStack {
            combatStatusPanel
                .padding(.top, combatStatusTopPadding(for: topInset))
                .opacity(hudVisible ? 1 : 0)
            
            Spacer()
            
            // Near Miss indicator
            if nearMissVisible {
                Text("NEAR MISS!")
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundColor(Color(red: 0.1, green: 0.9, blue: 0.8)) // teal instead of yellow
                    .tracking(8)
                    .shadow(color: .cyan, radius: 12)
                    .shadow(color: .white, radius: 4)
                    .opacity(nearMissOpacity)
                    .transition(.opacity)
            }
            
            Spacer()
            
            HStack(alignment: .bottom) {
                Spacer()

                Button(action: { finishRun(died: false) }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white.opacity(0.82))
                        .frame(width: 42, height: 42)
                        .background(
                            Circle()
                                .fill(Color.black.opacity(0.26))
                                .background(Circle().fill(.ultraThinMaterial).environment(\.colorScheme, .dark))
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 18)
            .opacity(hudVisible ? 1 : 0)

            Text(controlsEnabled ? "DRAG LEFT / RIGHT TO STEER" : "STABILIZING APPROACH")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(Color.white.opacity(0.35))
                .tracking(2)
                .lineLimit(1)
                .padding(.bottom, 32)
                .opacity(hudVisible || !controlsEnabled ? 1 : 0)
        }
    }

    private var combatStatusPanel: some View {
        VStack(spacing: 5) {
            statusBar(
                fraction: lifeFraction,
                height: 10,
                fill: Color(red: 1.0, green: 0.04, blue: 0.10),
                glow: Color.red
            )

            statusBar(
                fraction: armorFraction,
                height: 4,
                fill: Color(red: 0.12, green: 0.58, blue: 1.0),
                glow: Color(red: 0.18, green: 0.70, blue: 1.0)
            )

            Text("\(score)")
                .font(.system(size: 18, weight: .black, design: .monospaced))
                .foregroundColor(.white.opacity(0.94))
                .shadow(color: .black.opacity(0.75), radius: 4)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: 220)
    }

    private func statusBar(fraction: CGFloat, height: CGFloat, fill: Color, glow: Color) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.34))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )

                Capsule()
                    .fill(fill)
                    .frame(width: proxy.size.width * max(0, min(1, fraction)))
                    .shadow(color: glow.opacity(0.72), radius: 8)
            }
        }
        .frame(height: height)
    }
    
    private var missionPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("CONTRACTS")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.64))
                .tracking(2.0)
            
            HStack(spacing: 8) {
                ForEach(appState.activeMissions) { mission in
                    MissionCardView(
                        mission: mission,
                        progress: appState.progressValue(for: mission, in: currentRunSnapshot)
                    )
                }
            }
        }
        .glassPanel()
    }
    
    private func beginRunPresentation() {
        score = 0
        runCoins = 0
        health = Int(appState.engine.getVehicleHealth())
        timeElapsed = 0
        steeringValue = 0
        isGrazing = false
        nearMissVisible = false
        nearMissOpacity = 0
        wasGrazing = false
        nearMissCount = 0
        didBankRunCoins = false
        deathSequenceStarted = false
        hudVisible = false
        controlsEnabled = false
        isDragging = false
        activeDragTranslationWidth = 0
        appState.engine.setSteering(0)
        
        let shouldAnimateEntry = appState.consumePendingGameEntryAnimation()
        if shouldAnimateEntry {
            entryProgress = 0
            controlsEnabled = true
            withAnimation(.easeOut(duration: 0.9)) {
                entryProgress = 1
            }
            withAnimation(.easeIn(duration: 0.35).delay(0.20)) {
                hudVisible = true
            }
        } else {
            entryProgress = 1
            controlsEnabled = true
            withAnimation(.easeIn(duration: 0.3)) {
                hudVisible = true
            }
        }
    }
    
    private func beginDeathSequenceIfNeeded() {
        guard !deathSequenceStarted else { return }
        deathSequenceStarted = true
        steeringValue = 0
        appState.engine.setSteering(0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) {
            finishRun(died: true)
        }
    }
    
    private func finishRun(died: Bool) {
        guard !didBankRunCoins else { return }
        didBankRunCoins = true
        appState.finishGame(
            bankCoins: runCoins,
            score: score,
            survivedSeconds: max(0, Int(timeElapsed.rounded(.down))),
            nearMisses: nearMissCount,
            died: died
        )
    }

    private func updateSteering(forDragWidth width: CGFloat) {
        let dx = Float(width)
        let sensitivity: Float = 0.015
        let clamped = max(-1.0, min(1.0, dx * sensitivity))
        steeringValue = clamped
        appState.engine.setSteering(clamped)
    }
}

struct HUDStat: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(Color(red: 0.6, green: 0.9, blue: 0.8))
                .frame(width: 14)
            
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(Color.white.opacity(0.6))
                    .tracking(1.0)
                    .lineLimit(1)
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.8), radius: 2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }
}

struct MissionCardView: View {
    let mission: ProgressionMission
    let progress: Int
    
    private var progressFraction: Double {
        Double(min(progress, mission.goal)) / Double(max(1, mission.goal))
    }
    
    private var iconName: String {
        switch mission.kind {
        case .surviveSeconds: return "stopwatch"
        case .bankCoins: return "bitcoinsign.circle"
        case .nearMisses: return "exclamationmark.bolt"
        }
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: progressFraction)
                    .stroke(
                        LinearGradient(colors: [.cyan, Color(red: 0.4, green: 0.8, blue: 1.0)], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                Image(systemName: iconName)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }
            .frame(width: 44, height: 44)
            
            VStack(spacing: 4) {
                Text(mission.shortTitle)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(0.5)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("\(min(progress, mission.goal)) / \(mission.goal)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }
        }
        .frame(width: 80)
        .padding(.vertical, 14)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        )
    }
}
