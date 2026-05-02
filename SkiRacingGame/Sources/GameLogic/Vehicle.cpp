#include "Vehicle.hpp"

Vehicle::Vehicle() {
    position = simd_make_float3(0.0f, 0.0f, 0.0f);
    velocity = simd_make_float3(0.0f, 0.0f, 0.0f);
    
    mass = 120.0f;
    baseFriction = 0.01f;
    airResistance = 0.01f;
    
    health = 100;
    isDestroyed = false;
    
    steeringAmount = 0.0f;
    visibleLateralLimit = 95.0f;
    steeringRestCenterX = 0.0f;
    coins = 0;
    coinAccumulator = 0.0f;
    
    // Shooter mechanics
    hullRadius = 1.2f;
    grazeRadius = 4.0f;   // Wide enough to reliably register near-misses
    overdriveCharge = 0.0f;
    scoreMultiplier = 1.0f;
    isGrazing = false;
    
    chaserZ = 50.0f;        // Starts behind the player
    chaserBaseSpeed = 99.0f; // Matches the run's starting baseline speed
    
    boostTimer = 0.0f;
    boostMultiplier = 1.0f;
    impactShakeTimer = 0.0f;
    collisionSlowdownTimer = 0.0f;
    terrainCollisionCooldownTimer = 0.0f;
    
    elevateTimer = 0.0f;
    elevateFlightHeight = 12.0f;
    
    flattenWaveActive = false;
    flattenWaveZ = 0.0f;
    flattenTargetX = 0.0f;
    flattenWaveEndZ = 0.0f;
    
    score = 0;
}
