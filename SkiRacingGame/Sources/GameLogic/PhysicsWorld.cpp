#include "PhysicsWorld.hpp"
#include "MathUtils.hpp"
#include <algorithm>
#include <math.h>
#include <iostream>

namespace {
constexpr float kCollisionEffectDuration = 0.5f;
constexpr float kImpactShakeDuration = 0.22f;
constexpr float kCollisionSlowdownDuration = 0.45f;
constexpr float kCollisionCooldownDuration = 0.16f;
constexpr float kCollisionSlowdownMultiplier = 0.58f;
constexpr float kTerrainLeadDistance = 150.0f;
constexpr int kCollisionBaseDamage = 6;
constexpr int kCollisionBonusDamagePerExtraCell = 2;
constexpr int kMaxCollisionDamage = 12;
constexpr int kDebugLevel = 3;
constexpr float kRiverCurveScale = 0.92f;
constexpr float kRiverPrimaryFrequency = 0.0074f;
constexpr float kRiverSecondaryFrequency = 0.021f;
constexpr float kRiverBranchFrequency = 0.0046f;

static float smoothstepf(float edge0, float edge1, float x) {
    float t = (x - edge0) / (edge1 - edge0);
    t = fmaxf(0.0f, fminf(1.0f, t));
    return t * t * (3.0f - 2.0f * t);
}

static float clampf(float value, float minValue, float maxValue) {
    return fmaxf(minValue, fminf(maxValue, value));
}

static int worldToGridCoord(float worldValue) {
    return (int)floorf((worldValue + TerrainGrid::COLUMN_SPACING * 0.5f) / TerrainGrid::COLUMN_SPACING);
}

static float gridToWorldCoord(int gridValue) {
    return (float)gridValue * TerrainGrid::COLUMN_SPACING;
}

static float getDistFromRiverCPU(float gridX, float gridZ) {
    constexpr float kRiverPlayableHalfWidth = 100.0f;
    constexpr float kRiverTransitionWidth = 40.0f;
    constexpr float kRiverCenterLimit = kRiverPlayableHalfWidth - kRiverTransitionWidth;
    float dampening = smoothstepf(0.0f, 500.0f, fabsf(gridZ));
    float riverBaseX = (sinf(gridZ * kRiverPrimaryFrequency) * (31.0f * kRiverCurveScale) +
                        sinf(gridZ * kRiverSecondaryFrequency + 0.9f) * (16.0f * kRiverCurveScale)) * dampening;
    float splitFactor = (sinf(gridZ * kRiverBranchFrequency + 10.0f) * 0.72f) +
                        (sinf(gridZ * 0.0095f + 1.7f) * 0.28f);
    float branchOffset = smoothstepf(0.04f, 0.52f, splitFactor) * (21.0f * kRiverCurveScale);
    
    if (branchOffset > 2.0f) {
        float riverX1 = clampf(riverBaseX + branchOffset, -kRiverCenterLimit, kRiverCenterLimit);
        float riverX2 = clampf(riverBaseX - branchOffset, -kRiverCenterLimit, kRiverCenterLimit);
        return fminf(fabsf(gridX - riverX1), fabsf(gridX - riverX2));
    }
    return fabsf(gridX - clampf(riverBaseX, -kRiverCenterLimit, kRiverCenterLimit));
}

static uint16_t computeStaticFlagsForWorld(float worldX, float worldZ) {
    float distFromRiver = getDistFromRiverCPU(worldX, worldZ);
    uint16_t flags = 0;
    
    if (distFromRiver > 12.0f && distFromRiver < 22.0f) {
        float groupX = floorf(worldX / 15.0f) + 1000.0f;
        float groupZ = floorf(worldZ / 15.0f) + 1000.0f;
        float groupHash = MathUtils::hash(groupX * 0.73f + 1.3f, groupZ * 0.91f + 2.7f);
        if (groupHash < 0.30f) {
            flags |= static_cast<uint16_t>(CellFlags::Destructible);
        }
    }
    
    if (distFromRiver < 10.0f) {
        float bx = floorf(worldX / 5.0f) + 500.0f;
        float bz = floorf(worldZ / 5.0f) + 500.0f;
        float boostHash = MathUtils::hash(bx * 1.17f + 3.4f, bz * 0.83f + 7.1f);
        if (boostHash < 0.005f) {
            flags |= static_cast<uint16_t>(CellFlags::BoostPad);
        }
    }
    
    if (distFromRiver < 6.0f) {
        float ex = floorf(worldX / 5.0f) + 700.0f;
        float ez = floorf(worldZ / 5.0f) + 700.0f;
        float elevHash = MathUtils::hash(ex * 1.53f + 5.7f, ez * 1.21f + 9.3f);
        if (elevHash < 0.004f) {
            flags |= static_cast<uint16_t>(CellFlags::ElevationPad);
        }
        
        float fx = floorf(worldX / 5.0f) + 800.0f;
        float fz = floorf(worldZ / 5.0f) + 800.0f;
        float flatHash = MathUtils::hash(fx * 1.83f + 2.7f, fz * 1.41f + 6.3f);
        if (flatHash < 0.003f) {
            flags |= static_cast<uint16_t>(CellFlags::FlattenPad);
        }
    }
    
    return flags;
}
}

PhysicsWorld::PhysicsWorld() {
    gravity = simd_make_float3(0.0f, -9.81f, 0.0f);
}

void PhysicsWorld::updateEffectState(float deltaTime, int levelType) {
    for (auto it = collisionCells.begin(); it != collisionCells.end();) {
        it->timer = fmaxf(0.0f, it->timer - deltaTime);
        if (it->timer == 0.0f) {
            if (levelType != kDebugLevel) {
                bool alreadyDestroyed = false;
                for (const auto& cell : destroyedCells) {
                    if (cell.gridX == it->gridX && cell.gridZ == it->gridZ) {
                        alreadyDestroyed = true;
                        break;
                    }
                }
                if (!alreadyDestroyed) {
                    destroyedCells.push_back({it->gridX, it->gridZ});
                }
            }
            it = collisionCells.erase(it);
        } else {
            ++it;
        }
    }
}

void PhysicsWorld::syncVisibleGridState(Track& track, float renderOriginZ) {
    const float colSpacing = TerrainGrid::COLUMN_SPACING;
    const float visibleMinZ = renderOriginZ - TerrainGrid::LENGTH * colSpacing;
    
    destroyedCells.erase(
        std::remove_if(destroyedCells.begin(), destroyedCells.end(), [renderOriginZ, colSpacing](const DestroyedCellRecord& cell) {
            return gridToWorldCoord(cell.gridZ) > renderOriginZ + colSpacing;
        }),
        destroyedCells.end()
    );
    
    for (int row = 0; row < TerrainGrid::LENGTH; row++) {
        float worldZ = renderOriginZ - row * colSpacing;
        for (int col = 0; col < TerrainGrid::WIDTH; col++) {
            float worldX = (col - TerrainGrid::WIDTH / 2.0f) * colSpacing;
            GridCell& cell = track.grid.cells[row * TerrainGrid::WIDTH + col];
            cell.flags = 0;
            cell.baseHeight = MathUtils::getTerrainHeight(worldX, worldZ, track.slopeAngle);
            cell.collisionEffectTimer = 0.0f;
        }
    }
    
    for (const auto& cellRecord : destroyedCells) {
        float worldZ = gridToWorldCoord(cellRecord.gridZ);
        if (worldZ < visibleMinZ || worldZ > renderOriginZ) {
            continue;
        }
        int col = cellRecord.gridX + TerrainGrid::WIDTH / 2;
        int row = (int)lroundf((renderOriginZ - worldZ) / colSpacing);
        if (col >= 0 && col < TerrainGrid::WIDTH &&
            row >= 0 && row < TerrainGrid::LENGTH) {
            track.grid.cells[row * TerrainGrid::WIDTH + col].setFlag(CellFlags::Destroyed);
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
            GridCell& cell = track.grid.cells[row * TerrainGrid::WIDTH + col];
            cell.setFlag(CellFlags::Collided);
            cell.collisionEffectTimer = cellRecord.timer;
        }
    }
}

void PhysicsWorld::markDestroyedCell(float worldX, float worldZ) {
    int gridX = worldToGridCoord(worldX);
    int gridZ = worldToGridCoord(worldZ);
    
    for (const auto& cell : destroyedCells) {
        if (cell.gridX == gridX && cell.gridZ == gridZ) {
            return;
        }
    }
    
    destroyedCells.push_back({gridX, gridZ});
    collisionCells.erase(
        std::remove_if(collisionCells.begin(), collisionCells.end(), [gridX, gridZ](const CollisionCellRecord& cell) {
            return cell.gridX == gridX && cell.gridZ == gridZ;
        }),
        collisionCells.end()
    );
}

void PhysicsWorld::addOrRefreshCollisionCell(float worldX, float worldZ, float duration) {
    int gridX = worldToGridCoord(worldX);
    int gridZ = worldToGridCoord(worldZ);
    
    for (const auto& cell : destroyedCells) {
        if (cell.gridX == gridX && cell.gridZ == gridZ) {
            return;
        }
    }
    
    for (auto& cell : collisionCells) {
        if (cell.gridX == gridX && cell.gridZ == gridZ) {
            cell.timer = duration;
            return;
        }
    }
    
    collisionCells.push_back({gridX, gridZ, duration});
}

bool PhysicsWorld::isDestroyedAt(float worldX, float worldZ) const {
    int gridX = worldToGridCoord(worldX);
    int gridZ = worldToGridCoord(worldZ);
    
    for (const auto& cell : destroyedCells) {
        if (cell.gridX == gridX && cell.gridZ == gridZ) {
            return true;
        }
    }
    return false;
}

void PhysicsWorld::update(float deltaTime, Vehicle& vehicle, Track& track, float totalTime, int levelType) {
    float previousX = vehicle.position.x;
    float previousZ = vehicle.position.z;
    
    // ── Constants ─────────────────────────────────────────────────
    const float startSpeed = 66.0f;
    const float midRunSpeed = 126.0f;
    const float lateRunSpeed = 182.0f;
    float firstRamp = smoothstepf(0.0f, 55.0f, totalTime);
    float secondRamp = smoothstepf(60.0f, 165.0f, totalTime);
    float baseSpeed = startSpeed +
                      (midRunSpeed - startSpeed) * firstRamp +
                      (lateRunSpeed - midRunSpeed) * secondRamp;
    baseSpeed = fminf(baseSpeed, 220.0f);
    const float colSpacing = TerrainGrid::COLUMN_SPACING;
    auto snapToGrid = [colSpacing](float value) {
        return floorf((value + colSpacing * 0.5f) / colSpacing) * colSpacing;
    };
    
    updateEffectState(deltaTime, levelType);
    vehicle.impactShakeTimer = fmaxf(0.0f, vehicle.impactShakeTimer - deltaTime);
    vehicle.collisionSlowdownTimer = fmaxf(0.0f, vehicle.collisionSlowdownTimer - deltaTime);
    vehicle.terrainCollisionCooldownTimer = fmaxf(0.0f, vehicle.terrainCollisionCooldownTimer - deltaTime);
    
    if (vehicle.isDestroyed) {
        float frozenOriginZ = snapToGrid(vehicle.position.z) + kTerrainLeadDistance;
        track.grid.originZ = frozenOriginZ;
        syncVisibleGridState(track, frozenOriginZ);
        return;
    }
    
    // ── Boost Pad Timer Decay ────────────────────────────────────
    if (vehicle.boostTimer > 0.0f) {
        vehicle.boostTimer -= deltaTime;
        if (vehicle.boostTimer < 0.0f) vehicle.boostTimer = 0.0f;
    }
    
    // ── Elevation Timer Decay ─────────────────────────────────────
    if (vehicle.elevateTimer > 0.0f) {
        vehicle.elevateTimer -= deltaTime;
        if (vehicle.elevateTimer < 0.0f) vehicle.elevateTimer = 0.0f;
    }

    // ── Forward Speed (affected by boost) ────────────────────────
    float speedMult = (vehicle.boostTimer > 0.0f) ? vehicle.boostMultiplier : 1.0f;
    float slowdownMult = (vehicle.collisionSlowdownTimer > 0.0f) ? kCollisionSlowdownMultiplier : 1.0f;
    float currentSpeed = baseSpeed * speedMult * slowdownMult;
    vehicle.velocity.z = -currentSpeed;
    vehicle.position.z += vehicle.velocity.z * deltaTime;
    
    // Dynamic flight height: elevated when elevateTimer is active
    float flightHeight = (vehicle.elevateTimer > 0.0f) ? vehicle.elevateFlightHeight : 12.0f;
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
    
    // ── Flatten Wave Propagation ──────────────────────────────────
    if (vehicle.flattenWaveActive) {
        float waveSpeed = 800.0f;
        float oldWaveZ = vehicle.flattenWaveZ;
        vehicle.flattenWaveZ = fmaxf(vehicle.flattenWaveEndZ, vehicle.flattenWaveZ - waveSpeed * deltaTime);
        
        float snappedOldWaveZ = snapToGrid(oldWaveZ);
        float snappedNewWaveZ = snapToGrid(vehicle.flattenWaveZ);
        for (float cellZ = snappedOldWaveZ; cellZ > snappedNewWaveZ; cellZ -= colSpacing) {
            for (int col = 0; col < TerrainGrid::WIDTH; col++) {
                float cellX = (col - TerrainGrid::WIDTH / 2.0f) * colSpacing;
                if (fabsf(cellX - vehicle.flattenTargetX) < 1.1f * colSpacing) {
                    markDestroyedCell(cellX, cellZ);
                }
            }
        }
        
        if (vehicle.flattenWaveZ <= vehicle.flattenWaveEndZ + 0.001f) {
            vehicle.flattenWaveActive = false;
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
            if (isDestroyedAt(gridX, gridZ)) {
                continue;
            }
            
            float colHeight = MathUtils::getTerrainHeight(gridX, gridZ, track.slopeAngle);
            float cellMinX = gridX - colSpacing * 0.5f;
            float cellMaxX = gridX + colSpacing * 0.5f;
            float cellMinZ = gridZ - colSpacing * 0.5f;
            float cellMaxZ = gridZ + colSpacing * 0.5f;
            
            bool hitHull = (hullSweepMinX <= cellMaxX && hullSweepMaxX >= cellMinX &&
                            hullSweepMinZ <= cellMaxZ && hullSweepMaxZ >= cellMinZ);
            bool hitGraze = (grazeSweepMinX <= cellMaxX && grazeSweepMaxX >= cellMinX &&
                             grazeSweepMinZ <= cellMaxZ && grazeSweepMaxZ >= cellMinZ);
            
            uint16_t staticFlags = computeStaticFlagsForWorld(gridX, gridZ);
            bool isBoostPad = (staticFlags & static_cast<uint16_t>(CellFlags::BoostPad)) != 0;
            bool isElevationPad = (staticFlags & static_cast<uint16_t>(CellFlags::ElevationPad)) != 0;
            bool isFlattenPad = (staticFlags & static_cast<uint16_t>(CellFlags::FlattenPad)) != 0;
            
            if (isBoostPad && hitHull && colHeight < flightHeight - 2.0f) {
                vehicle.boostTimer = 2.0f;
            }
            
            if (isElevationPad && hitHull && colHeight < flightHeight - 2.0f) {
                vehicle.elevateTimer = 10.0f;
            }
            
            if (isFlattenPad && hitHull && colHeight < flightHeight - 2.0f) {
                vehicle.flattenWaveActive = true;
                vehicle.flattenWaveZ = vehicle.position.z;
                vehicle.flattenTargetX = snapToGrid(gridX);
                vehicle.flattenWaveEndZ = renderOriginZ - TerrainGrid::LENGTH * colSpacing;
            }
            
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
