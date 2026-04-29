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
    id<MTLDepthStencilState> _depthState;
    MTLVertexDescriptor *_vertexDescriptor;
    id<MTLSamplerState> _samplerState;
    id<MTLTexture> _dummyTexture;
    
    MTKMesh *_vehicleMesh;
    id<MTLTexture> _vehicleTexture;
    
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
    
    _pipelineState = [_device newRenderPipelineStateWithDescriptor:desc error:&error];
    NSAssert(_pipelineState, @"Failed to create pipeline state: %@", error);
    
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
    NSString *textureName = [_wrapper vehicleTextureName];
    
    _vehicleMesh = [_assetManager loadMeshNamed:meshName extension:@"obj"];
    if (!_vehicleMesh) _vehicleMesh = [_assetManager generateFallbackCapsule];
    
    _vehicleTexture = [_assetManager loadTextureNamed:textureName extension:@"png"];
    
    _rockMesh     = [_assetManager generateRockMesh];
    _terrainMesh  = [_assetManager generateFallbackPlane];
    
    if (!_terrainMesh) {
        NSLog(@"CRITICAL: terrain mesh is nil!");
    }
}

// ── Draw ────────────────────────────────────────────────────────────

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size { }

- (void)drawInMTKView:(MTKView *)view {
    NSTimeInterval currentTime = CACurrentMediaTime();
    if (_lastPresentTime == 0.0) _lastPresentTime = currentTime;
    _elapsedTime += (currentTime - _lastPresentTime);
    _lastPresentTime = currentTime;

    id<MTLCommandBuffer> cmdBuf = [_commandQueue commandBuffer];
    MTLRenderPassDescriptor *rpd = view.currentRenderPassDescriptor;
    if (!rpd) { [cmdBuf commit]; return; }
    rpd.stencilAttachment.clearStencil = 0;
    rpd.stencilAttachment.loadAction = MTLLoadActionClear;
    rpd.stencilAttachment.storeAction = MTLStoreActionDontCare;
    
    id<MTLRenderCommandEncoder> enc = [cmdBuf renderCommandEncoderWithDescriptor:rpd];
    [enc setRenderPipelineState:_pipelineState];
    [enc setDepthStencilState:_depthState];
    [enc setFrontFacingWinding:MTLWindingCounterClockwise];
    [enc setCullMode:MTLCullModeBack];
    
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
        desiredCamPos = renderVehiclePosition + simd_make_float3(0.0f, 148.0f, 86.0f);
        desiredCamTarget = renderVehiclePosition + simd_make_float3(0.0f, -52.0f, -38.0f);
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
        u.outlinePixelWidth = 1.0f;
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
    if (self.showsVehicle) {
        float yaw = M_PI;
        if (simd_length(vehicle.velocity) > 0.1f) {
            yaw = atan2f(vehicle.velocity.x, vehicle.velocity.z);
        }
        
        matrix_float4x4 vehScale = matrix_scale(simd_make_float3(0.8f, 0.8f, 0.8f));
        matrix_float4x4 vehRotY = matrix_rotation_y(yaw);
        matrix_float4x4 vehTrans = matrix_translation(visibleVehiclePosition + simd_make_float3(0, 0.5f, 0));
        matrix_float4x4 vehModel = simd_mul(vehTrans, simd_mul(vehRotY, vehScale));
        // Level-tinted base color instead of flat white — ensures ship isn't washed out
        simd_float3 vehCol;
        if (vehicle.isDestroyed) {
            vehCol = simd_make_float3(0.3f, 0.3f, 0.3f);
        } else if (levelType == 0) {
            vehCol = simd_make_float3(0.52f, 0.78f, 0.92f); // cool cyan-steel
        } else if (levelType == 1) {
            vehCol = simd_make_float3(0.92f, 0.68f, 0.48f); // warm amber-steel
        } else if (levelType == 2) {
            vehCol = simd_make_float3(0.52f, 0.88f, 0.68f); // mint-steel
        } else {
            vehCol = simd_make_float3(0.72f, 0.72f, 0.78f); // neutral steel
        }
        // Draw the opaque textured/tinted ship body and mark its pixels in stencil.
        [enc setRenderPipelineState:_pipelineState];
        [enc setDepthStencilState:_vehicleBodyStencilDepthState];
        [enc setStencilReferenceValue:1];
        [enc setCullMode:MTLCullModeBack];
        draw(_vehicleMesh, vehModel, vehCol, _vehicleTexture, 0, 1, 1);

        // Draw a 1-pixel black stencil outline after the body, only outside body pixels.
        [enc setRenderPipelineState:_pipelineState];
        [enc setDepthStencilState:_vehicleOutlineStencilDepthState];
        [enc setStencilReferenceValue:1];
        [enc setCullMode:MTLCullModeFront];
        draw(_vehicleMesh, vehModel, simd_make_float3(0.0f, 0.0f, 0.0f), nil, 0, 1, 4);

        [enc setStencilReferenceValue:0];
        [enc setRenderPipelineState:_pipelineState];
        [enc setDepthStencilState:_depthState];
        [enc setCullMode:MTLCullModeBack];
    }
    
    [enc endEncoding];
    [cmdBuf presentDrawable:view.currentDrawable];
    [cmdBuf commit];
}

@end
