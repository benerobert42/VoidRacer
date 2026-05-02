#include "PhysicsWorld.hpp"
#include "MathUtils.hpp"
#include <algorithm>
#include <math.h>

namespace {
constexpr float kImpactShakeDuration = 0.22f;
constexpr float kCollisionSlowdownDuration = 0.45f;
constexpr float kCollisionCooldownDuration = 0.16f;
constexpr float kCollisionSlowdownMultiplier = 0.58f;
constexpr float kCollisionEffectDuration = 0.5f;
constexpr float kTerrainLeadDistance = 150.0f;
constexpr float kFlightHeight = 6.0f;
constexpr float kSpeedDoublingIntervalSeconds = 180.0f;
constexpr int kCollisionBaseDamage = 6;
constexpr int kCollisionBonusDamagePerExtraCell = 2;
constexpr int kMaxCollisionDamage = 12;
constexpr int kDebugLevel = 3;

static int worldToGridCoord(float worldValue) {
    return (int)floorf((worldValue + TerrainGrid::COLUMN_SPACING * 0.5f) / TerrainGrid::COLUMN_SPACING);
}

static float gridToWorldCoord(int gridValue) {
    return (float)gridValue * TerrainGrid::COLUMN_SPACING;
}

}

PhysicsWorld::PhysicsWorld() {
    gravity = simd_make_float3(0.0f, -9.81f, 0.0f);
}

void PhysicsWorld::updateEffectState(float deltaTime) {
    for (auto it = collisionCells.begin(); it != collisionCells.end();) {
        it->timer = fmaxf(0.0f, it->timer - deltaTime);
        if (it->timer <= 0.0f) {
            it = collisionCells.erase(it);
        } else {
            ++it;
        }
    }
}

void PhysicsWorld::syncVisibleGridState(Track& track, float renderOriginZ) {
    const float colSpacing = TerrainGrid::COLUMN_SPACING;
    const float visibleMinZ = renderOriginZ - TerrainGrid::LENGTH * colSpacing;
    
    for (int row = 0; row < TerrainGrid::LENGTH; row++) {
        for (int col = 0; col < TerrainGrid::WIDTH; col++) {
            GridCell& cell = track.grid.cells[row * TerrainGrid::WIDTH + col];
            cell.flags = 0;
            cell.baseHeight = 0.0f;
            cell.collisionEffectTimer = 0.0f;
        }
    }

    for (const auto& cellRecord : collisionCells) {
        float worldZ = gridToWorldCoord(cellRecord.gridZ);
        if (worldZ < visibleMinZ || worldZ > renderOriginZ) {
            continue;
        }

        int col = cellRecord.gridX + TerrainGrid::WIDTH / 2;
        int row = (int)lroundf((renderOriginZ - worldZ) / colSpacing);
        if (col >= 0 && col < TerrainGrid::WIDTH &&
            row >= 0 && row < TerrainGrid::LENGTH) {
            track.grid.cells[row * TerrainGrid::WIDTH + col].collisionEffectTimer = cellRecord.timer;
        }
    }
}

void PhysicsWorld::addOrRefreshCollisionCell(float worldX, float worldZ, float duration) {
    int gridX = worldToGridCoord(worldX);
    int gridZ = worldToGridCoord(worldZ);

    for (auto& cell : collisionCells) {
        if (cell.gridX == gridX && cell.gridZ == gridZ) {
            cell.timer = fmaxf(cell.timer, duration);
            return;
        }
    }

    collisionCells.push_back({gridX, gridZ, duration});
}

void PhysicsWorld::update(float deltaTime, Vehicle& vehicle, Track& track, float totalTime, int levelType) {
    float previousX = vehicle.position.x;
    float previousZ = vehicle.position.z;
    
    // ── Constants ─────────────────────────────────────────────────
    const float startSpeed = 66.0f;
    float baseSpeed = startSpeed * powf(2.0f, totalTime / kSpeedDoublingIntervalSeconds);
    const float colSpacing = TerrainGrid::COLUMN_SPACING;
    auto snapToGrid = [colSpacing](float value) {
        return floorf((value + colSpacing * 0.5f) / colSpacing) * colSpacing;
    };
    
    updateEffectState(deltaTime);
    vehicle.impactShakeTimer = fmaxf(0.0f, vehicle.impactShakeTimer - deltaTime);
    vehicle.collisionSlowdownTimer = fmaxf(0.0f, vehicle.collisionSlowdownTimer - deltaTime);
    vehicle.terrainCollisionCooldownTimer = fmaxf(0.0f, vehicle.terrainCollisionCooldownTimer - deltaTime);
    
    if (vehicle.isDestroyed) {
        float frozenOriginZ = snapToGrid(vehicle.position.z) + kTerrainLeadDistance;
        track.grid.originZ = frozenOriginZ;
        syncVisibleGridState(track, frozenOriginZ);
        return;
    }
    
    // Power-up systems are disabled while the solid terrain baseline is stabilized.
    vehicle.boostTimer = 0.0f;
    vehicle.elevateTimer = 0.0f;
    vehicle.flattenWaveActive = false;

    // ── Forward Speed ────────────────────────────────────────────
    float speedMult = 1.0f;
    float slowdownMult = (vehicle.collisionSlowdownTimer > 0.0f) ? kCollisionSlowdownMultiplier : 1.0f;
    float currentSpeed = baseSpeed * speedMult * slowdownMult;
    vehicle.velocity.z = -currentSpeed;
    vehicle.position.z += vehicle.velocity.z * deltaTime;
    
    float flightHeight = kFlightHeight;
    vehicle.position.y = flightHeight;

    // ── Lateral Steering (Linear with proportional snap) ─────────
    float maxLateralDeviation = vehicle.visibleLateralLimit;
    float restCenterX = fmaxf(-maxLateralDeviation, fminf(maxLateralDeviation, vehicle.steeringRestCenterX));
    vehicle.steeringRestCenterX = restCenterX;
    bool hasSteeringInput = fabsf(vehicle.steeringAmount) > 0.001f;
    float targetX = hasSteeringInput ? (vehicle.steeringAmount * maxLateralDeviation) : restCenterX;
    float deltaX = targetX - vehicle.position.x;
    
    float minSpeed = hasSteeringInput ? 150.0f : 75.0f;
    float propFactor = hasSteeringInput ? 5.0f : 2.5f;
    float moveSpeed = (fabsf(deltaX) * propFactor) + minSpeed;
    float moveStep = moveSpeed * deltaTime;

    if (fabsf(deltaX) <= moveStep) {
        vehicle.position.x = targetX;
    } else {
        vehicle.position.x += (deltaX > 0.0f) ? moveStep : -moveStep;
    }
    vehicle.velocity.x = deltaX;

    float renderOriginZ = snapToGrid(vehicle.position.z) + kTerrainLeadDistance;
    track.grid.originZ = renderOriginZ;

    // ── Chaser (Wall of Energy) ──────────────────────────────────
    vehicle.chaserBaseSpeed = baseSpeed;
    vehicle.chaserZ -= vehicle.chaserBaseSpeed * deltaTime;
    
    if (vehicle.position.z > vehicle.chaserZ) {
        if (levelType != kDebugLevel) {
            vehicle.health = 0;
            vehicle.isDestroyed = true;
            vehicle.velocity.z = 0.0f;
            syncVisibleGridState(track, renderOriginZ);
            return;
        }
    }
    
    // ── Graze & Hull Collision (Swept AABB Grid Check) ───────────
    float vx = vehicle.position.x;
    float vz = vehicle.position.z;
    
    float hullSweepMinX = fminf(previousX, vx) - vehicle.hullRadius;
    float hullSweepMaxX = fmaxf(previousX, vx) + vehicle.hullRadius;
    float hullSweepMinZ = fminf(previousZ, vz) - vehicle.hullRadius;
    float hullSweepMaxZ = fmaxf(previousZ, vz) + vehicle.hullRadius;

    float grazeSweepMinX = fminf(previousX, vx) - vehicle.grazeRadius;
    float grazeSweepMaxX = fmaxf(previousX, vx) + vehicle.grazeRadius;
    float grazeSweepMinZ = fminf(previousZ, vz) - vehicle.grazeRadius;
    float grazeSweepMaxZ = fmaxf(previousZ, vz) + vehicle.grazeRadius;
    
    bool grazedThisFrame = false;
    int terrainCollisionCellCount = 0;
    
    float minGridX = snapToGrid(grazeSweepMinX - colSpacing);
    float maxGridX = snapToGrid(grazeSweepMaxX + colSpacing);
    float minGridZ = snapToGrid(grazeSweepMinZ - colSpacing);
    float maxGridZ = snapToGrid(grazeSweepMaxZ + colSpacing);

    for (float gridZ = minGridZ; gridZ <= maxGridZ; gridZ += colSpacing) {
        for (float gridX = minGridX; gridX <= maxGridX; gridX += colSpacing) {
            float colHeight = MathUtils::getTerrainHeight(gridX, gridZ, track.slopeAngle);
            float cellMinX = gridX - colSpacing * 0.5f;
            float cellMaxX = gridX + colSpacing * 0.5f;
            float cellMinZ = gridZ - colSpacing * 0.5f;
            float cellMaxZ = gridZ + colSpacing * 0.5f;
            
            bool hitHull = (hullSweepMinX <= cellMaxX && hullSweepMaxX >= cellMinX &&
                            hullSweepMinZ <= cellMaxZ && hullSweepMaxZ >= cellMinZ);
            bool hitGraze = (grazeSweepMinX <= cellMaxX && grazeSweepMaxX >= cellMinX &&
                             grazeSweepMinZ <= cellMaxZ && grazeSweepMaxZ >= cellMinZ);
            
            if (colHeight <= flightHeight - 5.0f) continue;
            
            if (hitHull && colHeight > flightHeight - 1.0f) {
                addOrRefreshCollisionCell(gridX, gridZ, kCollisionEffectDuration);
                if (levelType != kDebugLevel) {
                    terrainCollisionCellCount += 1;
                }
            }
            
            if (hitGraze && !hitHull && colHeight > flightHeight - 6.5f) {
                grazedThisFrame = true;
            }
        }
    }

    syncVisibleGridState(track, renderOriginZ);

    if (terrainCollisionCellCount > 0 && levelType != kDebugLevel && vehicle.terrainCollisionCooldownTimer <= 0.0f) {
        int damage = kCollisionBaseDamage + ((terrainCollisionCellCount - 1) * kCollisionBonusDamagePerExtraCell);
        damage = std::min(kMaxCollisionDamage, damage);
        vehicle.health = std::max(0, vehicle.health - damage);
        vehicle.impactShakeTimer = kImpactShakeDuration;
        vehicle.collisionSlowdownTimer = kCollisionSlowdownDuration;
        vehicle.terrainCollisionCooldownTimer = kCollisionCooldownDuration;
        vehicle.scoreMultiplier = fmaxf(1.0f, vehicle.scoreMultiplier - 0.35f);
        vehicle.overdriveCharge = fmaxf(0.0f, vehicle.overdriveCharge - 0.12f);
        
        if (vehicle.health <= 0) {
            vehicle.isDestroyed = true;
            vehicle.velocity.z = 0.0f;
            return;
        }
    }

    // ── Graze Overdrive Accumulation ─────────────────────────────
    if (grazedThisFrame) {
        vehicle.isGrazing = true;
        vehicle.overdriveCharge = fminf(1.0f, vehicle.overdriveCharge + deltaTime * 0.3f);
        vehicle.scoreMultiplier = fminf(8.0f, vehicle.scoreMultiplier + deltaTime * 0.5f);
    } else {
        vehicle.isGrazing = false;
        vehicle.scoreMultiplier = fmaxf(1.0f, vehicle.scoreMultiplier - deltaTime * 0.2f);
    }

    vehicle.score += (int)(deltaTime * 100.0f * vehicle.scoreMultiplier);
    float coinRate = 2.2f + (vehicle.scoreMultiplier * 0.9f) + (grazedThisFrame ? 1.8f : 0.0f);
    vehicle.coinAccumulator += deltaTime * coinRate;
    while (vehicle.coinAccumulator >= 1.0f) {
        vehicle.coins += 1;
        vehicle.coinAccumulator -= 1.0f;
    }
}

bool PhysicsWorld::checkObstacleCollision(Vehicle& vehicle, Obstacle& obstacle, int levelType) {
    if (obstacle.hasCollided || vehicle.isDestroyed) return false;
    
    float dx = vehicle.position.x - obstacle.position.x;
    float dz = vehicle.position.z - obstacle.position.z;
    float distSq = dx*dx + dz*dz;
    
    float collisionRadiusSq = obstacle.radius * obstacle.radius;
    
    if (distSq < collisionRadiusSq) {
        obstacle.hasCollided = true;
        
        if (levelType != 3) {
            vehicle.health -= 20;
            vehicle.impactShakeTimer = kImpactShakeDuration;
            if (vehicle.health <= 0) {
                vehicle.health = 0;
                vehicle.isDestroyed = true;
            }
            vehicle.velocity.z *= 0.3f;
        }
        
        return true;
    }
    return false;
}
