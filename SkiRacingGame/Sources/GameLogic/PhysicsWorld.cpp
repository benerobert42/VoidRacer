#include "PhysicsWorld.hpp"
#include "MathUtils.hpp"
#include <algorithm>
#include <cmath>
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
constexpr float kBoostDuration = 3.0f;
constexpr float kBoostIntervalMeanSeconds = 30.0f;
constexpr float kBoostIntervalStdDevSeconds = 10.0f;
constexpr float kBoostPadSpawnLeadTime = 1.55f;
constexpr float kFirstBoostSpawnTime = 4.0f;
constexpr float kSkillCollectibleIntervalSeconds = 16.0f;
constexpr float kSkillCollectibleLeadTime = 1.55f;
constexpr float kFirstSkillCollectibleSpawnTime = 6.0f;
constexpr float kSkillCollectibleRadius = 5.2f;
constexpr float kFlattenDurationSeconds = 3.0f;
constexpr int kCollisionBaseDamage = 6;
constexpr int kCollisionBonusDamagePerExtraCell = 2;
constexpr int kMaxCollisionDamage = 12;
constexpr int kDebugLevel = 3;
constexpr int kBoostPadRows = 5;
constexpr int kBoostPadCols = 3;
constexpr int kFlattenRows = 40;
constexpr int kFlattenHalfCols = 2;

static int worldToGridCoord(float worldValue) {
    return (int)floorf((worldValue + TerrainGrid::COLUMN_SPACING * 0.5f) / TerrainGrid::COLUMN_SPACING);
}

static float gridToWorldCoord(int gridValue) {
    return (float)gridValue * TerrainGrid::COLUMN_SPACING;
}

static bool boostPadPatternIsDark(int row, int col) {
    constexpr bool pattern[kBoostPadRows][kBoostPadCols] = {
        { true,  false, true  },
        { false, true,  false },
        { false, false, false },
        { true,  false, true  },
        { false, true,  false }
    };
    return pattern[row][col];
}

static float nextBoostRandom01(uint32_t& state) {
    state ^= state << 13;
    state ^= state >> 17;
    state ^= state << 5;
    return ((state & 0x00FFFFFFu) + 1.0f) / 16777217.0f;
}

}

PhysicsWorld::PhysicsWorld() {
    gravity = simd_make_float3(0.0f, -9.81f, 0.0f);
    boostRandomState = 0xA341316Cu;
    nextBoostSpawnTime = kFirstBoostSpawnTime;
    nextSkillCollectibleSpawnTime = kFirstSkillCollectibleSpawnTime;
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

    for (auto it = flattenedCells.begin(); it != flattenedCells.end();) {
        it->timer = fmaxf(0.0f, it->timer - deltaTime);
        if (it->timer <= 0.0f) {
            it = flattenedCells.erase(it);
        } else {
            ++it;
        }
    }
}

void PhysicsWorld::syncVisibleGridState(Track& track, float renderOriginZ) {
    const float colSpacing = TerrainGrid::COLUMN_SPACING;
    const float visibleMinZ = renderOriginZ - TerrainGrid::LENGTH * colSpacing;

    for (auto it = flattenedCells.begin(); it != flattenedCells.end();) {
        float worldZ = gridToWorldCoord(it->gridZ);
        if (worldZ < visibleMinZ - colSpacing || worldZ > renderOriginZ + colSpacing * 2.0f) {
            it = flattenedCells.erase(it);
        } else {
            ++it;
        }
    }
    
    for (int row = 0; row < TerrainGrid::LENGTH; row++) {
        for (int col = 0; col < TerrainGrid::WIDTH; col++) {
            GridCell& cell = track.grid.cells[row * TerrainGrid::WIDTH + col];
            cell.flags = 0;
            cell.baseHeight = 0.0f;
            cell.collisionEffectTimer = 0.0f;

            float worldX = ((float)col - (TerrainGrid::WIDTH / 2)) * TerrainGrid::COLUMN_SPACING;
            float worldZ = renderOriginZ - ((float)row * TerrainGrid::COLUMN_SPACING);
            bool boostPadDark = false;
            if (getBoostPadCell(worldX, worldZ, boostPadDark)) {
                cell.setFlag(CellFlags::BoostPad);
                if (boostPadDark) {
                    cell.setFlag(CellFlags::BoostPadDark);
                }
            }
            if (isFlattenedCell(worldX, worldZ)) {
                cell.setFlag(CellFlags::FlattenPad);
            }
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

bool PhysicsWorld::getBoostPadCell(float worldX, float worldZ, bool& isDark) const {
    int gridX = worldToGridCoord(worldX);
    int gridZ = worldToGridCoord(worldZ);

    for (const auto& pad : boostPads) {
        int padRow = pad.firstRowGridZ - gridZ;
        if (padRow < 0 || padRow >= kBoostPadRows) {
            continue;
        }

        int localCol = gridX - pad.centerGridX + (kBoostPadCols / 2);
        if (localCol < 0 || localCol >= kBoostPadCols) {
            continue;
        }

        isDark = boostPadPatternIsDark(padRow, localCol);
        return true;
    }

    return false;
}

bool PhysicsWorld::isBoostPadPlacementValid(int centerGridX, int firstRowGridZ, float slopeAngle) const {
    for (int row = 0; row < kBoostPadRows; row++) {
        int gridZ = firstRowGridZ - row;
        for (int col = 0; col < kBoostPadCols; col++) {
            int gridX = centerGridX + col - (kBoostPadCols / 2);
            float worldX = gridToWorldCoord(gridX);
            float worldZ = gridToWorldCoord(gridZ);
            float height = MathUtils::getTerrainHeight(worldX, worldZ, slopeAngle);
            if (height > kFlightHeight - 5.0f) {
                return false;
            }
        }
    }
    return true;
}

bool PhysicsWorld::findBoostPadPlacement(float targetWorldZ, float slopeAngle, BoostPadRecord& outPad) const {
    int targetGridZ = worldToGridCoord(targetWorldZ);
    for (int offset = 0; offset < 36; offset++) {
        int signedOffset = (offset % 2 == 0) ? -(offset / 2) : ((offset + 1) / 2);
        int firstRowGridZ = targetGridZ + signedOffset;
        int middleRowGridZ = firstRowGridZ - (kBoostPadRows / 2);
        int centerGridX = worldToGridCoord(MathUtils::getRiverCenterX(gridToWorldCoord(middleRowGridZ)));
        if (isBoostPadPlacementValid(centerGridX, firstRowGridZ, slopeAngle)) {
            outPad = { centerGridX, firstRowGridZ };
            return true;
        }
    }
    return false;
}

float PhysicsWorld::sampleNextBoostInterval() {
    float u1 = fmaxf(nextBoostRandom01(boostRandomState), 0.0001f);
    float u2 = nextBoostRandom01(boostRandomState);
    float normal = sqrtf(-2.0f * logf(u1)) * cosf(2.0f * (float)M_PI * u2);
    return fminf(fmaxf(kBoostIntervalMeanSeconds + normal * kBoostIntervalStdDevSeconds, 12.0f), 55.0f);
}

void PhysicsWorld::scheduleBoostPads(Vehicle& vehicle, Track& track, float totalTime, float currentSpeed) {
    int spawned = 0;
    while (totalTime >= nextBoostSpawnTime && spawned < 3) {
        BoostPadRecord pad;
        float targetWorldZ = vehicle.position.z - currentSpeed * kBoostPadSpawnLeadTime;
        if (findBoostPadPlacement(targetWorldZ, track.slopeAngle, pad)) {
            bool duplicate = false;
            for (const auto& existing : boostPads) {
                if (abs(existing.firstRowGridZ - pad.firstRowGridZ) < 8) {
                    duplicate = true;
                    break;
                }
            }
            if (!duplicate) {
                boostPads.push_back(pad);
            }
        }

        nextBoostSpawnTime += sampleNextBoostInterval();
        spawned++;
    }
}

void PhysicsWorld::scheduleSkillCollectibles(Vehicle& vehicle, Track& track, float totalTime, float currentSpeed) {
    while (totalTime >= nextSkillCollectibleSpawnTime) {
        float targetWorldZ = vehicle.position.z - currentSpeed * kSkillCollectibleLeadTime;
        int targetGridZ = worldToGridCoord(targetWorldZ);
        float snappedWorldZ = gridToWorldCoord(targetGridZ);
        float centerX = MathUtils::getRiverCenterX(snappedWorldZ);
        track.skillCollectibles.push_back({
            simd_make_float3(centerX, kFlightHeight + 0.9f, snappedWorldZ),
            kSkillCollectibleRadius,
            false
        });
        nextSkillCollectibleSpawnTime += kSkillCollectibleIntervalSeconds;
    }

    for (auto it = track.skillCollectibles.begin(); it != track.skillCollectibles.end();) {
        if (it->collected || it->position.z > vehicle.position.z + 35.0f) {
            it = track.skillCollectibles.erase(it);
        } else {
            ++it;
        }
    }
}

void PhysicsWorld::collectSkillCollectibles(Vehicle& vehicle, Track& track) {
    for (auto& collectible : track.skillCollectibles) {
        if (collectible.collected) {
            continue;
        }

        // Pickup collision is based on stable X/Z placement, so the visual bob phase cannot cause misses.
        float dx = vehicle.position.x - collectible.position.x;
        float dz = vehicle.position.z - collectible.position.z;
        float radius = collectible.radius + vehicle.hullRadius;
        if ((dx * dx + dz * dz) <= radius * radius) {
            collectible.collected = true;
            vehicle.impactShakeTimer = fmaxf(vehicle.impactShakeTimer, 0.12f);
            triggerFlattenCharge(vehicle);
        }
    }
}

void PhysicsWorld::triggerFlattenCharge(const Vehicle& vehicle) {
    int centerGridX = worldToGridCoord(vehicle.position.x);
    int startGridZ = worldToGridCoord(vehicle.position.z - 8.0f);

    for (int row = 0; row < kFlattenRows; row++) {
        int gridZ = startGridZ - row;
        for (int col = -kFlattenHalfCols; col <= kFlattenHalfCols; col++) {
            int gridX = centerGridX + col;
            bool exists = false;
            for (auto& flattened : flattenedCells) {
                if (flattened.gridX == gridX && flattened.gridZ == gridZ) {
                    flattened.timer = kFlattenDurationSeconds;
                    exists = true;
                    break;
                }
            }
            if (!exists) {
                flattenedCells.push_back({gridX, gridZ, kFlattenDurationSeconds});
            }
        }
    }
}

bool PhysicsWorld::isFlattenedCell(float worldX, float worldZ) const {
    int gridX = worldToGridCoord(worldX);
    int gridZ = worldToGridCoord(worldZ);
    for (const auto& flattened : flattenedCells) {
        if (flattened.gridX == gridX && flattened.gridZ == gridZ) {
            return true;
        }
    }
    return false;
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
    const float startSpeed = 99.0f;
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
    
    vehicle.boostTimer = fmaxf(0.0f, vehicle.boostTimer - deltaTime);
    vehicle.boostMultiplier = vehicle.boostTimer > 0.0f ? 2.0f : 1.0f;
    vehicle.elevateTimer = 0.0f;
    vehicle.flattenWaveActive = false;

    // ── Forward Speed ────────────────────────────────────────────
    float speedMult = vehicle.boostMultiplier;
    float slowdownMult = (vehicle.collisionSlowdownTimer > 0.0f) ? kCollisionSlowdownMultiplier : 1.0f;
    float currentSpeed = baseSpeed * speedMult * slowdownMult;
    vehicle.velocity.z = -currentSpeed;
    vehicle.position.z += vehicle.velocity.z * deltaTime;
    scheduleBoostPads(vehicle, track, totalTime, currentSpeed);
    scheduleSkillCollectibles(vehicle, track, totalTime, currentSpeed);
    
    float flightHeight = kFlightHeight;
    vehicle.position.y = flightHeight;

    bool boostPadDark = false;
    if (getBoostPadCell(vehicle.position.x, vehicle.position.z, boostPadDark)) {
        vehicle.boostTimer = kBoostDuration;
        vehicle.boostMultiplier = 2.0f;
        vehicle.collisionSlowdownTimer = 0.0f;
    }

    float renderOriginZ = snapToGrid(vehicle.position.z) + kTerrainLeadDistance;

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
    collectSkillCollectibles(vehicle, track);

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
            if (isFlattenedCell(gridX, gridZ)) {
                colHeight = flightHeight - 8.0f;
            }
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

    if (terrainCollisionCellCount > 0 && levelType != kDebugLevel && vehicle.boostTimer <= 0.0f && vehicle.terrainCollisionCooldownTimer <= 0.0f) {
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
