import SwiftUI

private func topSafeInset(for proxy: GeometryProxy) -> CGFloat {
    proxy.safeAreaInsets.top + 30
}

struct MainMenuView: View {
    @EnvironmentObject var appState: AppState
    @State private var buttonOffset: CGFloat = 36
    @State private var buttonOpacity = 0.0
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                // Black safety backdrop prevents any white bleed on edges
                Color.black.ignoresSafeArea()
                
                TerrainPreviewView(level: appState.selectedLevel, scrollSpeed: 34, preferredFramesPerSecond: 30)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                backgroundOverlay
                
                VStack(spacing: 0) {
                    topBar
                        .padding(.horizontal, 20)
                        .padding(.top, topSafeInset(for: proxy))
                    
                    Spacer()
                    
                    VStack(spacing: 18) {
                        titleBlock
                        actionStack
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 54)
                    .offset(y: buttonOffset)
                    .opacity(buttonOpacity)
                }
            }
            .ignoresSafeArea()
        }
        .background(Color.black)
        .onAppear {
            withAnimation(.easeOut(duration: 0.65)) {
                buttonOffset = 0
                buttonOpacity = 1
            }
        }
    }

    private var backgroundOverlay: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.42),
                    Color.black.opacity(0.62)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            RadialGradient(
                colors: [
                    appState.selectedLevel.gradient.first?.opacity(0.42) ?? .clear,
                    .clear
                ],
                center: .bottomTrailing,
                startRadius: 20,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }
    
    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("LAST SELECTED LEVEL")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.62))
                    .tracking(2.4)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                
                Text(appState.selectedLevel.name)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            
            Spacer()
            
            HStack(spacing: 10) {
                PilotRankCapsule(rank: appState.pilotRank, progress: appState.pilotRankProgress)
                CurrencyCapsule(amount: appState.coins)
            }
        }
    }
    
    private var titleBlock: some View {
        VStack(spacing: 12) {
            Text("VOID RACER")
                .font(.system(size: 50, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .tracking(2.5)
            
            Text("Minimal menu. Fast decisions. Drop straight into the next line.")
                .font(.system(size: 15, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.76))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)
        }
    }
    
    private var actionStack: some View {
        VStack(spacing: 14) {
            MenuActionButton(
                title: "PLAY",
                subtitle: "Choose a level and launch from above",
                accent: appState.selectedLevel.gradient.last ?? Color(red: 0.16, green: 0.96, blue: 1.0),
                symbolName: "play.fill",
                action: appState.openLevelSelect
            )
            
            MenuActionButton(
                title: "STORE",
                subtitle: "Ships, skins, and garage progression",
                accent: Color(red: 0.98, green: 0.72, blue: 0.24),
                symbolName: "bag.fill",
                action: appState.openStore
            )
        }
        .frame(maxWidth: 420)
    }
}

struct LevelSelectView: View {
    @EnvironmentObject var appState: AppState
    @State private var selection = 0
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                TabView(selection: $selection) {
                    ForEach(GameLevel.allCases, id: \.rawValue) { level in
                        LevelSelectionPage(level: level)
                            .tag(level.rawValue)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                VStack(spacing: 0) {
                    levelTopBar
                        .padding(.horizontal, 20)
                        .padding(.top, topSafeInset(for: proxy))
                    
                    Spacer()
                    
                    LevelPageIndicator(selection: selection)
                        .padding(.bottom, 24)
                }
            }
            .ignoresSafeArea()
        }
        .onAppear {
            selection = appState.selectedLevel.rawValue
        }
    }
    
    private var levelTopBar: some View {
        HStack {
            Button(action: appState.returnToMenu) {
                Label("MENU", systemImage: "chevron.left")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(GlassCapsuleBackground(tint: Color.white.opacity(0.06)))
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            HStack(spacing: 10) {
                PilotRankCapsule(rank: appState.pilotRank, progress: appState.pilotRankProgress)
                CurrencyCapsule(amount: appState.coins)
            }
        }
    }
}

private struct LevelSelectionPage: View {
    @EnvironmentObject var appState: AppState
    let level: GameLevel
    
    var body: some View {
        ZStack {
            TerrainPreviewView(level: level, scrollSpeed: 40, preferredFramesPerSecond: 30)
            pageOverlay
            
            VStack(alignment: .leading, spacing: 0) {
                Spacer()
                
                VStack(alignment: .leading, spacing: 18) {
                    Text("LEVEL SELECT")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.68))
                        .tracking(2.6)
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text(level.name)
                            .font(.system(size: 38, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .tracking(1.4)
                        
                        Text(level.subtitle)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.76))
                    }
                    
                    HStack(spacing: 10) {
                        levelTag(title: "ATMOSPHERE", value: atmosphereLabel)
                        levelTag(title: "DROP", value: "SHIP ENTRY")
                    }
                    
                    Button(action: {
                        appState.startGame(level: level)
                    }) {
                        HStack {
                            Text("DROP IN")
                                .font(.system(size: 16, weight: .black, design: .rounded))
                                .tracking(1.4)
                            Spacer()
                            Image(systemName: "arrow.down.to.line.compact")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 18)
                        .background(
                            GlassRoundedBackground(
                                cornerRadius: 22,
                                tint: (level.gradient.last ?? .white).opacity(0.18)
                            )
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
                .background(
                    GlassRoundedBackground(
                        cornerRadius: 30,
                        tint: (level.gradient.first ?? .white).opacity(0.10)
                    )
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 68)
            }
        }
        .ignoresSafeArea()
    }
    
    private var pageOverlay: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.18),
                    Color.black.opacity(0.68)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            
            RadialGradient(
                colors: [
                    level.gradient.last?.opacity(0.34) ?? .clear,
                    .clear
                ],
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 360
            )
        }
        .ignoresSafeArea()
    }
    
    private var atmosphereLabel: String {
        switch level {
        case .neonSynthwave:
            return "SOFT NEON"
        case .fieryRetrowave:
            return "HEAT GLOW"
        case .cyberpunkVoid:
            return "DIGITAL MIST"
        case .debugMode:
            return "TEST GRID"
        }
    }
    
    private func levelTag(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.54))
                .tracking(1.8)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(value)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .tracking(0.8)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(GlassRoundedBackground(cornerRadius: 18, tint: Color.white.opacity(0.05)))
    }
}

private struct MenuActionButton: View {
    let title: String
    let subtitle: String
    let accent: Color
    let symbolName: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(title)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(1.6)
                    
                    Text(subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.82))
                }
                
                Spacer()
                
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.18))
                        .frame(width: 54, height: 54)
                    Circle()
                        .stroke(accent.opacity(0.36), lineWidth: 1)
                        .frame(width: 54, height: 54)
                    Image(systemName: symbolName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
            .background(
                GlassRoundedBackground(
                    cornerRadius: 26,
                    tint: accent.opacity(0.12)
                )
            )
            .shadow(color: accent.opacity(0.10), radius: 20, y: 10)
        }
        .buttonStyle(.plain)
    }
}

private struct LevelPageIndicator: View {
    let selection: Int
    
    var body: some View {
        HStack(spacing: 9) {
            ForEach(GameLevel.allCases, id: \.rawValue) { level in
                Capsule()
                    .fill(level.rawValue == selection ? Color.white : Color.white.opacity(0.28))
                    .frame(width: level.rawValue == selection ? 26 : 8, height: 8)
                    .animation(.spring(response: 0.28, dampingFraction: 0.82), value: selection)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(GlassCapsuleBackground(tint: Color.white.opacity(0.05)))
    }
}

struct CurrencyCapsule: View {
    let amount: Int
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bitcoinsign.circle.fill")
                .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.24))
            Text("\(amount)")
                .font(.system(size: 13, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(GlassCapsuleBackground(tint: Color.white.opacity(0.05)))
    }
}

struct PilotRankCapsule: View {
    let rank: Int
    let progress: Double
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: "star.circle.fill")
                    .foregroundColor(Color(red: 0.16, green: 0.96, blue: 1.0))
                Text("RANK \(rank)")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(Color(red: 0.16, green: 0.96, blue: 1.0).opacity(0.92))
                        .frame(width: geo.size.width * min(max(progress, 0), 1))
                }
            }
            .frame(height: 5)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(minWidth: 100, idealWidth: 110)
        .background(GlassRoundedBackground(cornerRadius: 18, tint: Color.white.opacity(0.05)))
    }
}

private struct GlassCapsuleBackground: View {
    var tint: Color
    
    var body: some View {
        Capsule()
            .fill(.ultraThinMaterial)
            .overlay(Capsule().fill(tint))
            .overlay(
                Capsule()
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            )
            .overlay(alignment: .top) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.18),
                                Color.white.opacity(0.04),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: 18)
            }
            .shadow(color: Color.black.opacity(0.16), radius: 16, y: 8)
    }
}

private struct GlassRoundedBackground: View {
    let cornerRadius: CGFloat
    var tint: Color
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(tint)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 1)
            )
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.16),
                                Color.white.opacity(0.05),
                                .clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(height: min(40, cornerRadius * 1.25))
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            }
            .shadow(color: Color.black.opacity(0.16), radius: 18, y: 10)
    }
}
