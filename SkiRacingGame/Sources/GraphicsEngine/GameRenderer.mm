#import "GameRenderer.h"
#import <ModelIO/ModelIO.h>
#import <simd/simd.h>
#include "../GameLogic/GameEngine.hpp"
#import "AssetManager.h"
#include <cstring>

struct Uniforms {
    matrix_float4x4 modelMatrix;
    matrix_float4x4 viewProjectionMatrix;
    simd_float3 color;
    int useTexture;
    int isTerrain;
    float slopeAngle;
    int levelType;
    simd_float3 vehiclePosition;
    simd_float3 cameraPosition;
    float time;
    float chaserZ; // Z position of the chaser wall
    float vehicleSpeed;
    int isGrazing;
    float overdriveCharge;
    int renderStyle;
    float terrainOriginZ;
    simd_float2 viewportSize;
    float outlinePixelWidth;
    float uniformPadding;
};

// Must match GridCellGPU in Shaders.metal
struct GridCellGPU {
    uint16_t flags;
    float collisionTimer;
};

@implementation GameRenderer {
    id<MTLDevice> _device;
    id<MTLCommandQueue> _commandQueue;
    id<MTLRenderPipelineState> _pipelineState;
    id<MTLRenderPipelineState> _shipPipelineState;
    id<MTLRenderPipelineState> _shipMaskPipelineState;
    id<MTLRenderPipelineState> _shipOutlineCompositePipelineState;
    id<MTLDepthStencilState> _depthState;
    MTLVertexDescriptor *_vertexDescriptor;
    id<MTLSamplerState> _samplerState;
    id<MTLSamplerState> _maskSamplerState;
    id<MTLTexture> _dummyTexture;
    id<MTLTexture> _chromeRoughnessTexture;
    id<MTLTexture> _shipMaskTexture;
    NSUInteger _shipMaskWidth;
    NSUInteger _shipMaskHeight;
    
    MTKMesh *_vehicleMesh;
    
    MTKMesh *_rockMesh;
    MTKMesh *_terrainMesh;
    
    AssetManager *_assetManager;
    
    GameEngineWrapper *_wrapper;
    GameEngine *_engine;
    
    // Smooth camera
    simd_float3 _smoothCamPos;
    simd_float3 _smoothCamTarget;
    bool _cameraInitialized;
    
    // Time tracking for shader animation
    double _elapsedTime;
    NSTimeInterval _lastPresentTime;
    
    // Reserved grid cell state buffer; keeps the terrain shader binding layout stable.
    id<MTLBuffer> _gridStateBuffer;
    
    // Alpha-blended pipeline for non-terrain effects such as the chaser wall and ship outline.
    id<MTLRenderPipelineState> _blendPipelineState;
    id<MTLDepthStencilState> _transparentDepthState;
    id<MTLDepthStencilState> _overlayDepthState;
    id<MTLDepthStencilState> _vehicleBodyStencilDepthState;
    id<MTLDepthStencilState> _vehicleOutlineStencilDepthState;
}

// ── Matrix helpers ──────────────────────────────────────────────────

static matrix_float4x4 matrix_perspective(float fovyRadians, float aspect, float nearZ, float farZ) {
    float ys = 1.0f / tanf(fovyRadians * 0.5f);
    float xs = ys / aspect;
    float zs = farZ / (nearZ - farZ);
    return simd_matrix(
        simd_make_float4(xs,  0,   0,   0),
        simd_make_float4(0,   ys,  0,   0),
        simd_make_float4(0,   0,   zs, -1),
        simd_make_float4(0,   0,   nearZ * zs, 0)
    );
}

static matrix_float4x4 matrix_look_at(simd_float3 eye, simd_float3 target, simd_float3 up) {
    simd_float3 z = simd_normalize(eye - target);
    simd_float3 x = simd_normalize(simd_cross(up, z));
    simd_float3 y = simd_cross(z, x);
    return simd_matrix(
        simd_make_float4(x.x, y.x, z.x, 0),
        simd_make_float4(x.y, y.y, z.y, 0),
        simd_make_float4(x.z, y.z, z.z, 0),
        simd_make_float4(-simd_dot(x, eye), -simd_dot(y, eye), -simd_dot(z, eye), 1)
    );
}

static matrix_float4x4 matrix_translation(simd_float3 t) {
    return simd_matrix(
        simd_make_float4(1, 0, 0, 0),
        simd_make_float4(0, 1, 0, 0),
        simd_make_float4(0, 0, 1, 0),
        simd_make_float4(t.x, t.y, t.z, 1)
    );
}

static matrix_float4x4 matrix_rotation_y(float radians) {
    float c = cosf(radians); float s = sinf(radians);
    return simd_matrix(
        simd_make_float4(c, 0, -s, 0),
        simd_make_float4(0, 1,  0, 0),
        simd_make_float4(s, 0,  c, 0),
        simd_make_float4(0, 0,  0, 1)
    );
}

static matrix_float4x4 matrix_scale(simd_float3 s) {
    return simd_matrix(
        simd_make_float4(s.x, 0, 0, 0),
        simd_make_float4(0, s.y, 0, 0),
        simd_make_float4(0, 0, s.z, 0),
        simd_make_float4(0, 0, 0, 1)
    );
}

// ── Init ────────────────────────────────────────────────────────────

- (instancetype)initWithMetalKitView:(MTKView *)mtkView engineWrapper:(GameEngineWrapper *)wrapper {
    self = [super init];
    if (self) {
        _device = mtkView.device;
        _wrapper = wrapper;
        _engine = (GameEngine *)[_wrapper getEngineRawPointer];
        _commandQueue = [_device newCommandQueue];
        _cameraInitialized = false;
        _cameraInitialized = false;
        _elapsedTime = 0.0;
        _lastPresentTime = 0.0;
        self.previewMode = NO;
        self.forcedLevelType = -1;
        self.showsVehicle = YES;
        self.showsObstacles = YES;
        self.showsChaser = YES;
        self.previewScrollSpeed = 50.0f;
        self.vehicleVerticalOffset = 0.0f;
        
        mtkView.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
        mtkView.depthStencilPixelFormat = MTLPixelFormatDepth32Float_Stencil8;
        mtkView.sampleCount = 4;
        mtkView.clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 1.0); // Pitch black void
        
        [self buildPipelinesWithView:mtkView];
        [self buildMeshes];
        
        // Create GPU buffer for grid state (60 x 80 cells)
        _gridStateBuffer = [_device newBufferWithLength:(TerrainGrid::WIDTH * TerrainGrid::LENGTH) * sizeof(GridCellGPU)
                                               options:MTLResourceStorageModeShared];
    }
    return self;
}

// ── Pipeline ────────────────────────────────────────────────────────

- (void)buildPipelinesWithView:(MTKView *)view {
    NSError *error = nil;
    id<MTLLibrary> defaultLibrary = [_device newDefaultLibrary];
    id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertex_main"];
    id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"fragment_main"];
    id<MTLFunction> shipFragmentFunction = [defaultLibrary newFunctionWithName:@"fragment_ship_pbr"];
    id<MTLFunction> shipMaskFragmentFunction = [defaultLibrary newFunctionWithName:@"fragment_ship_mask"];
    id<MTLFunction> fullscreenVertexFunction = [defaultLibrary newFunctionWithName:@"vertex_fullscreen"];
    id<MTLFunction> shipOutlineFragmentFunction = [defaultLibrary newFunctionWithName:@"fragment_ship_outline"];
    
    _vertexDescriptor = [[MTLVertexDescriptor alloc] init];
    _vertexDescriptor.attributes[0].format = MTLVertexFormatFloat3;
    _vertexDescriptor.attributes[0].offset = 0;
    _vertexDescriptor.attributes[0].bufferIndex = 0;
    _vertexDescriptor.attributes[1].format = MTLVertexFormatFloat3;
    _vertexDescriptor.attributes[1].offset = 12;
    _vertexDescriptor.attributes[1].bufferIndex = 0;
    _vertexDescriptor.attributes[2].format = MTLVertexFormatFloat2;
    _vertexDescriptor.attributes[2].offset = 24;
    _vertexDescriptor.attributes[2].bufferIndex = 0;
    _vertexDescriptor.layouts[0].stride = 32;
    _vertexDescriptor.layouts[0].stepRate = 1;
    _vertexDescriptor.layouts[0].stepFunction = MTLVertexStepFunctionPerVertex;
    
    MTLRenderPipelineDescriptor *desc = [[MTLRenderPipelineDescriptor alloc] init];
    desc.label = @"Mountain Render Pipeline";
    desc.vertexFunction = vertexFunction;
    desc.fragmentFunction = fragmentFunction;
    desc.vertexDescriptor = _vertexDescriptor;
    desc.colorAttachments[0].pixelFormat = view.colorPixelFormat;
    desc.depthAttachmentPixelFormat = view.depthStencilPixelFormat;
    desc.stencilAttachmentPixelFormat = view.depthStencilPixelFormat;
    desc.rasterSampleCount = view.sampleCount;
    
    _pipelineState = [_device newRenderPipelineStateWithDescriptor:desc error:&error];
    NSAssert(_pipelineState, @"Failed to create pipeline state: %@", error);

    MTLRenderPipelineDescriptor *shipDesc = [desc copy];
    shipDesc.label = @"Ship PBR Render Pipeline";
    shipDesc.fragmentFunction = shipFragmentFunction;
    _shipPipelineState = [_device newRenderPipelineStateWithDescriptor:shipDesc error:&error];
    NSAssert(_shipPipelineState, @"Failed to create ship pipeline state: %@", error);

    MTLRenderPipelineDescriptor *shipMaskDesc = [[MTLRenderPipelineDescriptor alloc] init];
    shipMaskDesc.label = @"Ship Screen Mask Pipeline";
    shipMaskDesc.vertexFunction = vertexFunction;
    shipMaskDesc.fragmentFunction = shipMaskFragmentFunction;
    shipMaskDesc.vertexDescriptor = _vertexDescriptor;
    shipMaskDesc.colorAttachments[0].pixelFormat = MTLPixelFormatR8Unorm;
    _shipMaskPipelineState = [_device newRenderPipelineStateWithDescriptor:shipMaskDesc error:&error];
    NSAssert(_shipMaskPipelineState, @"Failed to create ship mask pipeline state: %@", error);

    MTLRenderPipelineDescriptor *outlineDesc = [[MTLRenderPipelineDescriptor alloc] init];
    outlineDesc.label = @"Ship Screen Outline Composite Pipeline";
    outlineDesc.vertexFunction = fullscreenVertexFunction;
    outlineDesc.fragmentFunction = shipOutlineFragmentFunction;
    outlineDesc.colorAttachments[0].pixelFormat = view.colorPixelFormat;
    outlineDesc.colorAttachments[0].blendingEnabled = YES;
    outlineDesc.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
    outlineDesc.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
    outlineDesc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    outlineDesc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    outlineDesc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
    outlineDesc.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    _shipOutlineCompositePipelineState = [_device newRenderPipelineStateWithDescriptor:outlineDesc error:&error];
    NSAssert(_shipOutlineCompositePipelineState, @"Failed to create ship outline composite pipeline state: %@", error);
    
    // ── Blended pipeline for non-terrain effects ───────────
    MTLRenderPipelineDescriptor *blendDesc = [[MTLRenderPipelineDescriptor alloc] init];
    blendDesc.label = @"Effect Blend Pipeline";
    blendDesc.vertexFunction = vertexFunction;
    blendDesc.fragmentFunction = fragmentFunction;
    blendDesc.vertexDescriptor = _vertexDescriptor;
    blendDesc.colorAttachments[0].pixelFormat = view.colorPixelFormat;
    blendDesc.colorAttachments[0].blendingEnabled = YES;
    blendDesc.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
    blendDesc.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
    blendDesc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    blendDesc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    blendDesc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorOne;
    blendDesc.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    blendDesc.depthAttachmentPixelFormat = view.depthStencilPixelFormat;
    blendDesc.stencilAttachmentPixelFormat = view.depthStencilPixelFormat;
    blendDesc.rasterSampleCount = view.sampleCount;
    _blendPipelineState = [_device newRenderPipelineStateWithDescriptor:blendDesc error:&error];
    NSAssert(_blendPipelineState, @"Failed to create blend pipeline: %@", error);
    
    MTLDepthStencilDescriptor *depthDesc = [[MTLDepthStencilDescriptor alloc] init];
    depthDesc.depthCompareFunction = MTLCompareFunctionLess;
    depthDesc.depthWriteEnabled = YES;
    _depthState = [_device newDepthStencilStateWithDescriptor:depthDesc];

    MTLDepthStencilDescriptor *transparentDepthDesc = [[MTLDepthStencilDescriptor alloc] init];
    transparentDepthDesc.depthCompareFunction = MTLCompareFunctionLess;
    transparentDepthDesc.depthWriteEnabled = NO;
    _transparentDepthState = [_device newDepthStencilStateWithDescriptor:transparentDepthDesc];

    MTLDepthStencilDescriptor *overlayDepthDesc = [[MTLDepthStencilDescriptor alloc] init];
    overlayDepthDesc.depthCompareFunction = MTLCompareFunctionAlways;
    overlayDepthDesc.depthWriteEnabled = NO;
    _overlayDepthState = [_device newDepthStencilStateWithDescriptor:overlayDepthDesc];

    MTLStencilDescriptor *vehicleBodyStencil = [[MTLStencilDescriptor alloc] init];
    vehicleBodyStencil.stencilCompareFunction = MTLCompareFunctionAlways;
    vehicleBodyStencil.stencilFailureOperation = MTLStencilOperationKeep;
    vehicleBodyStencil.depthFailureOperation = MTLStencilOperationKeep;
    vehicleBodyStencil.depthStencilPassOperation = MTLStencilOperationReplace;
    vehicleBodyStencil.readMask = 0xFF;
    vehicleBodyStencil.writeMask = 0xFF;

    MTLDepthStencilDescriptor *vehicleBodyDepthDesc = [[MTLDepthStencilDescriptor alloc] init];
    vehicleBodyDepthDesc.depthCompareFunction = MTLCompareFunctionLess;
    vehicleBodyDepthDesc.depthWriteEnabled = YES;
    vehicleBodyDepthDesc.frontFaceStencil = vehicleBodyStencil;
    vehicleBodyDepthDesc.backFaceStencil = vehicleBodyStencil;
    _vehicleBodyStencilDepthState = [_device newDepthStencilStateWithDescriptor:vehicleBodyDepthDesc];

    MTLStencilDescriptor *vehicleOutlineStencil = [[MTLStencilDescriptor alloc] init];
    vehicleOutlineStencil.stencilCompareFunction = MTLCompareFunctionNotEqual;
    vehicleOutlineStencil.stencilFailureOperation = MTLStencilOperationKeep;
    vehicleOutlineStencil.depthFailureOperation = MTLStencilOperationKeep;
    vehicleOutlineStencil.depthStencilPassOperation = MTLStencilOperationKeep;
    vehicleOutlineStencil.readMask = 0xFF;
    vehicleOutlineStencil.writeMask = 0x00;

    MTLDepthStencilDescriptor *vehicleOutlineDepthDesc = [[MTLDepthStencilDescriptor alloc] init];
    vehicleOutlineDepthDesc.depthCompareFunction = MTLCompareFunctionLessEqual;
    vehicleOutlineDepthDesc.depthWriteEnabled = NO;
    vehicleOutlineDepthDesc.frontFaceStencil = vehicleOutlineStencil;
    vehicleOutlineDepthDesc.backFaceStencil = vehicleOutlineStencil;
    _vehicleOutlineStencilDepthState = [_device newDepthStencilStateWithDescriptor:vehicleOutlineDepthDesc];
    
    MTLSamplerDescriptor *samplerDesc = [MTLSamplerDescriptor new];
    samplerDesc.minFilter = MTLSamplerMinMagFilterLinear;
    samplerDesc.magFilter = MTLSamplerMinMagFilterLinear;
    samplerDesc.sAddressMode = MTLSamplerAddressModeRepeat;
    samplerDesc.tAddressMode = MTLSamplerAddressModeRepeat;
    _samplerState = [_device newSamplerStateWithDescriptor:samplerDesc];

    MTLSamplerDescriptor *maskSamplerDesc = [MTLSamplerDescriptor new];
    maskSamplerDesc.minFilter = MTLSamplerMinMagFilterNearest;
    maskSamplerDesc.magFilter = MTLSamplerMinMagFilterNearest;
    maskSamplerDesc.sAddressMode = MTLSamplerAddressModeClampToEdge;
    maskSamplerDesc.tAddressMode = MTLSamplerAddressModeClampToEdge;
    _maskSamplerState = [_device newSamplerStateWithDescriptor:maskSamplerDesc];
    
    MTLTextureDescriptor *texDesc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatRGBA8Unorm width:1 height:1 mipmapped:NO];
    texDesc.usage = MTLTextureUsageShaderRead;
    _dummyTexture = [_device newTextureWithDescriptor:texDesc];
    uint32_t whitePixel = 0xFFFFFFFF;
    [_dummyTexture replaceRegion:MTLRegionMake2D(0, 0, 1, 1) mipmapLevel:0 withBytes:&whitePixel bytesPerRow:4];
}

// ── Meshes ──────────────────────────────────────────────────────────

- (void)buildMeshes {
    _assetManager = [[AssetManager alloc] initWithDevice:_device vertexDescriptor:_vertexDescriptor];
    NSString *meshName = [_wrapper vehicleMeshName];
    
    _vehicleMesh = [_assetManager loadMeshNamed:meshName extension:@"obj"];
    if (!_vehicleMesh) _vehicleMesh = [_assetManager generateFallbackCapsule];
    _chromeRoughnessTexture = [_assetManager loadTextureNamed:@"Chrome_Parametric_roughness" extension:@"png"];
    
    _rockMesh     = [_assetManager generateRockMesh];
    _terrainMesh  = [_assetManager generateFallbackPlane];
    
    if (!_terrainMesh) {
        NSLog(@"CRITICAL: terrain mesh is nil!");
    }
}

// ── Draw ────────────────────────────────────────────────────────────

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size { }

- (void)ensureShipMaskTextureForView:(MTKView *)view {
    NSUInteger width = MAX((NSUInteger)view.drawableSize.width, 1);
    NSUInteger height = MAX((NSUInteger)view.drawableSize.height, 1);
    if (_shipMaskTexture && _shipMaskWidth == width && _shipMaskHeight == height) {
        return;
    }

    MTLTextureDescriptor *desc = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatR8Unorm
                                                                                    width:width
                                                                                   height:height
                                                                                mipmapped:NO];
    desc.usage = MTLTextureUsageRenderTarget | MTLTextureUsageShaderRead;
    desc.storageMode = MTLStorageModePrivate;
    _shipMaskTexture = [_device newTextureWithDescriptor:desc];
    _shipMaskTexture.label = @"Ship Screen Mask";
    _shipMaskWidth = width;
    _shipMaskHeight = height;
}

- (void)drawInMTKView:(MTKView *)view {
    NSTimeInterval currentTime = CACurrentMediaTime();
    NSTimeInterval frameDelta = (_lastPresentTime == 0.0) ? (1.0 / 60.0) : (currentTime - _lastPresentTime);
    frameDelta = fmin(fmax(frameDelta, 0.0), 1.0 / 30.0);
    _elapsedTime += frameDelta;
    _lastPresentTime = currentTime;

    id<MTLCommandBuffer> cmdBuf = [_commandQueue commandBuffer];
    MTLRenderPassDescriptor *rpd = view.currentRenderPassDescriptor;
    if (!rpd) { [cmdBuf commit]; return; }
    id<CAMetalDrawable> drawable = view.currentDrawable;
    if (!drawable) { [cmdBuf commit]; return; }
    rpd.stencilAttachment.clearStencil = 0;
    rpd.stencilAttachment.loadAction = MTLLoadActionClear;
    rpd.stencilAttachment.storeAction = MTLStoreActionDontCare;
    
    __block id<MTLRenderCommandEncoder> enc = [cmdBuf renderCommandEncoderWithDescriptor:rpd];
    [enc setRenderPipelineState:_pipelineState];
    [enc setDepthStencilState:_depthState];
    [enc setFrontFacingWinding:MTLWindingCounterClockwise];
    [enc setCullMode:MTLCullModeBack];

    if (!self.previewMode) {
        _engine->update((float)frameDelta);
    }
    
    const Vehicle& vehicle = _engine->getVehicle();
    const Track& track = _engine->getTrack();
    int levelType = self.forcedLevelType >= 0 ? (int)self.forcedLevelType : _engine->getLevelType();
    simd_float3 renderVehiclePosition = vehicle.position;
    if (self.previewMode) {
        float previewSpeed = fmaxf(self.previewScrollSpeed * 1.2f, 1.0f);
        float previewZ = -(float)_elapsedTime * previewSpeed;
        renderVehiclePosition = simd_make_float3(0.0f, vehicle.position.y, previewZ);
    }
    simd_float3 visibleVehiclePosition = renderVehiclePosition + simd_make_float3(0.0f, self.previewMode ? 0.0f : self.vehicleVerticalOffset, 0.0f);
    
    // ── Camera ──────────────────────────────────────────────────────
    simd_float3 desiredCamPos;
    simd_float3 desiredCamTarget;
    if (self.previewMode) {
        desiredCamPos = renderVehiclePosition + simd_make_float3(0.0f, 96.0f, 58.0f);
        desiredCamTarget = renderVehiclePosition;
    } else {
        // Race the Sun style: camera stays locked to the ship so it remains centered on screen.
        desiredCamPos = visibleVehiclePosition + simd_make_float3(0.0f, 96.0f, 58.0f);
        desiredCamTarget = visibleVehiclePosition;
    }
    if (!self.previewMode && vehicle.impactShakeTimer > 0.0f) {
        float shakeAmount = (vehicle.impactShakeTimer / 0.22f);
        simd_float3 shake = simd_make_float3(sinf((float)_elapsedTime * 78.0f),
                                             cosf((float)_elapsedTime * 123.0f),
                                             0.0f) * (1.6f * shakeAmount);
        desiredCamPos += shake;
        desiredCamTarget += shake * 0.45f;
    }
    _smoothCamPos = desiredCamPos;
    _smoothCamTarget = desiredCamTarget;
    _cameraInitialized = true;
    if (!self.previewMode) {
        _engine->setSteeringRestCenter(_smoothCamTarget.x);
    }
    
    if (levelType == 0) {
        view.clearColor = MTLClearColorMake(0.015, 0.025, 0.08, 1.0);
    } else if (levelType == 1) {
        view.clearColor = MTLClearColorMake(0.09, 0.03, 0.015, 1.0);
    } else if (levelType == 2) {
        view.clearColor = MTLClearColorMake(0.01, 0.05, 0.035, 1.0);
    } else {
        view.clearColor = MTLClearColorMake(0.04, 0.04, 0.04, 1.0);
    }
    
    matrix_float4x4 viewMat = matrix_look_at(_smoothCamPos, _smoothCamTarget, simd_make_float3(0,1,0));
    float aspect = (float)view.drawableSize.width / (float)view.drawableSize.height;
    matrix_float4x4 projMat = matrix_perspective(55.0f * (M_PI / 180.0f), aspect, 0.1f, 3000.0f);
    matrix_float4x4 viewProj = simd_mul(projMat, viewMat);

    float terrainOriginZ = track.grid.originZ;
    if (self.previewMode || fabsf(terrainOriginZ) < 0.001f) {
        float colSpacing = TerrainGrid::COLUMN_SPACING;
        terrainOriginZ = floorf((renderVehiclePosition.z + colSpacing * 0.5f) / colSpacing) * colSpacing + 150.0f;
    }
    
    // ── Draw helper ─────────────────────────────────────────────────
    void (^draw)(MTKMesh *, matrix_float4x4, simd_float3, id<MTLTexture>, int, int, int) = ^(MTKMesh *mesh, matrix_float4x4 model, simd_float3 col, id<MTLTexture> tex, int isTerrain, int instanceCount, int renderStyle) {
        Uniforms u;
        u.modelMatrix = model;
        u.viewProjectionMatrix = viewProj;
        u.color = col;
        u.useTexture = (tex != nil) ? 1 : 0;
        u.isTerrain = isTerrain;
        u.slopeAngle = track.slopeAngle;
        u.levelType = levelType;
        u.vehiclePosition = visibleVehiclePosition;
        u.cameraPosition = self->_smoothCamPos;
        u.time = (float)self->_elapsedTime;
        u.chaserZ = vehicle.chaserZ;
        u.vehicleSpeed = simd_length(vehicle.velocity);
        u.isGrazing = vehicle.isGrazing ? 1 : 0;
        u.overdriveCharge = vehicle.overdriveCharge;
        u.renderStyle = renderStyle;
        u.terrainOriginZ = terrainOriginZ;
        u.viewportSize = simd_make_float2((float)view.drawableSize.width, (float)view.drawableSize.height);
        u.outlinePixelWidth = 1.4f;
        u.uniformPadding = 0.0f;
        
        [enc setVertexBytes:&u length:sizeof(u) atIndex:1];
        [enc setFragmentBytes:&u length:sizeof(u) atIndex:1];
        
        if (tex) {
            [enc setFragmentTexture:tex atIndex:0];
        } else {
            [enc setFragmentTexture:self->_dummyTexture atIndex:0];
        }
        [enc setFragmentSamplerState:self->_samplerState atIndex:0];
        
        for (MTKMeshBuffer *vb in mesh.vertexBuffers) {
            [enc setVertexBuffer:vb.buffer offset:vb.offset atIndex:0];
        }
        [enc setVertexBuffer:self->_gridStateBuffer offset:0 atIndex:2];
        for (MTKSubmesh *sub in mesh.submeshes) {
            [enc drawIndexedPrimitives:sub.primitiveType
                            indexCount:sub.indexCount
                             indexType:sub.indexType
                           indexBuffer:sub.indexBuffer.buffer
                     indexBufferOffset:sub.indexBuffer.offset
                         instanceCount:instanceCount];
        }
    };

    // ── Backdrop ──────────────────────────────────────────────────
    // This gives the world an actual atmospheric canvas instead of relying on a flat clear color.
    {
        simd_float3 backdropPos = simd_make_float3(renderVehiclePosition.x, 110.0f, renderVehiclePosition.z - 900.0f);
        matrix_float4x4 backdropModel = matrix_translation(backdropPos);
        matrix_float4x4 backdropScale = matrix_scale(simd_make_float3(1800.0f, 1000.0f, 2.0f));
        draw(_rockMesh, simd_mul(backdropModel, backdropScale), simd_make_float3(1.0f, 1.0f, 1.0f), nil, 0, 1, 3);
    }
    
    // ── Terrain (Hardware Instanced Grid) ─────────────────────────
    // 60 columns wide * 80 columns deep = 4800 instances
    // Upload grid cell state to GPU buffer
    {
        const TerrainGrid& grid = track.grid;
        GridCellGPU* gpuCells = (GridCellGPU*)[_gridStateBuffer contents];
        for (int i = 0; i < TerrainGrid::WIDTH * TerrainGrid::LENGTH; i++) {
            gpuCells[i].flags = grid.cells[i].flags;
            gpuCells[i].collisionTimer = grid.cells[i].collisionEffectTimer;
        }
    }
    
    matrix_float4x4 identity = matrix_translation(simd_make_float3(0, 0, 0));
    // Set grid state buffer at index 2 for the vertex shader
    [enc setVertexBuffer:_gridStateBuffer offset:0 atIndex:2];
    // Single solid terrain pass: every cell is one opaque neon column.
    [enc setCullMode:MTLCullModeBack];
    draw(_rockMesh, identity, simd_make_float3(1,1,1), nil, 1, TerrainGrid::WIDTH * TerrainGrid::LENGTH, 0);

    // ── Chaser wall ───────────────────────────────────────────────
    [enc setRenderPipelineState:_blendPipelineState];
    [enc setDepthStencilState:_transparentDepthState];
    [enc setCullMode:MTLCullModeNone];
    if (self.showsChaser) {
        float chaserTopY = visibleVehiclePosition.y * 1.2f;
        float chaserBottomY = -20.0f;
        float chaserHeight = fmaxf(12.0f, chaserTopY - chaserBottomY);
        float chaserCenterY = chaserBottomY + chaserHeight * 0.5f;
        simd_float3 chaserPos = simd_make_float3(renderVehiclePosition.x, chaserCenterY, vehicle.chaserZ);
        matrix_float4x4 chaserTrans = matrix_translation(chaserPos);
        matrix_float4x4 chaserScale = matrix_scale(simd_make_float3(125.0f, chaserHeight, 1.2f));
        matrix_float4x4 chaserModel = simd_mul(chaserTrans, chaserScale);
        draw(_rockMesh, chaserModel, simd_make_float3(1.0f, 1.0f, 1.0f), nil, 0, 1, 5);
    }
    [enc setRenderPipelineState:_pipelineState];
    [enc setDepthStencilState:_depthState];
    [enc setCullMode:MTLCullModeBack];
    
    // Decorative landmark cubes are disabled for the baseline pass so only streamed grid terrain is visible.

    // ── Speed streaks ──────────────────────────────────────────────
    if (!self.previewMode && self.showsVehicle && !vehicle.isDestroyed) {
        [enc setRenderPipelineState:_blendPipelineState];
        [enc setDepthStencilState:_overlayDepthState];
        [enc setCullMode:MTLCullModeNone];

        float speedAmount = fminf(fmaxf((simd_length(vehicle.velocity) - 85.0f) / 170.0f, 0.0f), 1.0f);
        int streakCount = 34 + (int)roundf(speedAmount * 22.0f);
        float recycleDistance = 235.0f;
        float flow = fmodf((float)_elapsedTime * (140.0f + simd_length(vehicle.velocity) * 1.25f), recycleDistance);
        for (int i = 0; i < streakCount; i++) {
            float seed = (float)i * 12.9898f;
            float lane = sinf(seed * 0.47f) * 0.5f + 0.5f;
            float side = cosf(seed * 1.73f) < 0.0f ? -1.0f : 1.0f;
            float x = visibleVehiclePosition.x + side * (6.0f + lane * 44.0f);
            float y = visibleVehiclePosition.y + 1.5f + (sinf(seed * 0.61f) * 0.5f + 0.5f) * 13.0f;
            float phase = fmodf((float)i * 37.0f - flow, recycleDistance);
            if (phase < 0.0f) {
                phase += recycleDistance;
            }
            float z = renderVehiclePosition.z - (18.0f + phase);

            float length = 58.0f + speedAmount * 62.0f;
            float thickness = 0.55f + speedAmount * 0.35f;
            matrix_float4x4 streakModel = simd_mul(matrix_translation(simd_make_float3(x, y, z)),
                                                   matrix_scale(simd_make_float3(thickness, thickness * 0.42f, length)));
            draw(_rockMesh, streakModel, levelType == 1 ? simd_make_float3(1.0f, 0.62f, 0.18f) : simd_make_float3(0.55f, 0.96f, 1.0f), nil, 0, 1, 6);
        }

        [enc setRenderPipelineState:_pipelineState];
        [enc setDepthStencilState:_depthState];
        [enc setCullMode:MTLCullModeBack];
    }
    
    // ── Obstacles (rocks) ───────────────────────────────────────────
    if (self.showsObstacles) {
        for (const auto& obs : track.obstacles) {
            if (obs.position.z > renderVehiclePosition.z + 30.0f) continue;
            if (obs.position.z < renderVehiclePosition.z - 200.0f) continue;
            
            matrix_float4x4 model = matrix_translation(obs.position + simd_make_float3(0, 0.8f, 0));
            matrix_float4x4 obsScale = matrix_scale(simd_make_float3(1.8f, 1.5f, 1.8f));
            
            simd_float3 col;
            if (levelType == 0) col = simd_make_float3(0.1f, 0.9f, 0.3f);       // Neon Green rock
            else if (levelType == 1) col = simd_make_float3(0.9f, 0.1f, 0.1f);   // Neon Red rock
            else col = simd_make_float3(0.1f, 0.5f, 0.9f);                       // Neon Blue rock
            
            if (obs.hasCollided) col *= 0.4f;
            draw(_rockMesh, simd_mul(model, obsScale), col, nil, 0, 1, 0);
        }
    }
    
    // ── Vehicle ─────────────────────────────────────────────────────
    bool renderedVehicle = false;
    matrix_float4x4 vehicleMaskModel = matrix_translation(simd_make_float3(0.0f, 0.0f, 0.0f));
    if (self.showsVehicle) {
        // Render-only steering attitude: make the hull face into turns without changing physics.
        float yaw = M_PI;
        float visualLateralSpeed = vehicle.velocity.x * 1.35f;
        float horizontalSpeedSq = visualLateralSpeed * visualLateralSpeed + vehicle.velocity.z * vehicle.velocity.z;
        if (horizontalSpeedSq > 0.01f) {
            yaw = atan2f(visualLateralSpeed, vehicle.velocity.z);
        }
        
        matrix_float4x4 vehScale = matrix_scale(simd_make_float3(0.8f, 0.8f, 0.8f));
        matrix_float4x4 vehRotY = matrix_rotation_y(yaw);
        matrix_float4x4 vehTrans = matrix_translation(visibleVehiclePosition + simd_make_float3(0, 0.25f, 0));
        matrix_float4x4 vehModel = simd_mul(vehTrans, simd_mul(vehRotY, vehScale));
        // Draw the Chrome material ship body and mark its pixels in stencil.
        simd_float3 vehCol = vehicle.isDestroyed
            ? simd_make_float3(0.38f, 0.38f, 0.40f)
            : simd_make_float3(1.0f, 1.0f, 1.0f);
        [enc setRenderPipelineState:_shipPipelineState];
        [enc setDepthStencilState:_vehicleBodyStencilDepthState];
        [enc setStencilReferenceValue:1];
        [enc setCullMode:MTLCullModeBack];
        draw(_vehicleMesh, vehModel, vehCol, _chromeRoughnessTexture, 0, 1, 1);
        renderedVehicle = true;
        vehicleMaskModel = vehModel;

        [enc setStencilReferenceValue:0];
        [enc setRenderPipelineState:_pipelineState];
        [enc setDepthStencilState:_depthState];
        [enc setCullMode:MTLCullModeBack];
    }
    
    [enc endEncoding];

    if (renderedVehicle) {
        [self ensureShipMaskTextureForView:view];

        MTLRenderPassDescriptor *maskPass = [MTLRenderPassDescriptor renderPassDescriptor];
        maskPass.colorAttachments[0].texture = _shipMaskTexture;
        maskPass.colorAttachments[0].loadAction = MTLLoadActionClear;
        maskPass.colorAttachments[0].storeAction = MTLStoreActionStore;
        maskPass.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0);

        enc = [cmdBuf renderCommandEncoderWithDescriptor:maskPass];
        [enc setRenderPipelineState:_shipMaskPipelineState];
        [enc setCullMode:MTLCullModeBack];
        draw(_vehicleMesh, vehicleMaskModel, simd_make_float3(1.0f, 1.0f, 1.0f), nil, 0, 1, 1);
        [enc endEncoding];

        MTLRenderPassDescriptor *outlinePass = [MTLRenderPassDescriptor renderPassDescriptor];
        outlinePass.colorAttachments[0].texture = drawable.texture;
        outlinePass.colorAttachments[0].loadAction = MTLLoadActionLoad;
        outlinePass.colorAttachments[0].storeAction = MTLStoreActionStore;

        Uniforms outlineUniforms;
        memset(&outlineUniforms, 0, sizeof(outlineUniforms));
        outlineUniforms.viewportSize = simd_make_float2((float)view.drawableSize.width, (float)view.drawableSize.height);
        outlineUniforms.outlinePixelWidth = 1.0f;

        enc = [cmdBuf renderCommandEncoderWithDescriptor:outlinePass];
        [enc setRenderPipelineState:_shipOutlineCompositePipelineState];
        [enc setFragmentBytes:&outlineUniforms length:sizeof(outlineUniforms) atIndex:1];
        [enc setFragmentTexture:_shipMaskTexture atIndex:0];
        [enc setFragmentSamplerState:_maskSamplerState atIndex:0];
        [enc drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
        [enc endEncoding];
    }

    [cmdBuf presentDrawable:drawable];
    [cmdBuf commit];
}

@end
