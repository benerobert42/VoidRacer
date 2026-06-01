#ifndef GameEngine_hpp
#define GameEngine_hpp

#include "Vehicle.hpp"
#include "Track.hpp"
#include "PhysicsWorld.hpp"

// Level types matching the shader's levelType uniform
enum LevelType {
    LEVEL_SNOWY_MOUNTAIN = 0,
    LEVEL_OLYMPUS_MONS   = 1,
    LEVEL_ROCKY_MOUNTAIN = 2,
    LEVEL_DEBUG          = 3
};

class GameEngine {
public:
    GameEngine();
    ~GameEngine();
    
    void update(float deltaTime);
    void setLevel(int level);
    void setVisibleLateralLimit(float limit);
    void setSteeringRestCenter(float centerX);
    
    void setBaseFriction(float friction);
    void setAirResistance(float resistance);
    void setSteering(float steeringAmount);
    
    const Vehicle& getVehicle() const;
    const Track& getTrack() const;
    int getLevelType() const;
    float getTotalTime() const;

private:
    Vehicle vehicle;
    Track track;
    PhysicsWorld physics;
    float totalTime;
    int levelType;
    float visibleLateralLimit;
};

#endif /* GameEngine_hpp */
