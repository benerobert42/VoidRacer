#import <MetalKit/MetalKit.h>
#import "GameEngineWrapper.h"

NS_ASSUME_NONNULL_BEGIN

@interface GameRenderer : NSObject <MTKViewDelegate>

@property (nonatomic) BOOL previewMode;
@property (nonatomic) NSInteger forcedLevelType;
@property (nonatomic) BOOL showsVehicle;
@property (nonatomic) BOOL showsObstacles;
@property (nonatomic) BOOL showsChaser;
@property (nonatomic) BOOL storeGridPalette;
@property (nonatomic) float previewScrollSpeed;
@property (nonatomic) float vehicleVerticalOffset;
@property (nonatomic) float visualModifierIntensity;
@property (nonatomic) float visualEdgeGlowBoost;
@property (nonatomic) float visualPathGlowBoost;
@property (nonatomic) float visualParticleBoost;
@property (nonatomic) NSInteger visualMoodStyle;

- (instancetype)initWithMetalKitView:(MTKView *)mtkView engineWrapper:(GameEngineWrapper *)engineWrapper;

@end

NS_ASSUME_NONNULL_END
