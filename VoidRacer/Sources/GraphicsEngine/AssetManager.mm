#import "AssetManager.h"

@implementation AssetManager {
    id<MTLDevice> _device;
    MDLVertexDescriptor *_mdlVertexDescriptor;
    MTKMeshBufferAllocator *_allocator;
}

- (nullable NSURL *)resourceURLForName:(NSString *)name extension:(NSString *)ext {
    NSURL *directURL = [[NSBundle mainBundle] URLForResource:name withExtension:ext];
    if (directURL) {
        return directURL;
    }
    
    NSString *target = [NSString stringWithFormat:@"%@.%@", name, ext];
    NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:[NSBundle mainBundle].resourceURL
                                                             includingPropertiesForKeys:nil
                                                                                options:NSDirectoryEnumerationSkipsHiddenFiles
                                                                           errorHandler:nil];
    for (NSURL *candidate in enumerator) {
        if ([[candidate lastPathComponent] isEqualToString:target]) {
            return candidate;
        }
    }
    return nil;
}

- (instancetype)initWithDevice:(id<MTLDevice>)device vertexDescriptor:(MTLVertexDescriptor *)vertexDescriptor {
    self = [super init];
    if (self) {
        _device = device;
        _allocator = [[MTKMeshBufferAllocator alloc] initWithDevice:_device];
        
        _mdlVertexDescriptor = MTKModelIOVertexDescriptorFromMetal(vertexDescriptor);
        _mdlVertexDescriptor.attributes[0].name = MDLVertexAttributePosition;
        _mdlVertexDescriptor.attributes[1].name = MDLVertexAttributeNormal;
        _mdlVertexDescriptor.attributes[2].name = MDLVertexAttributeTextureCoordinate;
    }
    return self;
}

- (nullable MTKMesh *)loadMeshNamed:(NSString *)name extension:(NSString *)ext {
    NSURL *url = [self resourceURLForName:name extension:ext];
    if (!url) {
        NSLog(@"AssetManager: Could not find %@.%@ in bundle.", name, ext);
        return nil;
    }
    
    NSError *error = nil;
    MDLAsset *asset = [[MDLAsset alloc] initWithURL:url vertexDescriptor:_mdlVertexDescriptor bufferAllocator:_allocator];
    if (!asset || asset.count == 0) {
        NSLog(@"AssetManager: Failed to load asset from %@", url);
        return nil;
    }
    
    MDLMesh *mdlMesh = (MDLMesh *)[asset objectAtIndex:0];
    if (![mdlMesh isKindOfClass:[MDLMesh class]]) {
        NSLog(@"AssetManager: Asset does not contain a mesh at index 0.");
        return nil;
    }
    
    MTKMesh *mtkMesh = [[MTKMesh alloc] initWithMesh:mdlMesh device:_device error:&error];
    if (error) {
        NSLog(@"AssetManager: Error converting MDLMesh to MTKMesh: %@", error);
        return nil;
    }
    
    return mtkMesh;
}

- (nullable id<MTLTexture>)loadTextureNamed:(NSString *)name extension:(NSString *)ext {
    NSURL *url = [self resourceURLForName:name extension:ext];
    if (!url) {
        NSLog(@"AssetManager: Could not find texture %@.%@ in bundle.", name, ext);
        return nil;
    }
    
    MTKTextureLoader *loader = [[MTKTextureLoader alloc] initWithDevice:_device];
    NSDictionary *options = @{
        MTKTextureLoaderOptionTextureUsage: @(MTLTextureUsageShaderRead),
        MTKTextureLoaderOptionTextureStorageMode: @(MTLStorageModePrivate),
        MTKTextureLoaderOptionSRGB: @NO
    };
    
    NSError *error = nil;
    id<MTLTexture> texture = [loader newTextureWithContentsOfURL:url options:options error:&error];
    if (error || !texture) {
        NSLog(@"AssetManager: Failed to load texture from %@. Error: %@", url, error);
        return nil;
    }
    
    return texture;
}

- (MTKMesh *)generateFallbackCapsule {
    MDLMesh *mdl = [MDLMesh newCapsuleWithHeight:1.8 radii:simd_make_float2(0.3, 0.3) radialSegments:12 verticalSegments:12 hemisphereSegments:6 geometryType:MDLGeometryTypeTriangles inwardNormals:NO allocator:_allocator];
    mdl.vertexDescriptor = _mdlVertexDescriptor;
    return [[MTKMesh alloc] initWithMesh:mdl device:_device error:nil];
}

- (MTKMesh *)generateRockMesh {
    // True geometric cube for the arcade voxel grid
    MDLMesh *mdl = [MDLMesh newBoxWithDimensions:simd_make_float3(1.0, 1.0, 1.0) segments:simd_make_uint3(1, 1, 1) geometryType:MDLGeometryTypeTriangles inwardNormals:NO allocator:_allocator];
    mdl.vertexDescriptor = _mdlVertexDescriptor;
    return [[MTKMesh alloc] initWithMesh:mdl device:_device error:nil];
}

- (MTKMesh *)generateFallbackPlane {
    // 100x300 segments per tile. Three tiles drawn for seamless infinite terrain.
    MDLMesh *mdl = [MDLMesh newPlaneWithDimensions:simd_make_float2(200.0, 600.0) segments:simd_make_uint2(100, 300) geometryType:MDLGeometryTypeTriangles allocator:_allocator];
    mdl.vertexDescriptor = _mdlVertexDescriptor;
    NSError *error = nil;
    MTKMesh *mesh = [[MTKMesh alloc] initWithMesh:mdl device:_device error:&error];
    if (error) {
        NSLog(@"AssetManager: Failed to create terrain mesh: %@", error);
    }
    return mesh;
}

@end
