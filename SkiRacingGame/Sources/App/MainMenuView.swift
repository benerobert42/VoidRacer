import SwiftUI

struct MainMenuView: View {
    @EnvironmentObject var appState: AppState
    @State private var buttonOffset: CGFloat = 36
    @State private var buttonOpacity = 0.0
    
    var body: some View {
        GeometryReader { _ in
            ZStack {
                // Black safety backdrop prevents any white bleed on edges
                Color.black.ignoresSafeArea()
                
                TerrainPreviewView(level: appState.selectedLevel, scrollSpeed: 34, preferredFramesPerSecond: 30)
                    .ignoresSafeArea()
                    .clipped()
                backgroundOverlay
                
                VStack(spacing: 0) {
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
    
    private var titleBlock: some View {
        VStack(spacing: 0) {
            Text("VOID RACER")
                .font(.system(size: 50, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .tracking(2.5)
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
                subtitle: "Ships and garage progression",
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
                
                LevelBackButton(action: appState.returnToMenu)
                    .padding(.leading, 18)
                    .padding(.top, proxy.safeAreaInsets.top + 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .ignoresSafeArea()
        }
        .onAppear {
            selection = appState.selectedLevel.rawValue
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
                
                VStack(spacing: 16) {
                    Text(level.name)
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(1.3)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                        .shadow(color: Color.black.opacity(0.60), radius: 14, y: 8)
                    
                    MenuActionButton(
                        title: "PLAY",
                        accent: level.gradient.last ?? .white,
                        symbolName: "play.fill",
                        action: {
                            appState.startGame(level: level)
                        }
                    )
                }
                .frame(maxWidth: 420)
                .padding(.horizontal, 24)
                .padding(.bottom, 54)
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
}

private struct LevelBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .black))
                .foregroundColor(.white)
                .frame(width: 42, height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Color.black.opacity(0.44))
                        .overlay(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .stroke(Color.white.opacity(0.28), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.28), radius: 14, y: 8)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back to menu")
    }
}

private struct MenuActionButton: View {
    let title: String
    let subtitle: String?
    let accent: Color
    let symbolName: String
    let action: () -> Void

    init(
        title: String,
        subtitle: String? = nil,
        accent: Color,
        symbolName: String,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.accent = accent
        self.symbolName = symbolName
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: subtitle == nil ? 0 : 7) {
                    Text(title)
                        .font(.system(size: 28, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(1.6)
                    
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.82))
                    }
                }
                
                Spacer()
                
                RetroNeonIcon(symbolName: symbolName, accent: accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 22)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.black.opacity(0.38))
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        accent.opacity(0.16),
                                        Color.white.opacity(0.035),
                                        Color.black.opacity(0.12)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(accent.opacity(0.55), lineWidth: 1.2)
                    )
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(accent.opacity(0.92))
                            .frame(width: 4)
                            .padding(.vertical, 18)
                            .shadow(color: accent.opacity(0.80), radius: 8)
                    }
            )
            .shadow(color: accent.opacity(0.22), radius: 22, y: 10)
        }
        .buttonStyle(.plain)
    }
}

private struct RetroNeonIcon: View {
    let symbolName: String
    let accent: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.52))
                .frame(width: 62, height: 62)
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(accent.opacity(0.92), lineWidth: 1.4)
                )
                .shadow(color: accent.opacity(0.70), radius: 10)

            RoundedRectangle(cornerRadius: 4)
                .stroke(accent.opacity(0.34), lineWidth: 1)
                .frame(width: 42, height: 42)
                .rotationEffect(.degrees(45))

            VStack(spacing: 5) {
                ForEach(0..<4, id: \.self) { _ in
                    Capsule()
                        .fill(accent.opacity(0.22))
                        .frame(width: 44, height: 1)
                }
            }

            Image(systemName: symbolName)
                .font(.system(size: 21, weight: .heavy))
                .foregroundColor(.white)
                .shadow(color: accent.opacity(0.95), radius: 7)
        }
        .accessibilityHidden(true)
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
