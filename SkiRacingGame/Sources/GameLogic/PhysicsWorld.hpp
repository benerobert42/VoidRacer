#ifndef PhysicsWorld_hpp
#define PhysicsWorld_hpp

#include "Vehicle.hpp"
#include "Track.hpp"
#include <simd/simd.h>
#include <stdint.h>
#include <vector>

class PhysicsWorld {
public:
    simd_float3 gravity;
    
    PhysicsWorld();
    
    void update(float deltaTime, Vehicle& vehicle, Track& track, float totalTime, int levelType);
    bool checkObstacleCollision(Vehicle& vehicle, Obstacle& obstacle, int levelType);

private:
    struct CollisionCellRecord {
        int gridX;
        int gridZ;
        float timer;
    };

    struct BoostPadRecord {
        int centerGridX;
        int firstRowGridZ;
    };

    struct JumpPadRecord {
        int firstGridX;
        int firstRowGridZ;
    };

    struct FlattenCellRecord {
        int gridX;
        int gridZ;
        float timer;
    };

    struct GateRecord {
        int pattern;
        int centerGridX;
        int firstRowGridZ;
    };

    struct NearMissRecord {
        int gridX;
        int gridZ;
        float timer;
    };

    std::vector<CollisionCellRecord> collisionCells;
    std::vector<BoostPadRecord> boostPads;
    std::vector<JumpPadRecord> jumpPads;
    std::vector<FlattenCellRecord> flattenedCells;
    std::vector<GateRecord> gates;
    std::vector<NearMissRecord> nearMissCells;
    uint32_t boostRandomState;
    float nextBoostSpawnTime;
    float nextJumpPadSpawnTime;
    float nextSkillCollectibleSpawnTime;
    float nextGateSpawnTime;

    void updateEffectState(float deltaTime);
    void syncVisibleGridState(Track& track, float renderOriginZ);
    void addOrRefreshCollisionCell(float worldX, float worldZ, float duration);
    void scheduleBoostPads(Vehicle& vehicle, Track& track, float totalTime, float currentSpeed);
    void scheduleJumpPads(Vehicle& vehicle, Track& track, float totalTime, float currentSpeed);
    void scheduleSkillCollectibles(Vehicle& vehicle, Track& track, float totalTime, float currentSpeed);
    void scheduleGates(Vehicle& vehicle, Track& track, float totalTime, float currentSpeed);
    void collectJumpPads(Vehicle& vehicle, float previousX, float previousZ);
    void collectSkillCollectibles(Vehicle& vehicle, Track& track);
    void triggerFlattenCharge(const Vehicle& vehicle);
    void addComboEvent(Vehicle& vehicle, int baseScore, float comboTimeBonus);
    bool addNearMissCell(int gridX, int gridZ);
    bool isFlattenedCell(float worldX, float worldZ) const;
    bool getGateCell(float worldX, float worldZ) const;
    bool gatePatternBlocksCell(int pattern, int localCol, int localRow) const;
    bool findBoostPadPlacement(const Track& track, float targetWorldZ, BoostPadRecord& outPad) const;
    bool isBoostPadPlacementValid(const Track& track, int centerGridX, int firstRowGridZ) const;
    bool findJumpPadPlacement(const Track& track, float targetWorldZ, JumpPadRecord& outPad) const;
    bool isJumpPadPlacementValid(const Track& track, int firstGridX, int firstRowGridZ) const;
    bool getBoostPadCell(float worldX, float worldZ, bool& isDark) const;
    bool getJumpPadCell(float worldX, float worldZ, float& springPhase) const;
    bool getJumpPadCell(float worldX, float worldZ) const;
    float sampleNextBoostInterval();
};

#endif /* PhysicsWorld_hpp */
