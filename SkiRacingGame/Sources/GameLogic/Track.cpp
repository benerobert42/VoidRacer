#include "Track.hpp"
#include "MathUtils.hpp"
#include <math.h>
#include <stdlib.h>
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
    float colSpacing = 5.0f;
    float halfWidth = (TerrainGrid::WIDTH / 2.0f) * colSpacing;
    
    for (int row = 0; row < TerrainGrid::LENGTH; row++) {
        float worldZ = grid.originZ - row * colSpacing;
        
        for (int col = 0; col < TerrainGrid::WIDTH; col++) {
            float worldX = (col - TerrainGrid::WIDTH / 2.0f) * colSpacing;
            int idx = row * TerrainGrid::WIDTH + col;
            
            GridCell& cell = grid.cells[idx];
            cell.flags = 0;
            cell.baseHeight = MathUtils::getTerrainHeight(worldX, worldZ, slopeAngle);
            cell.collisionEffectTimer = 0.0f;
            
            // Distance from the nearest river branch center
            float distFromRiver = MathUtils::getDistFromRiver(worldX, worldZ);
            
            // River edge: cluster groups of columns are destructible (breakable through)
            if (distFromRiver > 12.0f && distFromRiver < 22.0f) {
                int groupRow = row / 3;
                int groupCol = col / 3;
                // Use a simple hash to make ~30% of groups destructible clusters
                float groupHash = MathUtils::hash(groupRow * 0.73f + 1.3f, groupCol * 0.91f + 2.7f);
                if (groupHash < 0.30f) {
                    cell.setFlag(CellFlags::Destructible);
                }
            }
            
            // Low riverbed cells: small chance to be a Boost Pad
            if (distFromRiver < 10.0f && cell.baseHeight < -10.0f) {
                float r = (float)rand() / RAND_MAX;
                if (r < 0.02f) {
                    cell.setFlag(CellFlags::BoostPad);
                }
            }
            
            // Deep riverbed center: very rare Elevation Pads (raise ship for 10s)
            if (distFromRiver < 6.0f && cell.baseHeight < -13.0f) {
                float r = (float)rand() / RAND_MAX;
                if (r < 0.004f) {
                    cell.setFlag(CellFlags::ElevationPad);
                }
            }
            
            // Flatten Pads: very rare, centered in riverbed
            if (distFromRiver < 6.0f && cell.baseHeight < -13.0f) {
                float r = (float)rand() / RAND_MAX;
                if (r < 0.003f) {
                    cell.setFlag(CellFlags::FlattenPad);
                }
            }
        }
    }
}
