import SwiftUI
import SceneKit
import UIKit

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
        LinearGradient(
            colors: [
                Color(red: 0.015, green: 0.015, blue: 0.026),
                Color(red: 0.045, green: 0.047, blue: 0.075),
                Color(red: 0.085, green: 0.055, blue: 0.100)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
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
        ship.accentGradient.first ?? .white
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: StoreSafeArea.topInset(for: geometry) + 48)

            titleBlock

            ShipPreviewView(shipName: ship.rawValue)
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
        return min(max(safeHeight * 0.48, 300), 500)
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
            Color(red: 0.12, green: 0.88, blue: 1.0),
            Color(red: 0.02, green: 0.42, blue: 0.92)
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

struct ShipPreviewView: UIViewRepresentable {
    let shipName: String

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.backgroundColor = .clear
        view.scene = makeScene()
        view.allowsCameraControl = false
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling4X
        view.isPlaying = true
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        uiView.scene = makeScene()
    }

    private func makeScene() -> SCNScene {
        let scene = SCNScene()
        scene.background.contents = UIColor.clear

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 33
        cameraNode.camera?.wantsHDR = true
        cameraNode.camera?.wantsExposureAdaptation = false
        cameraNode.camera?.zNear = 0.1
        cameraNode.camera?.zFar = 100.0
        cameraNode.position = SCNVector3(0, 0.8, 7.0)
        scene.rootNode.addChildNode(cameraNode)

        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .directional
        keyLight.light?.intensity = 1100
        keyLight.light?.color = UIColor(red: 1.0, green: 0.96, blue: 0.92, alpha: 1.0)
        keyLight.eulerAngles = SCNVector3(-0.9, 0.7, 0.2)
        scene.rootNode.addChildNode(keyLight)

        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .omni
        fillLight.light?.intensity = 420
        fillLight.light?.color = UIColor(red: 0.58, green: 0.86, blue: 1.0, alpha: 1.0)
        fillLight.position = SCNVector3(-4.5, 1.5, 6.5)
        scene.rootNode.addChildNode(fillLight)

        let rimLight = SCNNode()
        rimLight.light = SCNLight()
        rimLight.light?.type = .omni
        rimLight.light?.intensity = 560
        rimLight.light?.color = UIColor(red: 0.95, green: 0.52, blue: 1.0, alpha: 1.0)
        rimLight.position = SCNVector3(2.2, 2.0, -6.0)
        scene.rootNode.addChildNode(rimLight)

        let ambient = SCNNode()
        ambient.light = SCNLight()
        ambient.light?.type = .ambient
        ambient.light?.intensity = 120
        ambient.light?.color = UIColor(white: 0.30, alpha: 1.0)
        scene.rootNode.addChildNode(ambient)

        let floorGlow = SCNNode(geometry: SCNPlane(width: 10, height: 10))
        floorGlow.geometry?.firstMaterial?.diffuse.contents = UIColor(white: 0.10, alpha: 0.18)
        floorGlow.geometry?.firstMaterial?.emission.contents = UIColor(red: 0.08, green: 0.22, blue: 0.28, alpha: 0.10)
        floorGlow.geometry?.firstMaterial?.isDoubleSided = true
        floorGlow.geometry?.firstMaterial?.lightingModel = .lambert
        floorGlow.eulerAngles.x = -.pi / 2
        floorGlow.position = SCNVector3(0, -1.18, 0)
        scene.rootNode.addChildNode(floorGlow)

        if let shipNode = loadShipNode() {
            scene.rootNode.addChildNode(shipNode)
        }

        return scene
    }

    private func loadShipNode() -> SCNNode? {
        guard let objURL = Bundle.main.url(forResource: shipName, withExtension: "obj", subdirectory: "\(shipName)/OBJ") else {
            return nil
        }

        guard let scene = try? SCNScene(url: objURL, options: nil) else {
            return nil
        }

        let container = SCNNode()
        for child in scene.rootNode.childNodes {
            let clone = child.clone()
            applySilverMaterial(to: clone)
            container.addChildNode(clone)
        }

        let (minVec, maxVec) = container.boundingBox
        let sizeX = maxVec.x - minVec.x
        let sizeY = maxVec.y - minVec.y
        let sizeZ = maxVec.z - minVec.z
        let maxDimension = max(sizeX, max(sizeY, sizeZ))
        let scale = maxDimension > 0 ? 2.9 / maxDimension : 1.0
        container.scale = SCNVector3(scale, scale, scale)

        let centerX = (minVec.x + maxVec.x) * 0.5
        let centerY = (minVec.y + maxVec.y) * 0.5
        let centerZ = (minVec.z + maxVec.z) * 0.5
        container.position = SCNVector3(-centerX * scale, -centerY * scale, -centerZ * scale)
        container.runAction(.repeatForever(.rotateBy(x: 0, y: CGFloat.pi * 2, z: 0, duration: 18)))
        return container
    }

    private func applySilverMaterial(to node: SCNNode) {
        if let geometry = node.geometry {
            configureMaterials(of: geometry)
        }

        node.enumerateChildNodes { child, _ in
            guard let geometry = child.geometry else { return }
            configureMaterials(of: geometry)
        }
    }

    private func configureMaterials(of geometry: SCNGeometry) {
        for material in geometry.materials {
            material.lightingModel = .phong
            material.diffuse.contents = UIColor(red: 0.78, green: 0.80, blue: 0.83, alpha: 1.0)
            material.ambient.contents = UIColor(white: 0.08, alpha: 1.0)
            material.emission.contents = UIColor.black
            material.specular.contents = UIColor(white: 0.95, alpha: 1.0)
            material.shininess = 0.86
            material.fresnelExponent = 0.40
            material.multiply.contents = UIColor.white
            material.isDoubleSided = true
        }
    }
}
