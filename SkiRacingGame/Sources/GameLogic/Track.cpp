#include "Track.hpp"
#include <math.h>
#include <cstring>

Track::Track() {
    slopeAngle = 30.0f * (M_PI / 180.0f);
    memset(&grid, 0, sizeof(grid));
    grid.originZ = 0.0f;
    generateTrack();
}

void Track::generateTrack() {
    obstacles.clear();
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
