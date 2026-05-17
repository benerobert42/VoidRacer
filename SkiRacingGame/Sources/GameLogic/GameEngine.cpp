#include "GameEngine.hpp"
#include "MathUtils.hpp"
#include <iostream>

namespace {
void placeVehicleAtRiverCenter(Vehicle& vehicle, const Track& track) {
    float centerX = MathUtils::getRiverCenterX(vehicle.position.z,
                                               track.riverPrimaryPhase,
                                               track.riverSecondaryPhase,
                                               track.riverFrequencyScale,
                                               track.riverCurveScale);
    vehicle.position.x = centerX;
    vehicle.steeringRestCenterX = centerX;
}
}

GameEngine::GameEngine() {
    std::cout << "GameEngine created." << std::endl;
    totalTime = 0.0f;
    levelType = LEVEL_SNOWY_MOUNTAIN;
    visibleLateralLimit = 95.0f;
    vehicle.visibleLateralLimit = visibleLateralLimit;
    placeVehicleAtRiverCenter(vehicle, track);
}

GameEngine::~GameEngine() {
}

void GameEngine::update(float deltaTime) {
    totalTime += deltaTime;
    physics.update(deltaTime, vehicle, track, totalTime, levelType);
    
    for (auto& obstacle : track.obstacles) {
        if (!obstacle.hasCollided && physics.checkObstacleCollision(vehicle, obstacle, levelType)) {
            std::cout << "Hit an obstacle!" << std::endl;
        }
    }
}

void GameEngine::setLevel(int level) {
    levelType = level;
    vehicle = Vehicle();
    vehicle.visibleLateralLimit = visibleLateralLimit;
    track = Track();
    placeVehicleAtRiverCenter(vehicle, track);
    physics = PhysicsWorld();
    totalTime = 0.0f;
}

void GameEngine::setBaseFriction(float friction) {
    vehicle.baseFriction = friction;
}

void GameEngine::setVisibleLateralLimit(float limit) {
    visibleLateralLimit = limit;
    vehicle.visibleLateralLimit = limit;
    if (vehicle.steeringRestCenterX > limit) {
        vehicle.steeringRestCenterX = limit;
    } else if (vehicle.steeringRestCenterX < -limit) {
        vehicle.steeringRestCenterX = -limit;
    }
}

void GameEngine::setSteeringRestCenter(float centerX) {
    if (centerX > visibleLateralLimit) {
        centerX = visibleLateralLimit;
    } else if (centerX < -visibleLateralLimit) {
        centerX = -visibleLateralLimit;
    }
    vehicle.steeringRestCenterX = centerX;
}

void GameEngine::setAirResistance(float resistance) {
    vehicle.airResistance = resistance;
}

void GameEngine::setSteering(float steeringAmount) {
    vehicle.steeringAmount = steeringAmount;
}

const Vehicle& GameEngine::getVehicle() const {
    return vehicle;
}

const Track& GameEngine::getTrack() const {
    return track;
}

int GameEngine::getLevelType() const {
    return levelType;
}

float GameEngine::getTotalTime() const {
    return totalTime;
}
