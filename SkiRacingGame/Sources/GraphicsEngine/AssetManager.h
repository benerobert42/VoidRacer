#import <Foundation/Foundation.h>
#import <MetalKit/MetalKit.h>
#import <ModelIO/ModelIO.h>

NS_ASSUME_NONNULL_BEGIN

@interface AssetManager : NSObject

- (instancetype)initWithDevice:(id<MTLDevice>)device vertexDescriptor:(MTLVertexDescriptor *)vertexDescriptor;

- (nullable MTKMesh *)loadMeshNamed:(NSString *)name extension:(NSString *)ext;
- (nullable id<MTLTexture>)loadTextureNamed:(NSString *)name extension:(NSString *)ext;

- (MTKMesh *)generateFallbackCapsule;
- (MTKMesh *)generateRockMesh;
- (MTKMesh *)generateFallbackPlane;

@end

NS_ASSUME_NONNULL_END
