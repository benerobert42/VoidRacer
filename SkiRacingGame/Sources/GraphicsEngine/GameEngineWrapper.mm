#import "GameEngineWrapper.h"
#include "../GameLogic/GameEngine.hpp"
#import <simd/simd.h>

@interface GameEngineWrapper () {
    GameEngine* _engine;
    NSString *_vehicleMeshName;
    NSString *_vehicleTextureName;
}
@end

@implementation GameEngineWrapper

- (instancetype)init {
    self = [super init];
    if (self) {
        _engine = new GameEngine();
        _vehicleMeshName = @"Executioner";
        _vehicleTextureName = @"Executioner_Blue";
    }
    return self;
}

- (void)dealloc {
    delete _engine;
}

- (void)updateWithDeltaTime:(float)deltaTime {
    _engine->update(deltaTime);
}

- (void)setBaseFriction:(float)friction {
    _engine->setBaseFriction(friction);
}

- (void)setAirResistance:(float)resistance {
    _engine->setAirResistance(resistance);
}

- (void)setSteering:(float)steeringAmount {
    _engine->setSteering(steeringAmount);
}

- (void)setLevel:(int)level {
    _engine->setLevel(level);
}

- (void)setVisibleLateralLimit:(float)limit {
    _engine->setVisibleLateralLimit(limit);
}

- (void)setVehicleMeshName:(NSString *)meshName {
    _vehicleMeshName = [meshName copy];
}

- (void)setVehicleTextureName:(NSString *)textureName {
    _vehicleTextureName = [textureName copy];
}

- (float)getVehicleSpeed {
    simd_float3 vel = _engine->getVehicle().velocity;
    return simd_length(vel);
}

- (int)getVehicleHealth {
    return _engine->getVehicle().health;
}

- (int)getCoins {
    return _engine->getVehicle().coins;
}

- (int)getLevelType {
    return _engine->getLevelType();
}

- (int)getScore {
    return _engine->getVehicle().score;
}

- (float)getTotalTime {
    return _engine->getTotalTime();
}

- (float)getOverdriveCharge {
    return _engine->getVehicle().overdriveCharge;
}

- (bool)getIsGrazing {
    return _engine->getVehicle().isGrazing;
}

- (float)getChaserDistance {
    return _engine->getVehicle().position.z - _engine->getVehicle().chaserZ;
}

- (void*)getEngineRawPointer {
    return _engine;
}

- (NSString *)vehicleMeshName {
    return _vehicleMeshName ?: @"Executioner";
}

- (NSString *)vehicleTextureName {
    return _vehicleTextureName ?: @"Executioner_Blue";
}

@end
