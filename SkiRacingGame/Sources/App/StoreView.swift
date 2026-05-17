import SwiftUI
import UIKit

private enum StorePalette {
    static let neonCyan = Color(red: 0.12, green: 0.88, blue: 1.0)
    static let neonBlue = Color(red: 0.02, green: 0.42, blue: 0.92)
}

struct StoreView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedShip = ShipID.executioner

    var body: some View {
        GeometryReader { geo in
            ZStack {
                storeBackground

                TabView(selection: $selectedShip) {
                    ForEach(ShipID.allCases) { ship in
                        ShipStorePage(ship: ship, geometry: geo)
                            .tag(ship)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea()

                storeChrome(for: geo)
            }
            .ignoresSafeArea()
        }
        .onAppear {
            selectedShip = appState.equippedShip
        }
    }

    private func storeChrome(for geo: GeometryProxy) -> some View {
        StoreBackButton(action: appState.returnToMenu)
            .padding(.leading, 18)
            .padding(.top, StoreSafeArea.topInset(for: geo) + 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .zIndex(10)
    }

    private var storeBackground: some View {
        TerrainPreviewView(
            level: appState.selectedLevel,
            scrollSpeed: 12,
            preferredFramesPerSecond: 30,
            storeGridPalette: true
        )
        .overlay(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.12),
                    Color.black.opacity(0.02),
                    Color.black.opacity(0.34)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .ignoresSafeArea()
    }
}

private struct StoreSpaceBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.003, green: 0.005, blue: 0.014),
                    Color(red: 0.010, green: 0.018, blue: 0.040),
                    Color(red: 0.026, green: 0.018, blue: 0.040),
                    Color(red: 0.002, green: 0.004, blue: 0.012)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    StorePalette.neonBlue.opacity(0.18),
                    StorePalette.neonCyan.opacity(0.05),
                    .clear
                ],
                center: UnitPoint(x: 0.18, y: 0.26),
                startRadius: 10,
                endRadius: 360
            )

            RadialGradient(
                colors: [
                    Color(red: 0.75, green: 0.28, blue: 1.0).opacity(0.10),
                    .clear
                ],
                center: UnitPoint(x: 0.82, y: 0.72),
                startRadius: 20,
                endRadius: 420
            )

            StoreStarfield()
                .opacity(0.86)
        }
        .ignoresSafeArea()
    }
}

private struct StoreStarfield: View {
    var body: some View {
        Canvas { context, size in
            for index in 0..<130 {
                let seed = CGFloat(index)
                let x = starHash(seed * 12.9898 + 4.0) * size.width
                let y = starHash(seed * 78.233 + 9.0) * size.height
                let brightness = 0.28 + starHash(seed * 39.425 + 2.0) * 0.62
                let radius = 0.55 + starHash(seed * 91.717 + 6.0) * 1.35
                let rect = CGRect(x: x, y: y, width: radius, height: radius)
                context.fill(
                    Path(ellipseIn: rect),
                    with: .color(Color.white.opacity(brightness))
                )
            }

            for index in 0..<22 {
                let seed = CGFloat(index)
                let x = starHash(seed * 20.113 + 3.0) * size.width
                let y = starHash(seed * 51.371 + 7.0) * size.height
                let length = 10 + starHash(seed * 13.579 + 8.0) * 24
                var path = Path()
                path.move(to: CGPoint(x: x - length * 0.5, y: y))
                path.addLine(to: CGPoint(x: x + length * 0.5, y: y))
                context.stroke(path, with: .color(StorePalette.neonCyan.opacity(0.18)), lineWidth: 0.55)
            }
        }
        .blur(radius: 0.15)
    }

    private func starHash(_ value: CGFloat) -> CGFloat {
        let raw = sin(value) * 43_758.5453
        return raw - floor(raw)
    }
}

private struct ShipStorePage: View {
    @EnvironmentObject var appState: AppState

    let ship: ShipID
    let geometry: GeometryProxy

    private var isOwned: Bool {
        appState.owns(ship: ship)
    }

    private var isEquipped: Bool {
        appState.equippedShip == ship
    }

    private var accentColor: Color {
        StorePalette.neonCyan
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: StoreSafeArea.topInset(for: geometry) + 48)

            titleBlock

            ShipPreviewView(shipName: ship.rawValue)
                .padding(.horizontal, -42)
                .padding(.vertical, -18)
                .offset(y: 30)
                .frame(maxWidth: .infinity)
                .frame(height: previewHeight)
                .contentShape(Rectangle())

            VStack(spacing: 14) {
                statLines
                priceAndAction
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.white.opacity(0.055))
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )

            StorePageIndicator(currentShip: ship)

            Spacer(minLength: StoreSafeArea.bottomInset(for: geometry) + 14)
        }
        .padding(.horizontal, 22)
    }

    private var previewHeight: CGFloat {
        let safeHeight = geometry.size.height
            - StoreSafeArea.topInset(for: geometry)
            - StoreSafeArea.bottomInset(for: geometry)
        return min(max(safeHeight * 0.62, 420), 620)
    }

    private var titleBlock: some View {
        VStack(spacing: 8) {
            Text(ship.name)
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .tracking(1.4)
                .lineLimit(1)
                .minimumScaleFactor(0.70)

            Text(ship.subtitle)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.68))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: 340)

            Text(isEquipped ? "EQUIPPED" : isOwned ? "OWNED" : "LOCKED")
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundColor(.white.opacity(0.86))
                .tracking(1.4)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(accentColor.opacity(isEquipped ? 0.30 : 0.16))
                        .overlay(
                            Capsule()
                                .stroke(accentColor.opacity(0.35), lineWidth: 1)
                        )
                )
        }
    }

    private var statLines: some View {
        VStack(spacing: 12) {
            ShipStoreStatLine(title: "Life", value: ship.stats.life, tint: Color(red: 0.98, green: 0.30, blue: 0.38))
            ShipStoreStatLine(title: "Armor", value: ship.stats.armor, tint: Color(red: 0.34, green: 0.76, blue: 1.0))
            ShipStoreStatLine(title: "Speed", value: ship.stats.speed, tint: Color(red: 1.0, green: 0.72, blue: 0.20))
        }
    }

    private var priceAndAction: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("PRICE")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.42))
                    .tracking(1.7)

                Text(priceText)
                    .font(.system(size: 21, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 8)

            Button(action: performPrimaryAction) {
                Text(primaryActionTitle)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(0.7)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 13)
                    .background(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: primaryActionColors,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    )
            }
            .buttonStyle(.plain)
            .disabled(isEquipped || (!isOwned && !appState.canAfford(ship: ship)))
        }
    }

    private var priceText: String {
        ship.price == 0 ? "Starter" : "\(ship.price) credits"
    }

    private var primaryActionTitle: String {
        if isEquipped { return "ACTIVE" }
        if isOwned { return "EQUIP" }
        if appState.canAfford(ship: ship) { return "BUY" }
        return "NEED \(ship.price - appState.coins)"
    }

    private var primaryActionColors: [Color] {
        if isEquipped || (!isOwned && !appState.canAfford(ship: ship)) {
            return [Color.white.opacity(0.10), Color.white.opacity(0.07)]
        }
        return [
            StorePalette.neonCyan,
            StorePalette.neonBlue
        ]
    }

    private func performPrimaryAction() {
        if isOwned {
            appState.equip(ship: ship)
            return
        }

        appState.buy(ship: ship)
        if appState.owns(ship: ship) {
            appState.equip(ship: ship)
        }
    }
}

private struct ShipStoreStatLine: View {
    let title: String
    let value: Int
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.58))
                .tracking(1.5)
                .frame(width: 58, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.10))
                    Capsule()
                        .fill(tint)
                        .frame(width: proxy.size.width * CGFloat(value) / 5.0)
                }
            }
            .frame(height: 7)

            Text("\(value)/5")
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(.white.opacity(0.78))
                .frame(width: 34, alignment: .trailing)
        }
    }
}

private struct StorePageIndicator: View {
    let currentShip: ShipID

    var body: some View {
        HStack(spacing: 7) {
            ForEach(ShipID.allCases) { ship in
                Capsule()
                    .fill(ship == currentShip ? Color.white.opacity(0.78) : Color.white.opacity(0.20))
                    .frame(width: ship == currentShip ? 20 : 7, height: 7)
            }
        }
        .padding(.top, 2)
    }
}

private struct StoreShipProjectionGrid: View {
    let accentColor: Color

    var body: some View {
        Canvas { context, size in
            let horizonY = size.height * 0.18
            let bottomY = size.height * 0.96
            let centerX = size.width * 0.5
            let rowCount = 10
            let columnCount = 30
            let fillColor = StorePalette.neonCyan.opacity(0.026)
            let weakLine = StorePalette.neonCyan.opacity(0.42)
            let strongLine = StorePalette.neonCyan.opacity(0.82)

            let rowT: (Int) -> CGFloat = { row in
                CGFloat(row) / CGFloat(rowCount)
            }
            let rowY: (Int) -> CGFloat = { row in
                let t = rowT(row)
                return horizonY + pow(t, 1.85) * (bottomY - horizonY)
            }
            let projectedX: (Int, CGFloat) -> CGFloat = { column, t in
                let colT = CGFloat(column) / CGFloat(columnCount)
                let bottomX = (colT * 3.0 - 1.0) * size.width
                let topX = centerX + (bottomX - centerX) * 0.34
                return topX + (bottomX - topX) * t
            }

            for row in 0..<rowCount {
                let nearT = rowT(row)
                let farT = rowT(row + 1)
                let farY = rowY(row)
                let nearY = rowY(row + 1)

                for column in 0..<columnCount {
                    var cell = Path()
                    cell.move(to: CGPoint(x: projectedX(column, farT), y: farY))
                    cell.addLine(to: CGPoint(x: projectedX(column + 1, farT), y: farY))
                    cell.addLine(to: CGPoint(x: projectedX(column + 1, nearT), y: nearY))
                    cell.addLine(to: CGPoint(x: projectedX(column, nearT), y: nearY))
                    cell.closeSubpath()
                    context.fill(cell, with: .color(fillColor))
                }
            }

            for index in 0...rowCount {
                let y = rowY(index)
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(index % 3 == 0 ? strongLine : weakLine), lineWidth: index % 3 == 0 ? 1.05 : 0.62)
            }

            for index in 0...columnCount {
                var path = Path()
                path.move(to: CGPoint(x: projectedX(index, 0.0), y: horizonY))
                path.addLine(to: CGPoint(x: projectedX(index, 1.0), y: bottomY))
                context.stroke(path, with: .color(index % 3 == 0 ? strongLine : weakLine), lineWidth: index % 3 == 0 ? 1.0 : 0.58)
            }

            var centerPath = Path()
            centerPath.move(to: CGPoint(x: centerX, y: horizonY))
            centerPath.addLine(to: CGPoint(x: centerX, y: bottomY))
            context.stroke(centerPath, with: .color(StorePalette.neonCyan.opacity(0.72)), lineWidth: 1.2)
        }
        .shadow(color: StorePalette.neonCyan.opacity(0.36), radius: 9)
        .blur(radius: 0.08)
        .mask(
            LinearGradient(
                colors: [.clear, .white.opacity(0.72), .white.opacity(0.88), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .allowsHitTesting(false)
    }
}

private struct StoreHangarBackdrop: View {
    let accentColor: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.006, green: 0.008, blue: 0.018),
                        Color(red: 0.018, green: 0.026, blue: 0.050),
                        Color(red: 0.030, green: 0.020, blue: 0.044)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                StoreFloorGrid(accentColor: accentColor)
                    .opacity(0.82)
                    .frame(height: proxy.size.height * 0.58)
                    .frame(maxHeight: .infinity, alignment: .bottom)
            }
        }
        .allowsHitTesting(false)
    }
}

private struct StoreFloorGrid: View {
    let accentColor: Color

    var body: some View {
        Canvas { context, size in
            let horizonY = size.height * 0.08
            let bottomY = size.height
            let centerX = size.width * 0.5
            let lineColor = accentColor.opacity(0.42)
            let strongLineColor = StorePalette.neonCyan.opacity(0.62)

            for index in 0...14 {
                let t = CGFloat(index) / 14.0
                let y = horizonY + pow(t, 1.85) * (bottomY - horizonY)
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(path, with: .color(index % 4 == 0 ? strongLineColor : lineColor), lineWidth: index % 4 == 0 ? 1.25 : 0.75)
            }

            for index in 0...24 {
                let t = CGFloat(index) / 24.0
                let bottomX = (t * 1.50 - 0.25) * size.width
                let topX = centerX + (bottomX - centerX) * 0.55
                var path = Path()
                path.move(to: CGPoint(x: topX, y: horizonY))
                path.addLine(to: CGPoint(x: bottomX, y: bottomY))
                context.stroke(path, with: .color(index % 4 == 0 ? strongLineColor : lineColor), lineWidth: index % 4 == 0 ? 1.35 : 0.75)
            }
        }
        .shadow(color: StorePalette.neonCyan.opacity(0.36), radius: 7)
        .blur(radius: 0.08)
        .mask(
            LinearGradient(
                colors: [.clear, .white.opacity(0.92), .white],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

private enum StoreSafeArea {
    static func topInset(for geometry: GeometryProxy) -> CGFloat {
        max(geometry.safeAreaInsets.top, windowInsets.top, 52)
    }

    static func bottomInset(for geometry: GeometryProxy) -> CGFloat {
        max(geometry.safeAreaInsets.bottom, windowInsets.bottom)
    }

    private static var windowInsets: UIEdgeInsets {
        let windowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        let window = windowScene?.windows.first { $0.isKeyWindow }
        return window?.safeAreaInsets ?? .zero
    }
}

private struct StoreBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .black))
                .foregroundColor(.white)
                .frame(width: 46, height: 46)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.black.opacity(0.50))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.28), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.36), radius: 14, y: 8)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back to menu")
    }
}

struct ShipPreviewView: View {
    let shipName: String
    @EnvironmentObject private var appState: AppState
    @State private var previewEngineWrapper: GameEngineWrapper

    init(shipName: String) {
        self.shipName = shipName
        let wrapper = GameEngineWrapper()
        wrapper.setVehicleMeshName(shipName)
        _previewEngineWrapper = State(initialValue: wrapper)
    }

    var body: some View {
        GameMetalView(
            engineWrapper: previewEngineWrapper,
            previewLevel: appState.selectedLevel,
            previewScrollSpeed: 12,
            showVehicle: true,
            showObstacles: false,
            showChaser: false,
            storeGridPalette: true,
            preferredFramesPerSecond: 30
        )
        .id(shipName)
        .clipShape(Rectangle())
        .onAppear(perform: syncPreview)
        .onChange(of: shipName) { _ in
            syncPreview()
        }
        .onChange(of: appState.selectedLevel.rawValue) { _ in
            syncPreview()
        }
    }

    private func syncPreview() {
        previewEngineWrapper.setVehicleMeshName(shipName)
        previewEngineWrapper.setLevel(Int32(appState.selectedLevel.rawValue))
    }
}
