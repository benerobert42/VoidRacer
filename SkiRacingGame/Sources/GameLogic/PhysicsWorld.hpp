#ifndef PhysicsWorld_hpp
#define PhysicsWorld_hpp

#include "Vehicle.hpp"
#include "Track.hpp"
#include <simd/simd.h>
#include <vector>

struct DestroyedCellRecord {
    int gridX;
    int gridZ;
};

struct CollisionCellRecord {
    int gridX;
    int gridZ;
    float timer;
};

class PhysicsWorld {
public:
    simd_float3 gravity;
    
    PhysicsWorld();
    
    void update(float deltaTime, Vehicle& vehicle, Track& track, float totalTime, int levelType);
    bool checkObstacleCollision(Vehicle& vehicle, Obstacle& obstacle, int levelType);

private:
    std::vector<DestroyedCellRecord> destroyedCells;
    std::vector<CollisionCellRecord> collisionCells;

    void updateEffectState(float deltaTime, int levelType);
    void syncVisibleGridState(Track& track, float renderOriginZ);
    void markDestroyedCell(float worldX, float worldZ);
    void addOrRefreshCollisionCell(float worldX, float worldZ, float duration);
    bool isDestroyedAt(float worldX, float worldZ) const;
};

#endif /* PhysicsWorld_hpp */
