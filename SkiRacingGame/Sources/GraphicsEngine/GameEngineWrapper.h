#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface GameEngineWrapper : NSObject

- (instancetype)init;
- (void)updateWithDeltaTime:(float)deltaTime;
- (void)setBaseFriction:(float)friction;
- (void)setAirResistance:(float)resistance;
- (void)setSteering:(float)steeringAmount;
- (void)setLevel:(int)level;
- (void)setVisibleLateralLimit:(float)limit;
- (void)setVehicleMeshName:(NSString *)meshName;
- (void)setVehicleTextureName:(NSString *)textureName;

// HUD Accessors
- (float)getVehicleSpeed;
- (int)getVehicleHealth;
- (int)getCoins;
- (int)getLevelType;
- (int)getScore;
- (float)getTotalTime;
- (float)getOverdriveCharge;
- (bool)getIsGrazing;
- (int)getNearMissCount;
- (float)getComboMultiplier;
- (float)getComboTimer;
- (float)getChaserDistance;

// The C++ engine accessor for the renderer
- (void*)getEngineRawPointer;
- (NSString *)vehicleMeshName;
- (NSString *)vehicleTextureName;

@end

NS_ASSUME_NONNULL_END
