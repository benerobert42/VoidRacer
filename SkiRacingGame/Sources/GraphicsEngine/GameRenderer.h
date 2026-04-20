#import <MetalKit/MetalKit.h>
#import "GameEngineWrapper.h"

NS_ASSUME_NONNULL_BEGIN

@interface GameRenderer : NSObject <MTKViewDelegate>

@property (nonatomic) BOOL previewMode;
@property (nonatomic) NSInteger forcedLevelType;
@property (nonatomic) BOOL showsVehicle;
@property (nonatomic) BOOL showsObstacles;
@property (nonatomic) BOOL showsChaser;
@property (nonatomic) float previewScrollSpeed;
@property (nonatomic) float vehicleVerticalOffset;

- (instancetype)initWithMetalKitView:(MTKView *)mtkView engineWrapper:(GameEngineWrapper *)engineWrapper;

@end

NS_ASSUME_NONNULL_END
