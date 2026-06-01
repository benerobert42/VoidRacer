import SwiftUI

struct GameOverView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.03, blue: 0.09),
                    Color(red: 0.11, green: 0.03, blue: 0.06),
                    Color.black
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer(minLength: 32)

                VStack(spacing: 10) {
                    Text("GAME OVER")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .tracking(4)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.34, blue: 0.48),
                                    Color(red: 1.0, green: 0.70, blue: 0.20)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.red.opacity(0.35), radius: 18)

                    Text("Reset fast and chase a cleaner line.")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.72))
                        .tracking(1.2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                VStack(spacing: 14) {
                    resultCard(
                        title: "LAST RUN SCORE",
                        value: "\(appState.lastRunScore)",
                        accent: Color(red: 0.14, green: 0.92, blue: 1.0)
                    )

                    HStack(spacing: 14) {
                        resultCard(
                            title: "CREDITS GAINED",
                            value: "\(appState.lastRunCoins)",
                            accent: Color(red: 0.99, green: 0.70, blue: 0.18)
                        )

                        resultCard(
                            title: "XP GAINED",
                            value: "\(appState.lastRunXP)",
                            accent: Color(red: 0.22, green: 0.98, blue: 0.86)
                        )
                    }
                    
                    HStack(spacing: 14) {
                        resultCard(
                            title: "PILOT RANK",
                            value: appState.lastRunRankUps > 0
                                ? "R\(appState.pilotRank)  +\(appState.lastRunRankUps)"
                                : "R\(appState.pilotRank)",
                            accent: Color(red: 0.56, green: 0.62, blue: 1.0)
                        )
                        
                        resultCard(
                            title: "LEVEL",
                            value: appState.selectedLevel.name,
                            accent: Color(red: 1.0, green: 0.36, blue: 0.62)
                        )
                    }

                    resultCard(
                        title: "NEXT RUN VISUAL MODE",
                        value: appState.activeRunVisualModifier.mood.name,
                        accent: Color(red: 0.18, green: 0.86, blue: 1.0)
                    )
                }
                
                if !appState.lastRunCompletedMissions.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("CONTRACTS CLEARED")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .tracking(2)
                            .foregroundColor(.white.opacity(0.62))
                        
                        ForEach(appState.lastRunCompletedMissions) { reward in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(reward.mission.title.uppercased())
                                    .font(.system(size: 12, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .tracking(0.9)
                                Text(reward.rewardSummary)
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(Color(red: 0.22, green: 0.98, blue: 0.86))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.white.opacity(0.07))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                        }
                    }
                }

                VStack(spacing: 12) {
                    Button(action: appState.retryLastGame) {
                        Text("TRY AGAIN")
                            .font(.system(size: 18, weight: .black, design: .rounded))
                            .tracking(2)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.16, green: 0.96, blue: 1.0),
                                                Color(red: 0.42, green: 1.0, blue: 0.84)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                            .shadow(color: Color.cyan.opacity(0.35), radius: 20)
                    }

                    Button(action: appState.returnToMenu) {
                        Text("MAIN MENU")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .tracking(1.6)
                            .foregroundColor(.white.opacity(0.92))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.white.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Color.white.opacity(0.14), lineWidth: 1)
                            )
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 28)
        }
    }

    private func resultCard(title: String, value: String, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(1.4)
                .foregroundColor(accent.opacity(0.95))
                .lineLimit(1)
                .minimumScaleFactor(0.65)

            Text(value)
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(accent.opacity(0.45), lineWidth: 1.4)
        )
        .shadow(color: accent.opacity(0.16), radius: 16)
    }
}
