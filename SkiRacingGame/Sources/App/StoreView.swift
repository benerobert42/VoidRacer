import SwiftUI
import SceneKit
import UIKit

struct StoreView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedShip: ShipID = .executioner
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                storeBackground
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        previewSection(height: max(280, geo.size.height * 0.38))
                        skinSection
                        statsSection
                        shipCollection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, topChromeInset(for: geo))
                    .padding(.bottom, 36)
                }
            }
        }
        .onAppear {
            if !appState.owns(ship: selectedShip) {
                selectedShip = appState.equippedShip
            }
        }
    }

    private func topChromeInset(for geo: GeometryProxy) -> CGFloat {
        geo.safeAreaInsets.top + 26
    }
    
    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text("SHIPYARD STORE")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .tracking(1.2)
                
                Text("Choose a hull, preview it in 3D, then lock in the skin and stats package you want for the next run.")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.72))
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 10) {
                CurrencyCapsule(amount: appState.coins)
                
                Button(action: appState.returnToMenu) {
                    Label("MENU", systemImage: "chevron.left")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.08))
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private func previewSection(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(selectedShip.name)
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text(selectedShip.subtitle)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.72))
                }
                
                Spacer()
                
                ownershipPill(for: selectedShip)
            }
            
            ShipPreviewView(
                shipName: selectedShip.rawValue,
                textureName: appState.textureName(for: selectedShip)
            )
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .overlay(
                RoundedRectangle(cornerRadius: 28)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
        }
    }
    
    private var skinSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("SKINS")
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ShipSkin.allCases) { skin in
                        SkinChip(
                            ship: selectedShip,
                            skin: skin,
                            isShipOwned: appState.owns(ship: selectedShip),
                            isOwned: appState.owns(ship: selectedShip, skin: skin),
                            isEquipped: appState.equippedSkin(for: selectedShip) == skin,
                            canAfford: appState.canAfford(ship: selectedShip, skin: skin),
                            buyAction: {
                                appState.buySkin(skin, for: selectedShip)
                            },
                            equipAction: {
                                appState.equipSkin(skin, for: selectedShip)
                            }
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionLabel("ATTRIBUTES")
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                AttributeCard(title: "Life", value: selectedShip.stats.life, tint: Color(red: 0.98, green: 0.34, blue: 0.46), icon: "heart.fill")
                AttributeCard(title: "Armor", value: selectedShip.stats.armor, tint: Color(red: 0.40, green: 0.84, blue: 1.0), icon: "shield.fill")
                AttributeCard(title: "Speed", value: selectedShip.stats.speed, tint: Color(red: 1.0, green: 0.74, blue: 0.20), icon: "bolt.fill")
                AttributeCard(title: "Agility", value: selectedShip.stats.agility, tint: Color(red: 0.42, green: 1.0, blue: 0.64), icon: "arrow.trianglehead.2.clockwise.rotate.90")
            }
            
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PRICE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.46))
                            .tracking(1.6)
                        
                        Text(selectedShip.price == 0 ? "Starter Unlock" : "\(selectedShip.price) credits")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    Spacer()
                    
                    primaryShipAction
                }
                
                Text(selectedShip.progressionNote)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.68))
                
                ProgressionHintCard(ownedShips: appState.ownedShips.count, totalShips: ShipID.allCases.count)
            }
            .padding(18)
            .background(sectionCardBackground)
        }
    }
    
    private var shipCollection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                sectionLabel("GARAGE")
                Spacer()
                Text("\(appState.ownedShips.count)/\(ShipID.allCases.count) UNLOCKED")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.42))
                    .tracking(1.2)
            }
            
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
            
            ForEach(ShipID.allCases) { ship in
                ShipStoreCard(
                    ship: ship,
                    isSelected: ship == selectedShip,
                    isOwned: appState.owns(ship: ship),
                    isEquipped: ship == appState.equippedShip,
                    action: {
                        selectedShip = ship
                    }
                )
            }
        }
    }
    
    private var primaryShipAction: some View {
        Group {
            if appState.owns(ship: selectedShip) {
                Button(action: {
                    appState.equip(ship: selectedShip)
                }) {
                    Text(selectedShip == appState.equippedShip ? "EQUIPPED" : "EQUIP SHIP")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 13)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: selectedShip == appState.equippedShip
                                            ? [Color.white.opacity(0.10), Color.white.opacity(0.08)]
                                            : selectedShip.accentGradient,
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                }
                .buttonStyle(.plain)
                .disabled(selectedShip == appState.equippedShip)
            } else {
                Button(action: {
                    appState.buy(ship: selectedShip)
                }) {
                    Text(appState.canAfford(ship: selectedShip) ? "BUY SHIP" : "NEED \(selectedShip.price - appState.coins) MORE")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 13)
                        .background(
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: appState.canAfford(ship: selectedShip)
                                            ? selectedShip.accentGradient
                                            : [Color.white.opacity(0.10), Color.white.opacity(0.08)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                }
                .buttonStyle(.plain)
                .disabled(!appState.canAfford(ship: selectedShip))
            }
        }
    }
    
    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundColor(.white.opacity(0.54))
            .tracking(2.2)
    }
    
    private func ownershipPill(for ship: ShipID) -> some View {
        Text(ship == appState.equippedShip ? "EQUIPPED" : appState.owns(ship: ship) ? "OWNED" : "LOCKED")
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.10))
            )
    }
    
    private var sectionCardBackground: some View {
        RoundedRectangle(cornerRadius: 24)
            .fill(Color.white.opacity(0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
    }
    
    private var storeBackground: some View {
        LinearGradient(
            colors: [
                Color(red: 0.03, green: 0.02, blue: 0.06),
                Color(red: 0.07, green: 0.05, blue: 0.12),
                Color(red: 0.13, green: 0.05, blue: 0.19)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

struct ShipPreviewView: UIViewRepresentable {
    let shipName: String
    let textureName: String
    
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
        let textureImage = loadTextureImage()
        for child in scene.rootNode.childNodes {
            let clone = child.clone()
            applyTexture(textureImage, to: clone)
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
    
    private func loadTextureImage() -> UIImage? {
        guard let textureURL = Bundle.main.url(forResource: textureName, withExtension: "png", subdirectory: "\(shipName)/Textures") else {
            return nil
        }
        return UIImage(contentsOfFile: textureURL.path)
    }
    
    private func applyTexture(_ textureImage: UIImage?, to node: SCNNode) {
        if let geometry = node.geometry {
            configureMaterials(of: geometry, textureImage: textureImage)
        }
        
        node.enumerateChildNodes { child, _ in
            guard let geometry = child.geometry else { return }
            configureMaterials(of: geometry, textureImage: textureImage)
        }
    }
    
    private func configureMaterials(of geometry: SCNGeometry, textureImage: UIImage?) {
        let textureTransform = SCNMatrix4Translate(SCNMatrix4MakeScale(1, -1, 1), 0, -1, 0)
        
        for material in geometry.materials {
            if let textureImage {
                material.diffuse.contents = textureImage
                material.diffuse.contentsTransform = textureTransform
                material.diffuse.wrapS = .repeat
                material.diffuse.wrapT = .repeat
                material.diffuse.magnificationFilter = .linear
                material.diffuse.minificationFilter = .linear
                material.diffuse.mipFilter = .linear
            } else {
                material.diffuse.contents = UIColor(white: 0.82, alpha: 1.0)
            }
            
            material.lightingModel = .blinn
            material.ambient.contents = UIColor(white: 0.10, alpha: 1.0)
            material.emission.contents = UIColor.black
            material.specular.contents = UIColor(white: 0.22, alpha: 1.0)
            material.shininess = 0.28
            material.fresnelExponent = 0.55
            material.multiply.contents = UIColor.white
            material.isDoubleSided = true
        }
    }
}

struct SkinChip: View {
    let ship: ShipID
    let skin: ShipSkin
    let isShipOwned: Bool
    let isOwned: Bool
    let isEquipped: Bool
    let canAfford: Bool
    let buyAction: () -> Void
    let equipAction: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                RoundedRectangle(cornerRadius: 18)
                    .fill(
                        LinearGradient(
                            colors: [
                                skin.swatch.opacity(0.92),
                                skin.swatch.opacity(0.56)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 130, height: 84)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(.white.opacity(0.18), lineWidth: 1)
                    )
                
                Text(skin.name)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(statusText)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.64))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 22)
                    .fill(isEquipped ? Color.white.opacity(0.12) : Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(isEquipped ? skin.swatch.opacity(0.75) : Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
    
    private var isDisabled: Bool {
        !isShipOwned || isEquipped || (!isOwned && !canAfford)
    }
    
    private var statusText: String {
        if !isShipOwned { return "LOCKED WITH SHIP" }
        if isEquipped { return "EQUIPPED" }
        if isOwned { return "TAP TO EQUIP" }
        return skin.price == 0 ? "FREE" : "BUY \(skin.price)"
    }
    
    private func action() {
        guard isShipOwned else { return }
        if isOwned {
            equipAction()
        } else {
            buyAction()
        }
    }
}

struct AttributeCard: View {
    let title: String
    let value: Int
    let tint: Color
    let icon: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(tint)
                Spacer()
                Text("\(value)/5")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(.white.opacity(0.54))
                .tracking(1.5)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            HStack(spacing: 6) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(index < value ? tint : Color.white.opacity(0.10))
                        .frame(height: 8)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.10), lineWidth: 1)
                )
        )
    }
}

struct ProgressionHintCard: View {
    let ownedShips: Int
    let totalShips: Int
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "rectangle.grid.2x2.fill")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.38))
            
            VStack(alignment: .leading, spacing: 4) {
                Text("COLLECTION")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(.white.opacity(0.42))
                    .tracking(1.6)
                
                HStack(spacing: 5) {
                    ForEach(0..<totalShips, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(index < ownedShips
                                  ? Color(red: 0.16, green: 0.96, blue: 1.0).opacity(0.82)
                                  : Color.white.opacity(0.10))
                            .frame(height: 6)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
        )
    }
}

struct ShipStoreCard: View {
    let ship: ShipID
    let isSelected: Bool
    let isOwned: Bool
    let isEquipped: Bool
    let action: () -> Void
    
    private var accentColor: Color {
        ship.accentGradient.first ?? .white
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 0) {
                // Left accent bar — futuristic hangar indicator
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: ship.accentGradient,
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: isSelected ? 5 : 3)
                    .opacity(isSelected ? 1.0 : (isOwned ? 0.55 : 0.22))
                    .padding(.vertical, 8)
                
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(ship.name)
                                    .font(.system(size: 16, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                    .tracking(0.8)
                                
                                if isEquipped {
                                    Text("ACTIVE")
                                        .font(.system(size: 9, weight: .black, design: .monospaced))
                                        .foregroundColor(accentColor)
                                        .padding(.horizontal, 7)
                                        .padding(.vertical, 3)
                                        .background(
                                            Capsule()
                                                .fill(accentColor.opacity(0.16))
                                                .overlay(
                                                    Capsule()
                                                        .stroke(accentColor.opacity(0.32), lineWidth: 1)
                                                )
                                        )
                                }
                            }
                            
                            Text(ship.subtitle)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(.white.opacity(0.48))
                                .lineLimit(1)
                        }
                        
                        Spacer(minLength: 12)
                        
                        if isOwned {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(accentColor.opacity(0.72))
                        } else {
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("\(ship.price)")
                                    .font(.system(size: 15, weight: .black, design: .rounded))
                                    .foregroundColor(.white)
                                Text("CR")
                                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.36))
                                    .tracking(1.0)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.white.opacity(0.09) : Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isSelected ? accentColor.opacity(0.32) : Color.white.opacity(0.06),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(
                color: isSelected ? accentColor.opacity(0.12) : .clear,
                radius: 12, y: 4
            )
        }
        .buttonStyle(.plain)
    }
}
