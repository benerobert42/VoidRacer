#ifndef Track_hpp
#define Track_hpp

#include <simd/simd.h>
#include <vector>

struct Obstacle {
    simd_float3 position;
    float radius;
    bool hasCollided;
};

// Reserved grid-cell flags. The current baseline terrain renderer keeps all cells opaque.
enum class CellFlags : uint16_t {
    None          = 0,
    Destructible  = 1 << 0,
    Destroyed     = 1 << 1,
    BoostPad      = 1 << 2,
    HasTurret     = 1 << 3,
    TurretActive  = 1 << 4,
    Equalizer     = 1 << 5,
    ElevationPad  = 1 << 6,
    FlattenPad    = 1 << 7,
    Collided      = 1 << 8,
    BoostPadDark  = 1 << 9
};

struct GridCell {
    uint16_t flags;
    float baseHeight;
    float collisionEffectTimer;
    
    inline bool hasFlag(CellFlags f) const { return (flags & static_cast<uint16_t>(f)) != 0; }
    inline void setFlag(CellFlags f) { flags |= static_cast<uint16_t>(f); }
    inline void clearFlag(CellFlags f) { flags &= ~static_cast<uint16_t>(f); }
};

struct TerrainGrid {
    static constexpr int WIDTH = 60;
    static constexpr int LENGTH = 80;
    static constexpr int PLAYABLE_WIDTH = 40;
    static constexpr float COLUMN_SPACING = 5.0f;
    static constexpr float PLAYABLE_HALF_WIDTH = (PLAYABLE_WIDTH * COLUMN_SPACING) * 0.5f;
    
    GridCell cells[WIDTH * LENGTH];
    float originZ; 
};

class Track {
public:
    std::vector<Obstacle> obstacles;
    TerrainGrid grid;
    float finishLineZ;
    float slopeAngle; // in radians
    
    Track();
    void generateTrack();
};

#endif /* Track_hpp */
