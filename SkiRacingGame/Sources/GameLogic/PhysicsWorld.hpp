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

    std::vector<CollisionCellRecord> collisionCells;
    std::vector<BoostPadRecord> boostPads;
    uint32_t boostRandomState;
    float nextBoostSpawnTime;

    void updateEffectState(float deltaTime);
    void syncVisibleGridState(Track& track, float renderOriginZ);
    void addOrRefreshCollisionCell(float worldX, float worldZ, float duration);
    void scheduleBoostPads(Vehicle& vehicle, Track& track, float totalTime, float currentSpeed);
    bool findBoostPadPlacement(float targetWorldZ, float slopeAngle, BoostPadRecord& outPad) const;
    bool isBoostPadPlacementValid(int centerGridX, int firstRowGridZ, float slopeAngle) const;
    bool getBoostPadCell(float worldX, float worldZ, bool& isDark) const;
    float sampleNextBoostInterval();
};

#endif /* PhysicsWorld_hpp */
