#ifndef Vehicle_hpp
#define Vehicle_hpp

#include <simd/simd.h>

class Vehicle {
public:
    simd_float3 position;
    simd_float3 velocity;
    
    float mass;
    float baseFriction;
    float airResistance;
    
    int health;
    bool isDestroyed;
    
    // Steering input from -1.0 (left) to 1.0 (right)
    float steeringAmount;
    float visibleLateralLimit;
    float steeringRestCenterX;
    
    // Coins collected based on time and performance
    int coins;
    float coinAccumulator;
    
    // ── Shooter Mechanics ───────────────────────────────
    // Graze system (near-miss dual radii)
    float hullRadius;      // Lethal collision radius
    float grazeRadius;     // Larger graze detection radius
    float overdriveCharge; // 0.0 to 1.0, builds from grazing
    float scoreMultiplier; // Increases with graze streaks
    bool isGrazing;        // True when currently in graze zone
    
    // Chaser (wall of energy behind)
    float chaserZ;         // Z position of the advancing wall
    float chaserBaseSpeed; // Matches the run's non-boost baseline speed
    
    // Boost pads
    float boostTimer;      // Remaining seconds of speed boost
    float boostMultiplier; // Speed multiplier when boosted
    float impactShakeTimer;
    float collisionSlowdownTimer;
    float terrainCollisionCooldownTimer;
    
    // Elevation pads
    float elevateTimer;        // Remaining seconds of elevated flight
    float elevateFlightHeight; // Elevated flight height (above normal 12.0)
    
    // Flatten wave
    bool flattenWaveActive;
    float flattenWaveZ;
    float flattenTargetX;
    float flattenWaveEndZ;
    
    // Score
    int score;
    
    Vehicle();
};

#endif /* Vehicle_hpp */
