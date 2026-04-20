import SwiftUI
import MetalKit

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
    
    let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()
    
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
                    .allowsHitTesting(controlsEnabled)
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                let dx = Float(value.translation.width)
                                let sensitivity: Float = 0.015
                                let clamped = max(-1.0, min(1.0, dx * sensitivity))
                                steeringValue = clamped
                                appState.engine.setSteering(steeringValue)
                            }
                            .onEnded { _ in
                                steeringValue = 0
                                appState.engine.setSteering(0)
                            }
                    )
                    .ignoresSafeArea()
                
                if !controlsEnabled {
                    entryOverlay
                }
                
                hudLayer(topInset: proxy.safeAreaInsets.top)
            }
        }
        .onAppear {
            beginRunPresentation()
        }
        .onReceive(timer) { _ in
            appState.engine.update(withDeltaTime: 1.0 / 60.0)
            score = Int(appState.engine.getScore())
            runCoins = Int(appState.engine.getCoins())
            health = Int(appState.engine.getVehicleHealth())
            let nowGrazing = appState.engine.getIsGrazing()
            timeElapsed += 1.0 / 60.0
            
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
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        HUDStat(icon: "star.fill", label: "SCORE", value: "\(score)")
                        HUDStat(icon: "bitcoinsign.circle.fill", label: "RUN", value: "\(runCoins)")
                        HUDStat(icon: "heart.fill", label: "HULL", value: "\(health)%")
                        if isGrazing {
                            Text("⚡ GRAZE")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .foregroundColor(.cyan)
                                .shadow(color: .cyan, radius: 4)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        finishRun(died: false)
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white.opacity(0.8))
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .environment(\.colorScheme, .dark)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color(red: 0.9, green: 0.1, blue: 0.6).opacity(0.6), lineWidth: 1.5)
                                    .shadow(color: Color(red: 0.9, green: 0.1, blue: 0.6).opacity(0.8), radius: 8)
                            )
                    }
                    .disabled(!hudVisible)
                }
                
                missionPanel
            }
            .padding(.top, topInset + 34)
            .padding(.horizontal, 16)
            .opacity(hudVisible ? 1 : 0)
            
            Spacer()
            
            if nearMissVisible {
                Text("NEAR MISS!")
                    .font(.system(size: 28, weight: .black, design: .monospaced))
                    .foregroundColor(.yellow)
                    .tracking(8)
                    .shadow(color: .yellow, radius: 12)
                    .shadow(color: .orange, radius: 24)
                    .opacity(nearMissOpacity)
                    .transition(.opacity)
            }
            
            Spacer()
            
            Text(controlsEnabled ? "DRAG LEFT / RIGHT TO STEER" : "STABILIZING APPROACH")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(Color(red: 0.1, green: 0.9, blue: 0.8))
                .shadow(color: Color.cyan.opacity(0.8), radius: 5)
                .tracking(2)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.bottom, 28)
                .opacity(hudVisible || !controlsEnabled ? 1 : 0)
        }
    }
    
    private var missionPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("RUN CONTRACTS")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.64))
                    .tracking(2.0)
                Spacer()
                Text("RANK \(appState.pilotRank)")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }
            
            ForEach(appState.activeMissions) { mission in
                MissionProgressRow(
                    mission: mission,
                    progress: appState.progressValue(for: mission, in: currentRunSnapshot)
                )
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.24))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
        .frame(maxWidth: 320, alignment: .leading)
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
        appState.engine.setSteering(0)
        
        let shouldAnimateEntry = appState.consumePendingGameEntryAnimation()
        if shouldAnimateEntry {
            entryProgress = 0
            withAnimation(.easeOut(duration: 0.9)) {
                entryProgress = 1
            }
            withAnimation(.easeIn(duration: 0.35).delay(0.20)) {
                hudVisible = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                controlsEnabled = true
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
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundColor(Color(red: 0.9, green: 0.4, blue: 0.6))
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

struct MissionProgressRow: View {
    let mission: ProgressionMission
    let progress: Int
    
    private var progressFraction: Double {
        Double(min(progress, mission.goal)) / Double(max(1, mission.goal))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(mission.shortTitle)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(0.8)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                Text("\(min(progress, mission.goal))/\(mission.goal)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.72))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.10))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.18, green: 0.95, blue: 1.0),
                                    Color(red: 1.0, green: 0.46, blue: 0.62)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progressFraction)
                }
            }
            .frame(height: 6)
        }
    }
}
