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
constexpr float kFlightHeight = 4.2f;
constexpr float kStartSpeed = 118.8f;
constexpr float kSpeedDoublingIntervalSeconds = 150.0f;
constexpr float kBoostDuration = 3.0f;
constexpr float kBoostIntervalMeanSeconds = 30.0f;
constexpr float kBoostIntervalStdDevSeconds = 10.0f;
constexpr float kBoostPadSpawnLeadTime = 1.55f;
constexpr float kFirstBoostSpawnTime = 4.0f;
constexpr float kJumpPadIntervalSeconds = 24.0f;
constexpr float kJumpPadSpawnLeadTime = 1.65f;
constexpr float kFirstJumpPadSpawnTime = 10.0f;
constexpr float kJumpRiseDuration = 0.5f;
constexpr float kJumpCruiseDuration = 2.0f;
constexpr float kJumpFallDuration = 0.5f;
constexpr float kJumpCruiseSpeedMultiplier = 1.5f;
constexpr float kJumpTargetHeightMultiplier = 4.0f;
constexpr float kJumpPadTriggerMargin = 18.0f;
constexpr float kApproxRiverbedFlightReferenceY = -17.0f;
constexpr float kSkillCollectibleIntervalSeconds = 16.0f;
constexpr float kSkillCollectibleLeadTime = 1.55f;
constexpr float kFirstSkillCollectibleSpawnTime = 6.0f;
constexpr float kSkillCollectibleRadius = 5.2f;
constexpr float kFlattenDurationSeconds = 3.0f;
constexpr float kComboBaseDuration = 3.0f;
constexpr float kCleanSurvivalComboInterval = 4.0f;
constexpr float kGateIntervalSeconds = 11.5f;
constexpr float kGateSpawnLeadTime = 1.95f;
constexpr float kFirstGateSpawnTime = 8.0f;
constexpr float kNearMissMemorySeconds = 1.1f;
constexpr float kPulseObstacleIntervalSeconds = 17.0f;
constexpr float kPulseObstacleSpawnLeadTime = 2.15f;
constexpr float kFirstPulseObstacleSpawnTime = 12.0f;
constexpr float kPulseObstacleLifetimeSeconds = 2.45f;
constexpr float kPulseObstacleActiveStart = 0.48f;
constexpr float kPulseObstacleActiveEnd = 0.88f;
constexpr float kRouteForkIntervalSeconds = 25.0f;
constexpr float kRouteForkSpawnLeadTime = 2.25f;
constexpr float kFirstRouteForkSpawnTime = 14.0f;
constexpr float kRouteForkLength = 270.0f;
constexpr float kRouteForkOffset = 60.0f;
constexpr float kRouteOrbRadius = 8.0f;
constexpr int kRouteOrbScore = 420;
constexpr int kCollisionBaseDamage = 6;
constexpr int kCollisionBonusDamagePerExtraCell = 2;
constexpr int kMaxCollisionDamage = 12;
constexpr int kDebugLevel = 3;
constexpr int kBoostPadRows = 5;
constexpr int kBoostPadCols = 3;
constexpr int kJumpPadRows = 2;
constexpr int kJumpPadCols = 2;
constexpr int kFlattenRows = 40;
constexpr int kFlattenHalfCols = 2;
constexpr int kGateRows = 9;
constexpr int kGateHalfCols = 6;
constexpr int kPulseObstacleRows = 1;
constexpr int kPulseObstacleHalfCols = 1;

static int worldToGridCoord(float worldValue) {
    return (int)floorf((worldValue + TerrainGrid::COLUMN_SPACING * 0.5f) / TerrainGrid::COLUMN_SPACING);
}

static float gridToWorldCoord(int gridValue) {
    return (float)gridValue * TerrainGrid::COLUMN_SPACING;
}

static float terrainHeightForTrack(const Track& track, float worldX, float worldZ) {
    return MathUtils::getTerrainHeight(worldX,
                                       worldZ,
                                       track.slopeAngle,
                                       track.riverPrimaryPhase,
                                       track.riverSecondaryPhase,
                                       track.riverFrequencyScale,
                                       track.riverCurveScale,
                                       track.forkStartZ,
                                       track.forkEndZ,
                                       track.forkOffsetX,
                                       track.forkActive);
}

static float forkEnvelopeForTrack(const Track& track, float worldZ) {
    return MathUtils::forkEnvelope(worldZ, track.forkStartZ, track.forkEndZ, track.forkActive);
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
    nextJumpPadSpawnTime = kFirstJumpPadSpawnTime;
    nextSkillCollectibleSpawnTime = kFirstSkillCollectibleSpawnTime;
    nextGateSpawnTime = kFirstGateSpawnTime;
    nextPulseObstacleSpawnTime = kFirstPulseObstacleSpawnTime;
    nextRouteForkSpawnTime = kFirstRouteForkSpawnTime;
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

    for (auto it = nearMissCells.begin(); it != nearMissCells.end();) {
        it->timer = fmaxf(0.0f, it->timer - deltaTime);
        if (it->timer <= 0.0f) {
            it = nearMissCells.erase(it);
        } else {
            ++it;
        }
    }

    for (auto it = pulseObstacles.begin(); it != pulseObstacles.end();) {
        it->timer = fmaxf(0.0f, it->timer - deltaTime);
        if (it->timer <= 0.0f) {
            it = pulseObstacles.erase(it);
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
            if (getGateCell(worldX, worldZ)) {
                cell.setFlag(CellFlags::GateBlock);
            }
            float pulsePhase = 0.0f;
            if (getPulseObstacleCell(worldX, worldZ, pulsePhase)) {
                cell.setFlag(CellFlags::PulseObstacle);
                cell.baseHeight = pulsePhase;
            }
            float springPhase = 0.0f;
            if (getJumpPadCell(worldX, worldZ, springPhase)) {
                cell.setFlag(CellFlags::ElevationPad);
                cell.baseHeight = springPhase;
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

    for (const auto& nearMiss : nearMissCells) {
        float worldZ = gridToWorldCoord(nearMiss.gridZ);
        if (worldZ < visibleMinZ || worldZ > renderOriginZ) {
            continue;
        }

        int col = nearMiss.gridX + TerrainGrid::WIDTH / 2;
        int row = (int)lroundf((renderOriginZ - worldZ) / colSpacing);
        if (col >= 0 && col < TerrainGrid::WIDTH &&
            row >= 0 && row < TerrainGrid::LENGTH) {
            GridCell& cell = track.grid.cells[row * TerrainGrid::WIDTH + col];
            cell.setFlag(CellFlags::NearMissSpark);
            if (!cell.hasFlag(CellFlags::PulseObstacle) && !cell.hasFlag(CellFlags::ElevationPad)) {
                cell.baseHeight = fmaxf(cell.baseHeight, nearMiss.timer / kNearMissMemorySeconds);
            }
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

bool PhysicsWorld::getJumpPadCell(float worldX, float worldZ, float& springPhase) const {
    int gridX = worldToGridCoord(worldX);
    int gridZ = worldToGridCoord(worldZ);

    for (const auto& pad : jumpPads) {
        int localCol = gridX - pad.firstGridX;
        if (localCol < 0 || localCol >= kJumpPadCols) {
            continue;
        }

        int padRow = pad.firstRowGridZ - gridZ;
        if (padRow < 0 || padRow >= kJumpPadRows) {
            continue;
        }

        springPhase = (float)((pad.firstGridX * 17 + pad.firstRowGridZ * 31) & 1023) * 0.017f;
        return true;
    }

    return false;
}

bool PhysicsWorld::getJumpPadCell(float worldX, float worldZ) const {
    float unusedPhase = 0.0f;
    return getJumpPadCell(worldX, worldZ, unusedPhase);
}

bool PhysicsWorld::getPulseObstacleCell(float worldX, float worldZ, float& phase) const {
    int gridX = worldToGridCoord(worldX);
    int gridZ = worldToGridCoord(worldZ);

    for (const auto& pulse : pulseObstacles) {
        int localRow = pulse.firstRowGridZ - gridZ;
        if (localRow < 0 || localRow >= kPulseObstacleRows) {
            continue;
        }

        int localCol = gridX - pulse.centerGridX;
        if (localCol < -kPulseObstacleHalfCols || localCol > kPulseObstacleHalfCols) {
            continue;
        }

        phase = 1.0f - (pulse.timer / kPulseObstacleLifetimeSeconds);
        phase = fmaxf(0.0f, fminf(1.0f, phase));
        return true;
    }

    return false;
}

bool PhysicsWorld::getPulseObstacleCell(float worldX, float worldZ) const {
    float unusedPhase = 0.0f;
    return getPulseObstacleCell(worldX, worldZ, unusedPhase);
}

bool PhysicsWorld::gatePatternBlocksCell(int pattern, int localCol, int localRow) const {
    switch (pattern % 5) {
        case 0:
            // Center slit: classic endless-runner gate with a narrow center opening.
            return localRow == 4 && abs(localCol) > 1;
        case 1:
            // Offset slit: same read as center slit, shifted to force commitment.
            return localRow == 4 && !(localCol >= 2 && localCol <= 4);
        case 2:
            // Slalom: alternating half walls, separated in depth and not overlapping in X.
            if (localRow == 1) return localCol <= -2;
            if (localRow == 6) return localCol >= 2;
            return false;
        case 3:
            // Double split: two lanes, blocked middle, readable choice.
            return localRow == 4 && abs(localCol) <= 1;
        default:
            // Skill wall: obstacle cluster in the safest center path; jump/flatten helps,
            // but side escapes remain possible.
            return localRow >= 3 && localRow <= 5 && abs(localCol) <= 2;
    }
}

bool PhysicsWorld::getGateCell(float worldX, float worldZ) const {
    int gridX = worldToGridCoord(worldX);
    int gridZ = worldToGridCoord(worldZ);

    for (const auto& gate : gates) {
        int localRow = gate.firstRowGridZ - gridZ;
        if (localRow < 0 || localRow >= kGateRows) {
            continue;
        }

        int localCol = gridX - gate.centerGridX;
        if (localCol < -kGateHalfCols || localCol > kGateHalfCols) {
            continue;
        }

        if (gatePatternBlocksCell(gate.pattern, localCol, localRow)) {
            return true;
        }
    }

    return false;
}

bool PhysicsWorld::isBoostPadPlacementValid(const Track& track, int centerGridX, int firstRowGridZ) const {
    for (int row = 0; row < kBoostPadRows; row++) {
        int gridZ = firstRowGridZ - row;
        for (int col = 0; col < kBoostPadCols; col++) {
            int gridX = centerGridX + col - (kBoostPadCols / 2);
            float worldX = gridToWorldCoord(gridX);
            float worldZ = gridToWorldCoord(gridZ);
            float height = terrainHeightForTrack(track, worldX, worldZ);
            if (height > kFlightHeight - 5.0f) {
                return false;
            }
        }
    }
    return true;
}

bool PhysicsWorld::findBoostPadPlacement(const Track& track, float targetWorldZ, BoostPadRecord& outPad) const {
    int targetGridZ = worldToGridCoord(targetWorldZ);
    for (int offset = 0; offset < 36; offset++) {
        int signedOffset = (offset % 2 == 0) ? -(offset / 2) : ((offset + 1) / 2);
        int firstRowGridZ = targetGridZ + signedOffset;
        int middleRowGridZ = firstRowGridZ - (kBoostPadRows / 2);
        int centerGridX = worldToGridCoord(MathUtils::getRiverCenterX(gridToWorldCoord(middleRowGridZ),
                                                                      track.riverPrimaryPhase,
                                                                      track.riverSecondaryPhase,
                                                                      track.riverFrequencyScale,
                                                                      track.riverCurveScale));
        if (isBoostPadPlacementValid(track, centerGridX, firstRowGridZ)) {
            outPad = { centerGridX, firstRowGridZ };
            return true;
        }
    }
    return false;
}

bool PhysicsWorld::isJumpPadPlacementValid(const Track& track, int firstGridX, int firstRowGridZ) const {
    for (int row = 0; row < kJumpPadRows; row++) {
        int gridZ = firstRowGridZ - row;
        for (int col = 0; col < kJumpPadCols; col++) {
            int gridX = firstGridX + col;
            float worldX = gridToWorldCoord(gridX);
            float worldZ = gridToWorldCoord(gridZ);
            float height = terrainHeightForTrack(track, worldX, worldZ);
            if (height > kFlightHeight - 5.0f) {
                return false;
            }
        }
    }
    return true;
}

bool PhysicsWorld::findJumpPadPlacement(const Track& track, float targetWorldZ, JumpPadRecord& outPad) const {
    int targetGridZ = worldToGridCoord(targetWorldZ);
    for (int offset = 0; offset < 32; offset++) {
        int signedOffset = (offset % 2 == 0) ? -(offset / 2) : ((offset + 1) / 2);
        int firstRowGridZ = targetGridZ + signedOffset;
        int middleRowGridZ = firstRowGridZ - (kJumpPadRows / 2);
        float centerX = MathUtils::getRiverCenterX(gridToWorldCoord(middleRowGridZ),
                                                   track.riverPrimaryPhase,
                                                   track.riverSecondaryPhase,
                                                   track.riverFrequencyScale,
                                                   track.riverCurveScale);
        int firstGridX = worldToGridCoord(centerX - TerrainGrid::COLUMN_SPACING * 0.5f);
        if (isJumpPadPlacementValid(track, firstGridX, firstRowGridZ)) {
            outPad = { firstGridX, firstRowGridZ };
            return true;
        }
    }
    return false;
}

bool PhysicsWorld::isPulseObstaclePlacementValid(const Track& track, int centerGridX, int firstRowGridZ) const {
    for (int row = 0; row < kPulseObstacleRows; row++) {
        int gridZ = firstRowGridZ - row;
        for (int col = -kPulseObstacleHalfCols; col <= kPulseObstacleHalfCols; col++) {
            int gridX = centerGridX + col;
            float worldX = gridToWorldCoord(gridX);
            float worldZ = gridToWorldCoord(gridZ);
            float height = terrainHeightForTrack(track, worldX, worldZ);
            if (height > kFlightHeight - 5.0f) {
                return false;
            }
        }
    }
    return true;
}

bool PhysicsWorld::findPulseObstaclePlacement(const Track& track, float targetWorldZ, PulseObstacleRecord& outPulse) const {
    int targetGridZ = worldToGridCoord(targetWorldZ);
    for (int offset = 0; offset < 34; offset++) {
        int signedOffset = (offset % 2 == 0) ? -(offset / 2) : ((offset + 1) / 2);
        int firstRowGridZ = targetGridZ + signedOffset;
        float centerX = MathUtils::getRiverCenterX(gridToWorldCoord(firstRowGridZ),
                                                   track.riverPrimaryPhase,
                                                   track.riverSecondaryPhase,
                                                   track.riverFrequencyScale,
                                                   track.riverCurveScale);
        int centerGridX = worldToGridCoord(centerX);
        if (isPulseObstaclePlacementValid(track, centerGridX, firstRowGridZ)) {
            outPulse = { centerGridX, firstRowGridZ, kPulseObstacleLifetimeSeconds };
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
        if (findBoostPadPlacement(track, targetWorldZ, pad)) {
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

void PhysicsWorld::scheduleJumpPads(Vehicle& vehicle, Track& track, float totalTime, float currentSpeed) {
    while (totalTime >= nextJumpPadSpawnTime) {
        JumpPadRecord pad;
        float targetWorldZ = vehicle.position.z - currentSpeed * kJumpPadSpawnLeadTime;
        if (findJumpPadPlacement(track, targetWorldZ, pad)) {
            bool duplicate = false;
            for (const auto& existing : jumpPads) {
                if (abs(existing.firstRowGridZ - pad.firstRowGridZ) < 7) {
                    duplicate = true;
                    break;
                }
            }
            if (!duplicate) {
                jumpPads.push_back(pad);
            }
        }
        nextJumpPadSpawnTime += kJumpPadIntervalSeconds;
    }

    for (auto it = jumpPads.begin(); it != jumpPads.end();) {
        if (gridToWorldCoord(it->firstRowGridZ) > vehicle.position.z + 45.0f) {
            it = jumpPads.erase(it);
        } else {
            ++it;
        }
    }
}

void PhysicsWorld::scheduleGates(Vehicle& vehicle, Track& track, float totalTime, float currentSpeed) {
    while (totalTime >= nextGateSpawnTime) {
        float targetWorldZ = vehicle.position.z - currentSpeed * kGateSpawnLeadTime;
        int targetGridZ = worldToGridCoord(targetWorldZ);
        int firstRowGridZ = targetGridZ + (kGateRows / 2);
        int middleRowGridZ = firstRowGridZ - (kGateRows / 2);
        float centerX = MathUtils::getRiverCenterX(gridToWorldCoord(middleRowGridZ),
                                                   track.riverPrimaryPhase,
                                                   track.riverSecondaryPhase,
                                                   track.riverFrequencyScale,
                                                   track.riverCurveScale);
        int centerGridX = worldToGridCoord(centerX);
        int pattern = (int)floorf(nextBoostRandom01(boostRandomState) * 5.0f);
        pattern = std::max(0, std::min(4, pattern));
        gates.push_back({ pattern, centerGridX, firstRowGridZ });
        nextGateSpawnTime += kGateIntervalSeconds;
    }

    for (auto it = gates.begin(); it != gates.end();) {
        if (gridToWorldCoord(it->firstRowGridZ) > vehicle.position.z + 55.0f) {
            it = gates.erase(it);
        } else {
            ++it;
        }
    }
}

void PhysicsWorld::schedulePulseObstacles(Vehicle& vehicle, Track& track, float totalTime, float currentSpeed) {
    while (totalTime >= nextPulseObstacleSpawnTime) {
        PulseObstacleRecord pulse;
        float targetWorldZ = vehicle.position.z - currentSpeed * kPulseObstacleSpawnLeadTime;
        if (findPulseObstaclePlacement(track, targetWorldZ, pulse)) {
            bool duplicate = false;
            for (const auto& existing : pulseObstacles) {
                if (abs(existing.firstRowGridZ - pulse.firstRowGridZ) < 8) {
                    duplicate = true;
                    break;
                }
            }
            if (!duplicate) {
                pulseObstacles.push_back(pulse);
            }
        }
        nextPulseObstacleSpawnTime += kPulseObstacleIntervalSeconds;
    }

    for (auto it = pulseObstacles.begin(); it != pulseObstacles.end();) {
        if (gridToWorldCoord(it->firstRowGridZ) > vehicle.position.z + 55.0f) {
            it = pulseObstacles.erase(it);
        } else {
            ++it;
        }
    }
}

void PhysicsWorld::scheduleRouteForks(Vehicle& vehicle, Track& track, float totalTime, float currentSpeed) {
    if (track.forkActive != 0 && vehicle.position.z < track.forkEndZ - 260.0f) {
        track.forkActive = 0;
        track.forkStartZ = 0.0f;
        track.forkEndZ = 0.0f;
        track.forkOffsetX = 0.0f;
    }

    while (totalTime >= nextRouteForkSpawnTime) {
        if (track.forkActive == 0) {
            float targetWorldZ = vehicle.position.z - currentSpeed * kRouteForkSpawnLeadTime;
            float forkStartZ = gridToWorldCoord(worldToGridCoord(targetWorldZ + 55.0f));
            float forkEndZ = forkStartZ - kRouteForkLength;
            float middleZ = forkStartZ - kRouteForkLength * 0.52f;
            float centerX = MathUtils::getRiverCenterX(middleZ,
                                                       track.riverPrimaryPhase,
                                                       track.riverSecondaryPhase,
                                                       track.riverFrequencyScale,
                                                       track.riverCurveScale);
            float side = centerX > 8.0f ? -1.0f : 1.0f;
            if (fabsf(centerX) <= 8.0f && nextBoostRandom01(boostRandomState) < 0.5f) {
                side = -1.0f;
            }

            track.forkStartZ = forkStartZ;
            track.forkEndZ = forkEndZ;
            track.forkOffsetX = side * kRouteForkOffset;
            track.forkActive = 1;

            constexpr float orbFractions[] = {0.38f, 0.52f, 0.66f};
            for (float fraction : orbFractions) {
                float orbZ = forkStartZ - kRouteForkLength * fraction;
                float forkAmount = forkEnvelopeForTrack(track, orbZ);
                float mainCenter = MathUtils::getRiverCenterX(orbZ,
                                                              track.riverPrimaryPhase,
                                                              track.riverSecondaryPhase,
                                                              track.riverFrequencyScale,
                                                              track.riverCurveScale);
                float orbX = MathUtils::clamp(mainCenter + track.forkOffsetX * forkAmount, -55.0f, 55.0f);
                track.routeOrbs.push_back({
                    simd_make_float3(orbX, kFlightHeight + 3.2f, gridToWorldCoord(worldToGridCoord(orbZ))),
                    kRouteOrbRadius,
                    kRouteOrbScore,
                    false
                });
            }
        }

        nextRouteForkSpawnTime += kRouteForkIntervalSeconds;
    }

    for (auto it = track.routeOrbs.begin(); it != track.routeOrbs.end();) {
        if (it->collected || it->position.z > vehicle.position.z + 45.0f) {
            it = track.routeOrbs.erase(it);
        } else {
            ++it;
        }
    }
}

void PhysicsWorld::scheduleSkillCollectibles(Vehicle& vehicle, Track& track, float totalTime, float currentSpeed) {
    while (totalTime >= nextSkillCollectibleSpawnTime) {
        float targetWorldZ = vehicle.position.z - currentSpeed * kSkillCollectibleLeadTime;
        int targetGridZ = worldToGridCoord(targetWorldZ);
        float snappedWorldZ = gridToWorldCoord(targetGridZ);
        float centerX = MathUtils::getRiverCenterX(snappedWorldZ,
                                                   track.riverPrimaryPhase,
                                                   track.riverSecondaryPhase,
                                                   track.riverFrequencyScale,
                                                   track.riverCurveScale);
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

void PhysicsWorld::collectRouteOrbs(Vehicle& vehicle, Track& track) {
    for (auto& orb : track.routeOrbs) {
        if (orb.collected) {
            continue;
        }

        float dx = vehicle.position.x - orb.position.x;
        float dz = vehicle.position.z - orb.position.z;
        float radius = orb.radius + vehicle.hullRadius;
        if ((dx * dx + dz * dz) <= radius * radius) {
            orb.collected = true;
            vehicle.impactShakeTimer = fmaxf(vehicle.impactShakeTimer, 0.035f);
            vehicle.coins += 4;
            addComboEvent(vehicle, orb.scoreValue, 1.2f);
        }
    }
}

void PhysicsWorld::collectJumpPads(Vehicle& vehicle, float previousX, float previousZ) {
    float sweepMinX = fminf(previousX, vehicle.position.x) - vehicle.hullRadius;
    float sweepMaxX = fmaxf(previousX, vehicle.position.x) + vehicle.hullRadius;
    float sweepMinZ = fminf(previousZ, vehicle.position.z) - vehicle.hullRadius;
    float sweepMaxZ = fmaxf(previousZ, vehicle.position.z) + vehicle.hullRadius;
    float halfSpacing = TerrainGrid::COLUMN_SPACING * 0.5f;

    for (auto it = jumpPads.begin(); it != jumpPads.end();) {
        float padMinX = gridToWorldCoord(it->firstGridX) - halfSpacing - kJumpPadTriggerMargin;
        float padMaxX = gridToWorldCoord(it->firstGridX + kJumpPadCols - 1) + halfSpacing + kJumpPadTriggerMargin;
        float padMaxZ = gridToWorldCoord(it->firstRowGridZ) + halfSpacing + kJumpPadTriggerMargin;
        float padMinZ = gridToWorldCoord(it->firstRowGridZ - (kJumpPadRows - 1)) - halfSpacing - kJumpPadTriggerMargin;
        bool intersectsPad = sweepMinX <= padMaxX && sweepMaxX >= padMinX &&
                             sweepMinZ <= padMaxZ && sweepMaxZ >= padMinZ;
        if (intersectsPad) {
            vehicle.elevateTimer = kJumpRiseDuration + kJumpCruiseDuration + kJumpFallDuration;
            vehicle.impactShakeTimer = fmaxf(vehicle.impactShakeTimer, 0.08f);
            addComboEvent(vehicle, 120, 1.4f);
            it = jumpPads.erase(it);
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
            addComboEvent(vehicle, 150, 1.6f);
        }
    }
}

void PhysicsWorld::addComboEvent(Vehicle& vehicle, int baseScore, float comboTimeBonus) {
    vehicle.comboCount += 1;
    vehicle.comboTimer = fminf(kComboBaseDuration + comboTimeBonus, vehicle.comboTimer + comboTimeBonus + 1.0f);
    vehicle.comboMultiplier = fminf(8.0f, 1.0f + (float)vehicle.comboCount * 0.18f);
    vehicle.scoreMultiplier = fmaxf(vehicle.scoreMultiplier, vehicle.comboMultiplier);
    vehicle.score += (int)roundf((float)baseScore * vehicle.comboMultiplier);
}

bool PhysicsWorld::addNearMissCell(int gridX, int gridZ) {
    for (auto& cell : nearMissCells) {
        if (cell.gridX == gridX && cell.gridZ == gridZ) {
            cell.timer = kNearMissMemorySeconds;
            return false;
        }
    }
    nearMissCells.push_back({ gridX, gridZ, kNearMissMemorySeconds });
    return true;
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
    float baseSpeed = kStartSpeed * powf(2.0f, totalTime / kSpeedDoublingIntervalSeconds);
    const float colSpacing = TerrainGrid::COLUMN_SPACING;
    auto snapToGrid = [colSpacing](float value) {
        return floorf((value + colSpacing * 0.5f) / colSpacing) * colSpacing;
    };
    
    updateEffectState(deltaTime);
    vehicle.impactShakeTimer = fmaxf(0.0f, vehicle.impactShakeTimer - deltaTime);
    vehicle.collisionSlowdownTimer = fmaxf(0.0f, vehicle.collisionSlowdownTimer - deltaTime);
    vehicle.terrainCollisionCooldownTimer = fmaxf(0.0f, vehicle.terrainCollisionCooldownTimer - deltaTime);
    vehicle.comboTimer = fmaxf(0.0f, vehicle.comboTimer - deltaTime);
    if (vehicle.comboTimer <= 0.0f) {
        vehicle.comboCount = 0;
        vehicle.comboMultiplier = fmaxf(1.0f, vehicle.comboMultiplier - deltaTime * 1.6f);
    }
    
    if (vehicle.isDestroyed) {
        float frozenOriginZ = snapToGrid(vehicle.position.z) + kTerrainLeadDistance;
        track.grid.originZ = frozenOriginZ;
        syncVisibleGridState(track, frozenOriginZ);
        return;
    }
    
    vehicle.boostTimer = fmaxf(0.0f, vehicle.boostTimer - deltaTime);
    vehicle.boostMultiplier = vehicle.boostTimer > 0.0f ? 2.0f : 1.0f;
    vehicle.elevateTimer = fmaxf(0.0f, vehicle.elevateTimer - deltaTime);
    vehicle.flattenWaveActive = false;

    // ── Forward Speed ────────────────────────────────────────────
    float speedMult = vehicle.boostMultiplier;
    if (vehicle.elevateTimer > 0.0f) {
        float totalJumpDuration = kJumpRiseDuration + kJumpCruiseDuration + kJumpFallDuration;
        float jumpElapsed = totalJumpDuration - vehicle.elevateTimer;
        if (jumpElapsed >= kJumpRiseDuration && jumpElapsed <= kJumpRiseDuration + kJumpCruiseDuration) {
            speedMult *= kJumpCruiseSpeedMultiplier;
        }
    }
    float slowdownMult = (vehicle.collisionSlowdownTimer > 0.0f) ? kCollisionSlowdownMultiplier : 1.0f;
    float currentSpeed = baseSpeed * speedMult * slowdownMult;
    vehicle.velocity.z = -currentSpeed;
    vehicle.position.z += vehicle.velocity.z * deltaTime;
    scheduleBoostPads(vehicle, track, totalTime, currentSpeed);
    scheduleJumpPads(vehicle, track, totalTime, currentSpeed);
    scheduleGates(vehicle, track, totalTime, currentSpeed);
    schedulePulseObstacles(vehicle, track, totalTime, currentSpeed);
    scheduleRouteForks(vehicle, track, totalTime, currentSpeed);
    scheduleSkillCollectibles(vehicle, track, totalTime, currentSpeed);
    
    bool boostPadDark = false;
    if (getBoostPadCell(vehicle.position.x, vehicle.position.z, boostPadDark)) {
        bool boostWasInactive = vehicle.boostTimer <= 0.0f;
        vehicle.boostTimer = kBoostDuration;
        vehicle.boostMultiplier = 2.0f;
        vehicle.collisionSlowdownTimer = 0.0f;
        if (boostWasInactive) {
            addComboEvent(vehicle, 110, 1.1f);
        }
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
    collectJumpPads(vehicle, previousX, previousZ);
    collectSkillCollectibles(vehicle, track);
    collectRouteOrbs(vehicle, track);

    float flightHeight = kFlightHeight;
    if (vehicle.elevateTimer > 0.0f) {
        float totalJumpDuration = kJumpRiseDuration + kJumpCruiseDuration + kJumpFallDuration;
        float jumpElapsed = totalJumpDuration - vehicle.elevateTimer;
        float normalClearance = kFlightHeight - kApproxRiverbedFlightReferenceY;
        float peakHeight = kApproxRiverbedFlightReferenceY + normalClearance * kJumpTargetHeightMultiplier;
        if (jumpElapsed <= kJumpRiseDuration) {
            float t = jumpElapsed / kJumpRiseDuration;
            t = t * t * (3.0f - 2.0f * t);
            flightHeight = kFlightHeight + (peakHeight - kFlightHeight) * t;
        } else if (jumpElapsed <= kJumpRiseDuration + kJumpCruiseDuration) {
            flightHeight = peakHeight;
        } else {
            float t = (jumpElapsed - kJumpRiseDuration - kJumpCruiseDuration) / kJumpFallDuration;
            t = t * t * (3.0f - 2.0f * t);
            flightHeight = peakHeight + (kFlightHeight - peakHeight) * t;
        }
    }
    vehicle.elevateFlightHeight = flightHeight;
    vehicle.position.y = flightHeight;

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
            float colHeight = terrainHeightForTrack(track, gridX, gridZ);
            bool flattenedCell = isFlattenedCell(gridX, gridZ);
            bool gateCell = getGateCell(gridX, gridZ);
            float pulsePhase = 0.0f;
            bool pulseCell = getPulseObstacleCell(gridX, gridZ, pulsePhase);
            bool pulseActive = pulseCell &&
                               pulsePhase >= kPulseObstacleActiveStart &&
                               pulsePhase <= kPulseObstacleActiveEnd;
            if (flattenedCell) {
                colHeight = flightHeight - 8.0f;
            }
            if (getJumpPadCell(gridX, gridZ)) {
                colHeight = flightHeight - 8.0f;
            }
            if (gateCell && !flattenedCell) {
                colHeight = fmaxf(colHeight, flightHeight + 18.0f);
            }
            if (pulseActive && !flattenedCell) {
                colHeight = fmaxf(colHeight, flightHeight + 18.0f);
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
                if (addNearMissCell(worldToGridCoord(gridX), worldToGridCoord(gridZ))) {
                    vehicle.nearMissCount += 1;
                    vehicle.overdriveCharge = fminf(1.0f, vehicle.overdriveCharge + 0.045f);
                    addComboEvent(vehicle, 75, 0.55f);
                }
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
        vehicle.comboCount = 0;
        vehicle.comboTimer = 0.0f;
        vehicle.comboMultiplier = 1.0f;
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
        vehicle.scoreMultiplier = fminf(8.0f, vehicle.scoreMultiplier + deltaTime * 0.25f);
    } else {
        vehicle.isGrazing = false;
        vehicle.scoreMultiplier = fmaxf(vehicle.comboMultiplier, vehicle.scoreMultiplier - deltaTime * 0.2f);
    }

    if (fmodf(totalTime, kCleanSurvivalComboInterval) < deltaTime && terrainCollisionCellCount == 0 && !grazedThisFrame) {
        addComboEvent(vehicle, 45, 0.35f);
    }

    vehicle.score += (int)(deltaTime * 100.0f * fmaxf(vehicle.scoreMultiplier, vehicle.comboMultiplier));
    float coinRate = 2.2f + (vehicle.scoreMultiplier * 0.9f) + (grazedThisFrame ? 1.8f : 0.0f) + (vehicle.comboMultiplier - 1.0f) * 0.35f;
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
