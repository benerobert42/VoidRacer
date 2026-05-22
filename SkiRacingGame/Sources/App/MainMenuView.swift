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
                    .padding(.bottom, 110)
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

            HStack(spacing: 12) {
                CompactMenuActionButton(
                    title: "ACHIEVEMENTS",
                    subtitle: "10 locked",
                    accent: Color(red: 0.64, green: 0.34, blue: 0.98),
                    symbolName: "trophy.fill",
                    action: appState.openAchievements
                )

                CompactMenuActionButton(
                    title: "SHOP",
                    subtitle: "Soon",
                    accent: Color(red: 0.12, green: 0.88, blue: 1.0),
                    symbolName: "cart.fill",
                    action: {}
                )
            }
            .frame(maxWidth: .infinity)
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

private struct CompactMenuActionButton: View {
    let title: String
    let subtitle: String
    let accent: Color
    let symbolName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbolName)
                    .font(.system(size: 17, weight: .black))
                    .foregroundColor(.white)
                    .frame(width: 38, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(Color.black.opacity(0.48))
                            .overlay(
                                RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .stroke(accent.opacity(0.78), lineWidth: 1.1)
                            )
                            .shadow(color: accent.opacity(0.62), radius: 8)
                    )

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(0.8)
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)

                    Text(subtitle)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.66))
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(0.36))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        accent.opacity(0.14),
                                        Color.white.opacity(0.032),
                                        Color.black.opacity(0.10)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(accent.opacity(0.48), lineWidth: 1.1)
                    )
            )
            .shadow(color: accent.opacity(0.18), radius: 16, y: 8)
        }
        .buttonStyle(.plain)
    }
}

struct AchievementsView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.ignoresSafeArea()

                TerrainPreviewView(level: appState.selectedLevel, scrollSpeed: 34, preferredFramesPerSecond: 30)
                    .ignoresSafeArea()
                    .clipped()

                LinearGradient(
                    colors: [
                        Color.black.opacity(0.42),
                        Color.black.opacity(0.64),
                        Color.black.opacity(0.86)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 18) {
                    achievementsHeader(topInset: proxy.safeAreaInsets.top)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            ForEach(dummyAchievements) { achievement in
                                AchievementRow(achievement: achievement)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, max(proxy.safeAreaInsets.bottom + 26, 44))
                    }
                }
            }
            .ignoresSafeArea()
        }
    }

    private func achievementsHeader(topInset: CGFloat) -> some View {
        HStack(spacing: 14) {
            Button(action: appState.returnToMenu) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(GlassRoundedBackground(cornerRadius: 16, tint: Color.white.opacity(0.04)))
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 4) {
                Text("ACHIEVEMENTS")
                    .font(.system(size: 25, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(1.3)

                Text("Locked challenges to unlock later")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.64))
            }

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, topInset + 16)
    }
}

private struct AchievementRow: View {
    let achievement: DummyAchievement

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.52))
                    .frame(width: 58, height: 58)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(achievement.accent.opacity(0.64), lineWidth: 1.1)
                    )
                    .shadow(color: achievement.accent.opacity(0.34), radius: 10)

                Image(systemName: achievement.symbolName)
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(.white.opacity(0.90))
                    .shadow(color: achievement.accent.opacity(0.80), radius: 7)

                Image(systemName: "lock.fill")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.black.opacity(0.78))
                    .padding(5)
                    .background(Circle().fill(achievement.accent))
                    .offset(x: 22, y: 22)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(achievement.title)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(achievement.requirement)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.62))
                    .lineLimit(2)

                ProgressView(value: 0.0)
                    .tint(achievement.accent)
                    .scaleEffect(x: 1, y: 0.65, anchor: .center)
            }

            Spacer(minLength: 8)

            Text("LOCKED")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundColor(achievement.accent)
                .tracking(1.2)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(achievement.accent.opacity(0.12))
                        .overlay(Capsule().stroke(achievement.accent.opacity(0.42), lineWidth: 1))
                )
        }
        .padding(14)
        .background(GlassRoundedBackground(cornerRadius: 24, tint: achievement.accent.opacity(0.07)))
    }
}

private struct DummyAchievement: Identifiable {
    let id = UUID()
    let title: String
    let requirement: String
    let symbolName: String
    let accent: Color
}

private let dummyAchievements: [DummyAchievement] = [
    DummyAchievement(title: "Thread The Needle", requirement: "Unlock by scoring 20 near misses in one run.", symbolName: "scope", accent: Color(red: 0.12, green: 0.88, blue: 1.0)),
    DummyAchievement(title: "Solar Surfer", requirement: "Unlock by surviving 180 seconds.", symbolName: "sun.max.fill", accent: Color(red: 1.0, green: 0.72, blue: 0.20)),
    DummyAchievement(title: "Void Banker", requirement: "Unlock by collecting 2,500 credits.", symbolName: "bitcoinsign.circle.fill", accent: Color(red: 1.0, green: 0.84, blue: 0.24)),
    DummyAchievement(title: "No-Scratch Run", requirement: "Unlock by finishing 90 seconds without taking damage.", symbolName: "shield.fill", accent: Color(red: 0.22, green: 0.86, blue: 0.54)),
    DummyAchievement(title: "Jump Chain", requirement: "Unlock by chaining 5 jump pads.", symbolName: "arrow.up.forward.circle.fill", accent: Color(red: 0.60, green: 0.36, blue: 1.0)),
    DummyAchievement(title: "Overdrive Pilot", requirement: "Unlock by using 3 boost pads in one run.", symbolName: "bolt.fill", accent: Color(red: 1.0, green: 0.48, blue: 0.08)),
    DummyAchievement(title: "Canyon Reader", requirement: "Unlock by clearing 12 route forks.", symbolName: "map.fill", accent: Color(red: 0.18, green: 0.78, blue: 1.0)),
    DummyAchievement(title: "Chrome Collector", requirement: "Unlock by owning 3 ships.", symbolName: "paperplane.fill", accent: Color(red: 0.86, green: 0.88, blue: 0.94)),
    DummyAchievement(title: "Risk Line", requirement: "Unlock by collecting 30 edge orbs.", symbolName: "circle.hexagongrid.fill", accent: Color(red: 1.0, green: 0.18, blue: 0.72)),
    DummyAchievement(title: "Night Machine", requirement: "Unlock by playing every level in one session.", symbolName: "moon.stars.fill", accent: Color(red: 0.44, green: 0.66, blue: 1.0))
]

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
