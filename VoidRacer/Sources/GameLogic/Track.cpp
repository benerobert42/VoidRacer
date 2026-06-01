#include "Track.hpp"
#include <math.h>
#include <cstring>
#include <random>

namespace {
float randomRange(std::mt19937& rng, float minValue, float maxValue) {
    std::uniform_real_distribution<float> distribution(minValue, maxValue);
    return distribution(rng);
}
}

Track::Track() {
    slopeAngle = 30.0f * (M_PI / 180.0f);
    std::random_device device;
    std::mt19937 rng(device());
    riverPrimaryPhase = randomRange(rng, 0.0f, 2.0f * (float)M_PI);
    riverSecondaryPhase = randomRange(rng, 0.0f, 2.0f * (float)M_PI);
    riverFrequencyScale = randomRange(rng, 0.90f, 1.14f);
    riverCurveScale = randomRange(rng, 0.86f, 1.05f);
    forkStartZ = 0.0f;
    forkEndZ = 0.0f;
    forkOffsetX = 0.0f;
    forkActive = 0;
    memset(&grid, 0, sizeof(grid));
    grid.originZ = 0.0f;
    generateTrack();
}

void Track::generateTrack() {
    obstacles.clear();
    skillCollectibles.clear();
    routeOrbs.clear();
    finishLineZ = -2000.0f;
    
    // Initialize the terrain grid cells
    for (int row = 0; row < TerrainGrid::LENGTH; row++) {
        for (int col = 0; col < TerrainGrid::WIDTH; col++) {
            int idx = row * TerrainGrid::WIDTH + col;
            
            GridCell& cell = grid.cells[idx];
            cell.flags = 0;
            cell.baseHeight = 0.0f;
            cell.collisionEffectTimer = 0.0f;
        }
    }
}
