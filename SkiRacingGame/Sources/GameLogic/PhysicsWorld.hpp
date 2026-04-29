#ifndef PhysicsWorld_hpp
#define PhysicsWorld_hpp

#include "Vehicle.hpp"
#include "Track.hpp"
#include <simd/simd.h>
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

    std::vector<CollisionCellRecord> collisionCells;

    void updateEffectState(float deltaTime);
    void syncVisibleGridState(Track& track, float renderOriginZ);
    void addOrRefreshCollisionCell(float worldX, float worldZ, float duration);
};

#endif /* PhysicsWorld_hpp */
