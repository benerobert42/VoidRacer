import SwiftUI

enum AppScreen {
    case menu
    case levelSelect
    case store
    case game
    case gameOver
}

enum GameLevel: Int, CaseIterable {
    case neonSynthwave = 0
    case fieryRetrowave = 1
    case cyberpunkVoid = 2
    case debugMode = 3
    
    var name: String {
        switch self {
        case .neonSynthwave: return "NEON SYNTHWAVE"
        case .fieryRetrowave: return "FIERY RETROWAVE"
        case .cyberpunkVoid: return "CYBERPUNK VOID"
        case .debugMode: return "DEBUG MODE"
        }
    }
    
    var subtitle: String {
        switch self {
        case .neonSynthwave: return "Cyan and Magenta grids"
        case .fieryRetrowave: return "Scorched neon wasteland"
        case .cyberpunkVoid: return "Terminal hacker space"
        case .debugMode: return "Constant speed, visual logging"
        }
    }
    
    var icon: String {
        switch self {
        case .neonSynthwave: return "network"
        case .fieryRetrowave: return "flame"
        case .cyberpunkVoid: return "cpu"
        case .debugMode: return "ant.fill"
        }
    }
    
    var gradient: [Color] {
        switch self {
        case .neonSynthwave: return [Color(red: 0.9, green: 0.1, blue: 0.6), Color(red: 0.1, green: 0.9, blue: 0.9)]
        case .fieryRetrowave: return [Color(red: 0.8, green: 0.0, blue: 0.1), Color(red: 1.0, green: 0.7, blue: 0.0)]
        case .cyberpunkVoid: return [Color(red: 0.4, green: 0.0, blue: 0.8), Color(red: 0.2, green: 1.0, blue: 0.2)]
        case .debugMode: return [Color(red: 0.9, green: 0.2, blue: 0.2), Color(red: 0.5, green: 0.5, blue: 0.5)]
        }
    }
}

enum ShipSkin: String, CaseIterable, Identifiable {
    case blue = "Blue"
    case green = "Green"
    case orange = "Orange"
    case purple = "Purple"
    case red = "Red"
    
    var id: String { rawValue }
    
    var name: String { rawValue.uppercased() }
    
    var price: Int {
        switch self {
        case .blue: return 0
        case .green: return 180
        case .orange: return 240
        case .purple: return 320
        case .red: return 420
        }
    }
    
    var swatch: Color {
        switch self {
        case .blue: return Color(red: 0.22, green: 0.60, blue: 1.0)
        case .green: return Color(red: 0.22, green: 0.90, blue: 0.52)
        case .orange: return Color(red: 1.0, green: 0.58, blue: 0.16)
        case .purple: return Color(red: 0.64, green: 0.34, blue: 0.98)
        case .red: return Color(red: 1.0, green: 0.28, blue: 0.38)
        }
    }
}

enum ShipID: String, CaseIterable, Identifiable {
    case executioner = "Executioner"
    case challenger = "Challenger"
    case dispatcher = "Dispatcher"
    case imperial = "Imperial"
    case insurgent = "Insurgent"
    
    var id: String { rawValue }
    
    var name: String { rawValue.uppercased() }
    
    var subtitle: String {
        switch self {
        case .executioner: return "Starter interceptor with balanced handling"
        case .challenger: return "Low-profile frame built for clean racing lines"
        case .dispatcher: return "Wide-body bruiser with an industrial silhouette"
        case .imperial: return "Luxury-class cruiser with regal neon plating"
        case .insurgent: return "Aggressive late-game hull with sharp attack lines"
        }
    }
    
    var price: Int {
        switch self {
        case .executioner: return 0
        case .challenger: return 850
        case .dispatcher: return 1350
        case .imperial: return 1850
        case .insurgent: return 2400
        }
    }
    
    var stats: ShipStats {
        switch self {
        case .executioner:
            return ShipStats(life: 3, armor: 2, speed: 3, agility: 4)
        case .challenger:
            return ShipStats(life: 3, armor: 3, speed: 4, agility: 4)
        case .dispatcher:
            return ShipStats(life: 5, armor: 5, speed: 2, agility: 2)
        case .imperial:
            return ShipStats(life: 4, armor: 4, speed: 4, agility: 3)
        case .insurgent:
            return ShipStats(life: 4, armor: 3, speed: 5, agility: 5)
        }
    }
    
    var progressionNote: String {
        switch self {
        case .executioner:
            return "Starter hull with a forgiving learning curve and a free default livery."
        case .challenger:
            return "First aspirational unlock built to make your next purchase feel close and achievable."
        case .dispatcher:
            return "Tank-class unlock for players who enjoy visible collection growth and heavier silhouettes."
        case .imperial:
            return "Prestige cruiser priced like a mid-game flex piece with a premium silhouette."
        case .insurgent:
            return "Endgame chase ship tuned to feel like the garage completion milestone."
        }
    }
    
    var accentGradient: [Color] {
        switch self {
        case .executioner:
            return [Color(red: 0.17, green: 0.85, blue: 1.0), Color(red: 0.52, green: 0.36, blue: 1.0)]
        case .challenger:
            return [Color(red: 0.18, green: 0.95, blue: 0.76), Color(red: 0.06, green: 0.44, blue: 0.95)]
        case .dispatcher:
            return [Color(red: 1.0, green: 0.65, blue: 0.14), Color(red: 0.93, green: 0.24, blue: 0.22)]
        case .imperial:
            return [Color(red: 1.0, green: 0.42, blue: 0.70), Color(red: 0.52, green: 0.32, blue: 1.0)]
        case .insurgent:
            return [Color(red: 1.0, green: 0.30, blue: 0.32), Color(red: 1.0, green: 0.75, blue: 0.20)]
        }
    }
    
    var symbolName: String {
        switch self {
        case .executioner: return "paperplane.fill"
        case .challenger: return "bolt.horizontal.circle.fill"
        case .dispatcher: return "shield.lefthalf.filled"
        case .imperial: return "crown.fill"
        case .insurgent: return "flame.fill"
        }
    }
}

struct ShipStats {
    let life: Int
    let armor: Int
    let speed: Int
    let agility: Int
}

struct RunProgressSnapshot {
    let survivedSeconds: Int
    let bankedCoins: Int
    let nearMisses: Int
    let score: Int
}

enum ProgressionMissionKind: String, CaseIterable, Identifiable {
    case surviveSeconds
    case bankCoins
    case nearMisses
    
    var id: String { rawValue }
    
    func goal(for tier: Int) -> Int {
        let safeTier = max(1, tier)
        switch self {
        case .surviveSeconds:
            return 22 + ((safeTier - 1) * 6)
        case .bankCoins:
            return 40 + ((safeTier - 1) * 12)
        case .nearMisses:
            return 3 + (safeTier - 1)
        }
    }
    
    func creditReward(for tier: Int) -> Int {
        let safeTier = max(1, tier)
        switch self {
        case .surviveSeconds:
            return 70 + (safeTier * 18)
        case .bankCoins:
            return 85 + (safeTier * 20)
        case .nearMisses:
            return 90 + (safeTier * 22)
        }
    }
    
    func xpReward(for tier: Int) -> Int {
        let safeTier = max(1, tier)
        switch self {
        case .surviveSeconds:
            return 55 + (safeTier * 14)
        case .bankCoins:
            return 60 + (safeTier * 15)
        case .nearMisses:
            return 70 + (safeTier * 16)
        }
    }
    
    func achievedValue(in snapshot: RunProgressSnapshot) -> Int {
        switch self {
        case .surviveSeconds:
            return snapshot.survivedSeconds
        case .bankCoins:
            return snapshot.bankedCoins
        case .nearMisses:
            return snapshot.nearMisses
        }
    }
    
    func title(for goal: Int) -> String {
        switch self {
        case .surviveSeconds:
            return "Survive \(goal)s"
        case .bankCoins:
            return "Bank \(goal) credits"
        case .nearMisses:
            return "Land \(goal) near misses"
        }
    }
    
    func shortTitle(for goal: Int) -> String {
        switch self {
        case .surviveSeconds:
            return "SURVIVE \(goal)S"
        case .bankCoins:
            return "BANK \(goal)"
        case .nearMisses:
            return "NEAR MISS x\(goal)"
        }
    }
}

struct ProgressionMission: Identifiable {
    let kind: ProgressionMissionKind
    let tier: Int
    
    var id: String { kind.rawValue }
    var goal: Int { kind.goal(for: tier) }
    var title: String { kind.title(for: goal) }
    var shortTitle: String { kind.shortTitle(for: goal) }
    var creditReward: Int { kind.creditReward(for: tier) }
    var xpReward: Int { kind.xpReward(for: tier) }
}

struct CompletedMissionReward: Identifiable {
    let mission: ProgressionMission
    let achievedValue: Int
    
    var id: String { "\(mission.id)-tier-\(mission.tier)" }
    var rewardSummary: String { "+\(mission.creditReward) credits • +\(mission.xpReward) XP" }
}

private struct ProgressionResolution {
    let totalCredits: Int
    let totalXP: Int
    let rankUps: Int
    let completedMissions: [CompletedMissionReward]
}

class AppState: ObservableObject {
    private enum StorageKey {
        static let coins = "appState.coins"
        static let selectedLevel = "appState.selectedLevel"
        static let pilotRank = "appState.pilotRank"
        static let pilotXP = "appState.pilotXP"
        static let missionTiers = "appState.missionTiers"
        static let ownedShips = "appState.ownedShips"
        static let unlockedSkins = "appState.unlockedSkins"
        static let equippedShip = "appState.equippedShip"
        static let equippedSkins = "appState.equippedSkins"
    }
    
    @Published var currentScreen: AppScreen = .menu
    @Published var coins: Int = 1400
    @Published var selectedLevel: GameLevel = .neonSynthwave
    @Published private(set) var ownedShips: Set<ShipID> = [.executioner]
    @Published private(set) var unlockedSkinKeys: Set<String> = [AppState.skinKey(ship: .executioner, skin: .blue)]
    @Published private(set) var equippedShip: ShipID = .executioner
    @Published private(set) var equippedSkinRawValues: [String: String] = [ShipID.executioner.rawValue: ShipSkin.blue.rawValue]
    @Published private(set) var lastRunScore: Int = 0
    @Published private(set) var lastRunCoins: Int = 0
    @Published private(set) var lastRunXP: Int = 0
    @Published private(set) var lastRunRankUps: Int = 0
    @Published private(set) var lastRunCompletedMissions: [CompletedMissionReward] = []
    @Published private(set) var pilotRank: Int = 1
    @Published private(set) var pilotXP: Int = 0
    @Published private(set) var missionTiers: [String: Int] = Dictionary(
        uniqueKeysWithValues: ProgressionMissionKind.allCases.map { ($0.rawValue, 1) }
    )
    @Published private(set) var pendingGameEntryAnimation = false
    
    let engine: GameEngineWrapper
    
    init(engine: GameEngineWrapper) {
        self.engine = engine
        loadFromStorage()
        applyCurrentLoadoutToEngine()
    }
    
    func startGame(level: GameLevel) {
        selectedLevel = level
        applyCurrentLoadoutToEngine()
        engine.setLevel(Int32(level.rawValue))
        pendingGameEntryAnimation = true
        persist()
        currentScreen = .game
    }

    func openLevelSelect() {
        currentScreen = .levelSelect
    }
    
    func openStore() {
        currentScreen = .store
    }
    
    func returnToMenu() {
        currentScreen = .menu
    }
    
    var activeMissions: [ProgressionMission] {
        ProgressionMissionKind.allCases.map { kind in
            ProgressionMission(kind: kind, tier: missionTiers[kind.rawValue] ?? 1)
        }
    }
    
    var xpToNextRank: Int {
        xpRequired(for: pilotRank)
    }
    
    var pilotRankProgress: Double {
        let required = max(1, xpToNextRank)
        return Double(pilotXP) / Double(required)
    }
    
    func progressValue(for mission: ProgressionMission, in snapshot: RunProgressSnapshot) -> Int {
        min(mission.goal, mission.kind.achievedValue(in: snapshot))
    }
    
    func finishGame(bankCoins: Int, score: Int, survivedSeconds: Int, nearMisses: Int, died: Bool) {
        let snapshot = RunProgressSnapshot(
            survivedSeconds: survivedSeconds,
            bankedCoins: bankCoins,
            nearMisses: nearMisses,
            score: score
        )
        let progression = resolveProgression(from: snapshot)
        let totalCreditsAwarded = bankCoins + progression.totalCredits
        
        lastRunScore = score
        lastRunCoins = totalCreditsAwarded
        lastRunXP = progression.totalXP
        lastRunRankUps = progression.rankUps
        lastRunCompletedMissions = progression.completedMissions
        
        if totalCreditsAwarded > 0 {
            coins += totalCreditsAwarded
        }
        persist()
        currentScreen = died ? .gameOver : .menu
    }

    func retryLastGame() {
        startGame(level: selectedLevel)
    }

    func consumePendingGameEntryAnimation() -> Bool {
        let shouldAnimate = pendingGameEntryAnimation
        pendingGameEntryAnimation = false
        return shouldAnimate
    }
    
    func canAfford(ship: ShipID) -> Bool {
        coins >= ship.price
    }
    
    func canAfford(ship: ShipID, skin: ShipSkin) -> Bool {
        coins >= skin.price
    }
    
    func owns(ship: ShipID) -> Bool {
        ownedShips.contains(ship)
    }
    
    func owns(ship: ShipID, skin: ShipSkin) -> Bool {
        unlockedSkinKeys.contains(Self.skinKey(ship: ship, skin: skin))
    }
    
    func equippedSkin(for ship: ShipID) -> ShipSkin {
        guard
            let rawValue = equippedSkinRawValues[ship.rawValue],
            let skin = ShipSkin(rawValue: rawValue)
        else {
            return .blue
        }
        return skin
    }
    
    func buy(ship: ShipID) {
        guard !owns(ship: ship), canAfford(ship: ship) else { return }
        coins -= ship.price
        ownedShips.insert(ship)
        unlockedSkinKeys.insert(Self.skinKey(ship: ship, skin: .blue))
        equippedSkinRawValues[ship.rawValue] = equippedSkin(for: ship).rawValue
        persist()
    }
    
    func equip(ship: ShipID) {
        guard owns(ship: ship) else { return }
        equippedShip = ship
        applyCurrentLoadoutToEngine()
        persist()
    }
    
    func buySkin(_ skin: ShipSkin, for ship: ShipID) {
        guard owns(ship: ship), !owns(ship: ship, skin: skin), canAfford(ship: ship, skin: skin) else { return }
        coins -= skin.price
        unlockedSkinKeys.insert(Self.skinKey(ship: ship, skin: skin))
        equippedSkinRawValues[ship.rawValue] = skin.rawValue
        if equippedShip == ship {
            applyCurrentLoadoutToEngine()
        }
        persist()
    }
    
    func equipSkin(_ skin: ShipSkin, for ship: ShipID) {
        guard owns(ship: ship), owns(ship: ship, skin: skin) else { return }
        equippedSkinRawValues[ship.rawValue] = skin.rawValue
        if equippedShip == ship {
            applyCurrentLoadoutToEngine()
        }
        persist()
    }
    
    func textureName(for ship: ShipID) -> String {
        // Kept for inactive skin persistence; active render paths currently use a monochrome silver material.
        "\(ship.rawValue)_\(ShipSkin.blue.rawValue)"
    }
    
    private func applyCurrentLoadoutToEngine() {
        engine.setVehicleMeshName(equippedShip.rawValue)
        engine.setVehicleTextureName(textureName(for: equippedShip))
    }
    
    private func resolveProgression(from snapshot: RunProgressSnapshot) -> ProgressionResolution {
        var completedMissions: [CompletedMissionReward] = []
        var bonusCredits = 0
        
        let baseXP = max(
            20,
            snapshot.survivedSeconds + (snapshot.nearMisses * 18) + (snapshot.bankedCoins * 3) + (snapshot.score / 180)
        )
        var totalXP = baseXP
        
        for kind in ProgressionMissionKind.allCases {
            let mission = ProgressionMission(kind: kind, tier: missionTiers[kind.rawValue] ?? 1)
            let achievedValue = kind.achievedValue(in: snapshot)
            guard achievedValue >= mission.goal else { continue }
            
            completedMissions.append(
                CompletedMissionReward(
                    mission: mission,
                    achievedValue: achievedValue
                )
            )
            bonusCredits += mission.creditReward
            totalXP += mission.xpReward
            missionTiers[kind.rawValue] = mission.tier + 1
        }
        
        let rankResolution = awardXP(totalXP)
        bonusCredits += rankResolution.creditReward
        
        return ProgressionResolution(
            totalCredits: bonusCredits,
            totalXP: totalXP,
            rankUps: rankResolution.rankUps,
            completedMissions: completedMissions
        )
    }
    
    private func awardXP(_ amount: Int) -> (rankUps: Int, creditReward: Int) {
        guard amount > 0 else { return (0, 0) }
        
        var remainingXP = amount
        var rankUps = 0
        var creditReward = 0
        
        while remainingXP > 0 {
            let required = xpRequired(for: pilotRank)
            let missing = required - pilotXP
            if remainingXP < missing {
                pilotXP += remainingXP
                remainingXP = 0
            } else {
                remainingXP -= missing
                pilotXP = 0
                pilotRank += 1
                rankUps += 1
                creditReward += 80 + (pilotRank * 18)
            }
        }
        
        return (rankUps, creditReward)
    }
    
    private func xpRequired(for rank: Int) -> Int {
        120 + (max(1, rank) - 1) * 55
    }
    
    private func ensureMissionTierDefaults() {
        for kind in ProgressionMissionKind.allCases where missionTiers[kind.rawValue] == nil {
            missionTiers[kind.rawValue] = 1
        }
    }
    
    private func persist() {
        let defaults = UserDefaults.standard
        defaults.set(coins, forKey: StorageKey.coins)
        defaults.set(selectedLevel.rawValue, forKey: StorageKey.selectedLevel)
        defaults.set(pilotRank, forKey: StorageKey.pilotRank)
        defaults.set(pilotXP, forKey: StorageKey.pilotXP)
        defaults.set(missionTiers, forKey: StorageKey.missionTiers)
        defaults.set(ownedShips.map(\.rawValue), forKey: StorageKey.ownedShips)
        defaults.set(Array(unlockedSkinKeys), forKey: StorageKey.unlockedSkins)
        defaults.set(equippedShip.rawValue, forKey: StorageKey.equippedShip)
        defaults.set(equippedSkinRawValues, forKey: StorageKey.equippedSkins)
    }
    
    private func loadFromStorage() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: StorageKey.coins) != nil {
            coins = defaults.integer(forKey: StorageKey.coins)
        }

        if let storedLevel = GameLevel(rawValue: defaults.integer(forKey: StorageKey.selectedLevel)) {
            selectedLevel = storedLevel
        }
        
        if defaults.object(forKey: StorageKey.pilotRank) != nil {
            pilotRank = max(1, defaults.integer(forKey: StorageKey.pilotRank))
        }
        
        if defaults.object(forKey: StorageKey.pilotXP) != nil {
            pilotXP = max(0, defaults.integer(forKey: StorageKey.pilotXP))
        }
        
        if let storedMissionTiers = defaults.dictionary(forKey: StorageKey.missionTiers) {
            missionTiers = storedMissionTiers.reduce(into: [:]) { partialResult, element in
                if let value = element.value as? Int {
                    partialResult[element.key] = value
                } else if let value = element.value as? NSNumber {
                    partialResult[element.key] = value.intValue
                }
            }
        }
        ensureMissionTierDefaults()
        
        if let storedShips = defaults.array(forKey: StorageKey.ownedShips) as? [String] {
            let ships = Set(storedShips.compactMap(ShipID.init(rawValue:)))
            ownedShips = ships.isEmpty ? [.executioner] : ships.union([.executioner])
        }
        
        if let storedSkins = defaults.array(forKey: StorageKey.unlockedSkins) as? [String] {
            unlockedSkinKeys = Set(storedSkins)
        }
        unlockedSkinKeys.insert(Self.skinKey(ship: .executioner, skin: .blue))
        
        if let rawShip = defaults.string(forKey: StorageKey.equippedShip),
           let ship = ShipID(rawValue: rawShip),
           ownedShips.contains(ship) {
            equippedShip = ship
        }
        
        if let storedEquippedSkins = defaults.dictionary(forKey: StorageKey.equippedSkins) as? [String: String] {
            equippedSkinRawValues = storedEquippedSkins
        }
        if equippedSkinRawValues[ShipID.executioner.rawValue] == nil {
            equippedSkinRawValues[ShipID.executioner.rawValue] = ShipSkin.blue.rawValue
        }
    }
    
    private static func skinKey(ship: ShipID, skin: ShipSkin) -> String {
        "\(ship.rawValue):\(skin.rawValue)"
    }
}
