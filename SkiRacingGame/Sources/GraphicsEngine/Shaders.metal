#include <metal_stdlib>
using namespace metal;

struct VertexIn {
    float3 position [[attribute(0)]];
    float3 normal   [[attribute(1)]];
    float2 texCoord [[attribute(2)]];
};

struct VertexOut {
    float4 position [[position]];
    float3 worldNormal;
    float3 terrainTopNormal;
    float3 worldPosition;
    float3 localPosition;
    float2 texCoord;
    float2 cellCenterXZ;
    uint cellFlags; // reserved; active baseline keeps every terrain cell opaque
    float collisionTimer;
    uint edgeExposure; // reserved for future explicit edge mesh/line pass
};

struct Uniforms {
    float4x4 modelMatrix;
    float4x4 viewProjectionMatrix;
    float3 color;
    int useTexture;
    int isTerrain;
    float slopeAngle;
    int levelType;
    float3 vehiclePosition;
    float3 cameraPosition;
    float time;
    float chaserZ; // Z position of the chaser wall
    float vehicleSpeed;
    int isGrazing;
    float overdriveCharge;
    int renderStyle;
    float terrainOriginZ;
    float2 viewportSize;
    float outlinePixelWidth;
    float uniformPadding;
};

// Per-instance grid cell state passed from CPU
struct GridCellGPU {
    uint16_t flags;
    float collisionTimer;
};

constant float RIVER_CURVE_SCALE = 0.92;
constant float RIVER_PRIMARY_FREQUENCY = 0.0074;
constant float RIVER_SECONDARY_FREQUENCY = 0.021;

// ── Helpers ──────────────────────────────────────────────────────

// Convert HSV to RGB
float3 hsv2rgb(float3 c) {
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// ── Terrain Logic Helpers ────────────────────────────────────────

float getDistFromRiverMetal(float gridX, float gridZ) {
    const float kRiverPlayableHalfWidth = 100.0;
    const float kRiverTransitionWidth = 40.0;
    const float kRiverCenterLimit = kRiverPlayableHalfWidth - kRiverTransitionWidth;
    float riverBaseX = (sin(gridZ * RIVER_PRIMARY_FREQUENCY) * (31.0 * RIVER_CURVE_SCALE) +
                        sin(gridZ * RIVER_SECONDARY_FREQUENCY + 0.9) * (16.0 * RIVER_CURVE_SCALE));

    return abs(gridX - clamp(riverBaseX, -kRiverCenterLimit, kRiverCenterLimit));
}

// Improved hash — better distribution, less pattern
float2 hash2(float2 p) {
    p = float2(dot(p, float2(127.1, 311.7)),
               dot(p, float2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

float hash(float2 p) {
    p = fract(p * 0.3183099 + 0.1);
    p *= 17.0;
    return fract(p.x * p.y * (p.x + p.y));
}

// Value noise with analytical derivatives (returns float3: x=value, yz=derivatives)
float3 noised(float2 x) {
    float2 i = floor(x);
    float2 f = fract(x);
    // Quintic interpolation and its derivative
    float2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    float2 du = 30.0 * f * f * (f * (f - 2.0) + 1.0);

    float a = hash(i + float2(0.0, 0.0));
    float b = hash(i + float2(1.0, 0.0));
    float c = hash(i + float2(0.0, 1.0));
    float d = hash(i + float2(1.0, 1.0));

    float k0 = a;
    float k1 = b - a;
    float k2 = c - a;
    float k4 = a - b - c + d;

    float value = k0 + k1 * u.x + k2 * u.y + k4 * u.x * u.y;
    float2 deriv = du * float2(k1 + k4 * u.y, k2 + k4 * u.x);

    return float3(value, deriv);
}

// Simple value noise (no derivatives)
float noise(float2 x) {
    float2 i = floor(x);
    float2 f = fract(x);
    float2 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
    return mix(mix(hash(i + float2(0.0, 0.0)), hash(i + float2(1.0, 0.0)), u.x),
               mix(hash(i + float2(0.0, 1.0)), hash(i + float2(1.0, 1.0)), u.x), u.y);
}

// ── Derivative-aware FBM (erosion-like dampening on slopes) ───────
// Returns float3: x=height, yz=accumulated derivatives
float3 fbm_d(float2 x, int octaves) {
    float f = 1.0;
    float a = 0.5;
    float t = 0.0;
    float2 d = float2(0.0);
    float2x2 rot = float2x2(cos(0.5), sin(0.5), -sin(0.5), cos(0.5));

    for (int i = 0; i < octaves; i++) {
        float3 n = noised(x * f);
        // Dampen amplitude based on accumulated slope (erosion simulation)
        float slopeAttenuation = 1.0 / (1.0 + dot(d, d));
        t += a * n.x * slopeAttenuation;
        d += a * n.yz * f;
        f *= 2.0;
        a *= 0.5;
        x = rot * x + float2(100.0);
    }
    return float3(t, d);
}

// ── Ridged noise FBM ─────────────────────────────────────────────
// Creates sharp mountain ridges: 1 - abs(noise) then squared
float fbm_ridged(float2 x, int octaves) {
    float f = 1.0;
    float a = 0.5;
    float t = 0.0;
    float prev = 1.0;
    float2x2 rot = float2x2(cos(0.5), sin(0.5), -sin(0.5), cos(0.5));

    for (int i = 0; i < octaves; i++) {
        float n = noise(x * f);
        n = 1.0 - abs(n * 2.0 - 1.0); // ridge
        n = n * n;                      // sharpen
        t += a * n * prev;             // dependency on previous octave
        prev = n;
        f *= 2.0;
        a *= 0.5;
        x = rot * x + float2(100.0);
    }
    return t;
}

// ── Domain warping ───────────────────────────────────────────────
// Offsets FBM input by another FBM sample — creates organic gullies/swirls
float fbm_warped(float2 x, int octaves) {
    // First pass: compute warp offset
    float2 warpOffset;
    warpOffset.x = noise(x * 0.7 + float2(1.7, 9.2));
    warpOffset.y = noise(x * 0.7 + float2(8.3, 2.8));
    // Apply warp
    float2 warped = x + warpOffset * 1.5;
    return fbm_d(warped, octaves).x;
}

// ── Simple FBM (for fragment micro-detail) ───────────────────────
float fbm_simple(float2 x, int octaves) {
    float v = 0.0;
    float a = 0.5;
    float2x2 rot = float2x2(cos(0.5), sin(0.5), -sin(0.5), cos(0.5));
    for (int i = 0; i < octaves; i++) {
        v += a * noise(x);
        x = rot * x * 2.0 + float2(100.0);
        a *= 0.5;
    }
    return v;
}

// ── Terrain height (must match CPU MathUtils::getTerrainHeight) ──
float terrainHeight(float2 xz, float slopeAngle) {
    float colSpacing = 5.0;
    float gridX = floor((xz.x + colSpacing*0.5) / colSpacing) * colSpacing;
    float gridZ = floor((xz.y + colSpacing*0.5) / colSpacing) * colSpacing;
    
    // Geometry Wars style: more turbulent, jagged procedural noise (pure FBM)
    float2 tc = float2(gridX * 0.04, gridZ * 0.04);
    
    // Mountains are rugged and high
    float h_mountain = fbm_simple(tc, 4) * 45.0 + 10.0; // 10 to 55 height
    
    // River path has noticeable but short noise (max 1/3 the 15 unit depth -> 5 units amplitude)
    float h_river = fbm_simple(tc, 2) * 2.5 - 17.5; // approx -17.5 to -12.5 height
    
    // Blend them based on distance from the river centerline
    float distFromCenter = getDistFromRiverMetal(gridX, gridZ);
    
    // Path is 15 units wide (flat riverbed, total width 30), then sharply rising to mountain
    float pathMix = smoothstep(15.0, 40.0, distFromCenter);
    
    float finalHeight = mix(h_river, h_mountain, pathMix);
    
    // Quantize height blocks (stair step effect)
    return floor(finalHeight * 0.5) * 2.0;
}

float3 terrainTopNormalAtCell(float2 centerXZ, float slopeAngle) {
    float sampleStep = 5.0;
    float hL = terrainHeight(centerXZ + float2(-sampleStep, 0.0), slopeAngle);
    float hR = terrainHeight(centerXZ + float2(sampleStep, 0.0), slopeAngle);
    float hD = terrainHeight(centerXZ + float2(0.0, -sampleStep), slopeAngle);
    float hU = terrainHeight(centerXZ + float2(0.0, sampleStep), slopeAngle);
    return normalize(float3(hL - hR, sampleStep * 2.0, hD - hU));
}

// ── Vertex ─────────────────────────────────────────────────────────
vertex VertexOut vertex_main(VertexIn in [[stage_in]],
                             constant Uniforms &uniforms [[buffer(1)]],
                             constant GridCellGPU *gridState [[buffer(2)]],
                             uint instance_id [[instance_id]]) {
    VertexOut out;

    if (uniforms.isTerrain == 1) {
        // Grid config
        int colsWide = 60;
        int gridX_idx = (int)(instance_id % colsWide) - (colsWide / 2);
        int gridZ_idx = (int)(instance_id / colsWide); // 0 to 79

        float colSpacing = 5.0;
        
        // CPU and GPU both anchor streamed terrain to this origin so visible cells stay locked to world positions.
        float worldCenterX = gridX_idx * colSpacing;
        float worldCenterZ = uniforms.terrainOriginZ - (gridZ_idx * colSpacing);
        
        float h = terrainHeight(float2(worldCenterX, worldCenterZ), uniforms.slopeAngle);
        
        GridCellGPU cell = gridState[instance_id];
        out.cellFlags = cell.flags & 0u;
        out.collisionTimer = cell.collisionTimer;
        out.cellCenterXZ = float2(worldCenterX, worldCenterZ);
        out.terrainTopNormal = terrainTopNormalAtCell(out.cellCenterXZ, uniforms.slopeAngle);
        
        // Pre-compute neighbor heights for edge exposure (moved from fragment shader)
        float colSpacingV = 5.0;
        float hPosX_v = terrainHeight(float2(worldCenterX + colSpacingV, worldCenterZ), uniforms.slopeAngle);
        float hNegX_v = terrainHeight(float2(worldCenterX - colSpacingV, worldCenterZ), uniforms.slopeAngle);
        float hPosZ_v = terrainHeight(float2(worldCenterX, worldCenterZ + colSpacingV), uniforms.slopeAngle);
        float hNegZ_v = terrainHeight(float2(worldCenterX, worldCenterZ - colSpacingV), uniforms.slopeAngle);
        uint exposure = 0;
        if (hPosX_v + 0.75 < h) exposure |= 1u;
        if (hNegX_v + 0.75 < h) exposure |= 2u;
        if (hPosZ_v + 0.75 < h) exposure |= 4u;
        if (hNegZ_v + 0.75 < h) exposure |= 8u;
        out.edgeExposure = exposure;
        
        float4 worldPos;
        float tileSize = colSpacing * 1.012;
        worldPos.x = worldCenterX + in.position.x * tileSize;
        worldPos.z = worldCenterZ + in.position.z * tileSize;

        float topY = h;
        float bottomY = -50.0;
        
        if (in.position.y > 0.0) {
            worldPos.y = topY;
        } else {
            worldPos.y = bottomY;
        }

        float collisionProgress = saturate(1.0 - (out.collisionTimer / 0.5));
        float collisionPop = sin(collisionProgress * 3.14159265) * 4.0;
        worldPos.y += collisionPop;
        worldPos.w = 1.0;
        
        out.position = uniforms.viewProjectionMatrix * worldPos;
        out.worldPosition = worldPos.xyz;
        out.localPosition = in.position;
        // Pack column top height into texCoord.y for fragment elevation gradient
        out.texCoord = float2(in.texCoord.x, h);
        out.worldNormal = in.normal;
    } else {
        out.cellFlags = 0;
        out.cellCenterXZ = float2(0.0);
        out.terrainTopNormal = float3(0.0, 1.0, 0.0);
        out.collisionTimer = 0.0;
        out.edgeExposure = 0;
        float4 worldPos = uniforms.modelMatrix * float4(in.position, 1.0);
        float3 worldNormal = normalize((uniforms.modelMatrix * float4(in.normal, 0.0)).xyz);
        float4 clipPos = uniforms.viewProjectionMatrix * worldPos;
        if (uniforms.renderStyle == 4) {
            float4 normalClipPos = uniforms.viewProjectionMatrix * float4(worldPos.xyz + worldNormal, 1.0);
            float2 clipNDC = clipPos.xy / max(abs(clipPos.w), 0.0001);
            float2 normalNDC = normalClipPos.xy / max(abs(normalClipPos.w), 0.0001);
            float2 outlineDir = normalNDC - clipNDC;
            if (length(outlineDir) < 0.0001) {
                outlineDir = float2(0.0, 1.0);
            } else {
                outlineDir = normalize(outlineDir);
            }
            float2 pixelSizeNDC = 2.0 / max(uniforms.viewportSize, float2(1.0));
            clipPos.xy += outlineDir * pixelSizeNDC * uniforms.outlinePixelWidth * clipPos.w;
        }
        out.position = clipPos;
        out.worldPosition = worldPos.xyz;
        out.localPosition = in.position;
        out.texCoord = in.texCoord;
        out.worldNormal = worldNormal;
    }

    return out;
}

/*
// ═══════════════════════════════════════════════════════════════════
// ── PBR Helpers (Mobile-optimised Cook-Torrance) ──────────────────
// Disabled for now. The baseline renderer uses simple Phong shading
// until geometry, culling, and material readability are stable.
// ═══════════════════════════════════════════════════════════════════

// GGX / Trowbridge-Reitz Normal Distribution Function
float DistributionGGX(float NdotH, float roughness) {
    float a  = roughness * roughness;
    float a2 = a * a;
    float NdotH2 = NdotH * NdotH;
    float denom  = NdotH2 * (a2 - 1.0) + 1.0;
    return a2 / (PI * denom * denom + 0.0001);
}

// Schlick approximation for Fresnel
float3 FresnelSchlick(float cosTheta, float3 F0) {
    return F0 + (1.0 - F0) * pow(clamp(1.0 - cosTheta, 0.0, 1.0), 5.0);
}

// Schlick-GGX geometry function (single direction)
float GeometrySchlickGGX(float NdotV, float roughness) {
    float r = roughness + 1.0;
    float k = (r * r) / 8.0;
    return NdotV / (NdotV * (1.0 - k) + k + 0.0001);
}

// Smith's method combining both view and light directions
float GeometrySmith(float NdotV, float NdotL, float roughness) {
    return GeometrySchlickGGX(NdotV, roughness) * GeometrySchlickGGX(NdotL, roughness);
}

// Full PBR lighting for a single directional light
// Returns lit color (diffuse + specular combined with energy conservation)
float3 pbrDirectionalLight(float3 albedo,
                           float metallic,
                           float roughness,
                           float3 N,
                           float3 V,
                           float3 L,
                           float3 lightColor,
                           float lightIntensity) {
    float3 H = normalize(V + L);
    
    float NdotL = max(dot(N, L), 0.0);
    float NdotV = max(dot(N, V), 0.001);
    float NdotH = max(dot(N, H), 0.0);
    float VdotH = max(dot(V, H), 0.0);
    
    // F0: base reflectivity (dielectrics ~0.04, metals use albedo)
    float3 F0 = mix(float3(0.04), albedo, metallic);
    
    // Cook-Torrance specular BRDF components
    float  D = DistributionGGX(NdotH, roughness);
    float3 F = FresnelSchlick(VdotH, F0);
    float  G = GeometrySmith(NdotV, NdotL, roughness);
    
    float3 numerator  = D * F * G;
    float  denominator = 4.0 * NdotV * NdotL + 0.0001;
    float3 specular = numerator / denominator;
    
    // Energy conservation: diffuse component is reduced by what's reflected
    float3 kD = (float3(1.0) - F) * (1.0 - metallic);
    
    // Lambertian diffuse
    float3 diffuse = kD * albedo / PI;
    
    return (diffuse + specular) * lightColor * lightIntensity * NdotL;
}
*/

float3 phongDirectionalLight(float3 albedo,
                             float3 N,
                             float3 V,
                             float3 L,
                             float3 lightColor,
                             float lightIntensity,
                             float shininess,
                             float specularStrength) {
    float NdotL = max(dot(N, L), 0.0);
    float3 diffuse = albedo * NdotL;
    float3 R = reflect(-L, N);
    float specular = pow(max(dot(R, V), 0.0), shininess) * specularStrength;
    return (diffuse + float3(specular)) * lightColor * lightIntensity;
}

// ═══════════════════════════════════════════════════════════════════
// ── Fragment ───────────────────────────────────────────────────────
// ═══════════════════════════════════════════════════════════════════

float3 levelFogColor(int levelType) {
    if (levelType == 0) return float3(0.06, 0.12, 0.24); // neon synthwave
    if (levelType == 1) return float3(0.22, 0.11, 0.05); // fiery retrowave
    if (levelType == 2) return float3(0.05, 0.16, 0.11); // cyberpunk void
    return float3(0.08, 0.08, 0.08);                     // debug
}

float3 levelKeyTint(int levelType) {
    if (levelType == 0) return float3(0.42, 0.92, 1.00);
    if (levelType == 1) return float3(1.00, 0.66, 0.28);
    if (levelType == 2) return float3(0.56, 1.00, 0.48);
    return float3(1.00, 1.00, 1.00);
}

float3 levelGlowTint(int levelType) {
    if (levelType == 0) return float3(0.14, 1.00, 1.00);
    if (levelType == 1) return float3(1.00, 0.52, 0.14);
    if (levelType == 2) return float3(0.34, 1.00, 0.58);
    return float3(1.00, 1.00, 1.00);
}

float3 levelTerrainBaseColor(int levelType) {
    if (levelType == 0) return float3(0.10, 0.46, 0.62);
    if (levelType == 1) return float3(0.72, 0.28, 0.08);
    if (levelType == 2) return float3(0.12, 0.50, 0.28);
    return float3(0.42, 0.42, 0.46);
}

float2 levelFogRange(int levelType) {
    if (levelType == 0) return float2(55.0, 260.0);
    if (levelType == 1) return float2(45.0, 230.0);
    if (levelType == 2) return float2(50.0, 245.0);
    return float2(70.0, 290.0);
}

float3 terrainElevationColor(float t, int levelType) {
    float3 c0;
    float3 c1;
    float3 c2;
    float3 c3;
    float3 c4;
    if (levelType == 0) {
        // Neon synthwave: deep indigo → electric cyan → hot magenta
        c0 = float3(0.02, 0.03, 0.18);
        c1 = float3(0.06, 0.14, 0.42);
        c2 = float3(0.04, 0.62, 0.82);
        c3 = float3(0.72, 0.16, 0.64);
        c4 = float3(0.92, 0.52, 0.88);
    } else if (levelType == 1) {
        // Fiery retrowave: deep crimson → molten orange → bright gold
        c0 = float3(0.12, 0.02, 0.02);
        c1 = float3(0.32, 0.06, 0.04);
        c2 = float3(0.72, 0.18, 0.05);
        c3 = float3(0.92, 0.48, 0.08);
        c4 = float3(1.00, 0.82, 0.32);
    } else if (levelType == 2) {
        // Cyberpunk void: dark teal → neon green → bright mint
        c0 = float3(0.01, 0.06, 0.05);
        c1 = float3(0.03, 0.16, 0.12);
        c2 = float3(0.12, 0.64, 0.28);
        c3 = float3(0.38, 0.92, 0.54);
        c4 = float3(0.72, 1.00, 0.82);
    } else {
        c0 = float3(0.08, 0.08, 0.10);
        c1 = float3(0.18, 0.18, 0.22);
        c2 = float3(0.36, 0.36, 0.42);
        c3 = float3(0.62, 0.62, 0.68);
        c4 = float3(0.86, 0.86, 0.90);
    }
    if      (t < 0.25) return mix(c0, c1, t / 0.25);
    else if (t < 0.50) return mix(c1, c2, (t - 0.25) / 0.25);
    else if (t < 0.75) return mix(c2, c3, (t - 0.50) / 0.25);
    return mix(c3, c4, (t - 0.75) / 0.25);
}

float3 applyLevelGrade(float3 color, int levelType) {
    float3 graded = color;
    if (levelType == 0) {
        graded = pow(max(graded, float3(0.0)), float3(0.92));
        graded *= float3(0.96, 1.02, 1.08);
    } else if (levelType == 1) {
        graded = pow(max(graded, float3(0.0)), float3(0.96));
        graded *= float3(1.08, 0.97, 0.90);
    } else if (levelType == 2) {
        graded = pow(max(graded, float3(0.0)), float3(0.94));
        graded *= float3(0.92, 1.06, 0.95);
    } else {
        graded *= float3(0.98);
    }
    float luma = dot(graded, float3(0.299, 0.587, 0.114));
    graded = mix(float3(luma), graded, 1.10);
    graded = (graded - 0.5) * 1.07 + 0.5;
    return saturate(graded);
}

fragment float4 fragment_main(VertexOut in [[stage_in]],
                              constant Uniforms &uniforms [[buffer(1)]],
                              texture2d<float> colorTexture [[texture(0)]],
                              sampler textureSampler [[sampler(0)]]) {
    float3 viewDir = normalize(uniforms.cameraPosition - in.worldPosition + float3(0.001, 0.001, 0.001));
    float3 keyTint = levelKeyTint(uniforms.levelType);
    float3 glowTint = levelGlowTint(uniforms.levelType);
    float3 fogBaseColor = levelFogColor(uniforms.levelType);

    // ── Scene light setup (shared by terrain + objects) ──────────
    float3 keyLightDir   = normalize(float3(0.55, 1.0, -0.35));
    float3 fillLightDir  = normalize(float3(-0.35, 0.6, 0.55));
    float3 keyLightColor = float3(1.0, 0.98, 0.94);  // warm white
    float3 fillLightColor = float3(0.6, 0.7, 0.85);  // cool fill

    // ── Render style early-outs (silhouette, chaser wall, skybox) ──
    if (uniforms.renderStyle == 4) {
        return float4(0.0, 0.0, 0.0, 1.0);
    }

    if (uniforms.renderStyle == 5) {
        float topEdge = smoothstep(0.40, 0.47, in.localPosition.y);
        float centerBias = 1.0 - saturate(abs(in.localPosition.x) / 0.5);
        float subtleBands = 0.94 + 0.06 * sin(in.worldPosition.x * 0.22 + uniforms.time * 6.0);
        float3 wallColor = float3(1.0, 0.05, 0.06) * subtleBands;
        wallColor += float3(1.0, 0.16, 0.10) * centerBias * 0.22;
        wallColor += float3(1.0, 0.42, 0.18) * topEdge * 0.55;
        return float4(applyLevelGrade(saturate(wallColor), uniforms.levelType), mix(0.50, 1.0, topEdge));
    }

    if (uniforms.renderStyle == 3) {
        float skyV = saturate((in.worldPosition.y + 120.0) / 240.0);
        float skyU = in.worldPosition.x * 0.0025;
        float3 zenith = fogBaseColor * 0.52 + keyTint * 0.22;
        float3 horizon = fogBaseColor * 0.11 + glowTint * 0.52 + float3(0.03, 0.025, 0.04);
        float3 color = mix(horizon, zenith, pow(skyV, 1.25));
        float bands = 0.5 + 0.5 * sin(skyU * 8.0 + uniforms.time * 0.18);
        float scan = 0.5 + 0.5 * sin(in.worldPosition.y * 0.05 - uniforms.time * 0.32);
        float horizonGlow = pow(1.0 - abs(skyV - 0.30), 4.0);
        color += glowTint * bands * 0.11;
        color += float3(1.0, 0.9, 1.0) * scan * horizonGlow * 0.05;
        color += glowTint * horizonGlow * 0.24;
        return float4(applyLevelGrade(saturate(color), uniforms.levelType), 1.0);
    }

    float3 baseColor = uniforms.color;

    if (uniforms.useTexture == 1) {
        float3 textureColor = colorTexture.sample(textureSampler, in.texCoord).rgb;
        baseColor = textureColor * (float3(0.78) + uniforms.color * 0.22);
    }

    float3 finalColor = baseColor;

    // ═════════════════════════════════════════════════════════════
    // ── TERRAIN: simple Phong shading ───────────────────────────
    // ═════════════════════════════════════════════════════════════
    if (uniforms.isTerrain == 1) {
        float3 faceNormal = normalize(in.worldNormal);
        float topMask = step(0.75, faceNormal.y);
        float bottomMask = step(0.75, -faceNormal.y);
        float sideMask = saturate(1.0 - topMask - bottomMask);

        float hitMask = step(0.001, in.collisionTimer);
        // Single albedo for every terrain face. Hit feedback only overrides it temporarily.
        float3 albedo = mix(levelTerrainBaseColor(uniforms.levelType), float3(1.0, 0.02, 0.0), hitMask);

        // Use the actual cube face normal so top and side shading matches the column geometry.
        float3 N = faceNormal;

        // Simple Phong lighting only; no height gradient, no path glow, no emissive terrain tint.
        float3 ambient = albedo * mix(0.30, 0.52, hitMask);
        float3 lit = ambient;
        lit += phongDirectionalLight(albedo, N, viewDir, keyLightDir, keyLightColor, 0.72, 20.0, 0.06);
        lit += phongDirectionalLight(albedo, N, viewDir, fillLightDir, fillLightColor, 0.24, 8.0, 0.02);

        finalColor = lit;

        // Black wireframe on visible faces only. Vertical thickness is world-scaled
        // so tall columns do not get a dark band near the top edge.
        float3 absPos = abs(in.localPosition);
        float edgeWidth = 0.014;
        float edgeSoftness = 0.010;
        float edgeX = 1.0 - smoothstep(edgeWidth, edgeWidth + edgeSoftness, 0.5 - absPos.x);
        float edgeZ = 1.0 - smoothstep(edgeWidth, edgeWidth + edgeSoftness, 0.5 - absPos.z);
        float columnHeight = max(in.texCoord.y + 50.0, 1.0);
        float topEdgeWidth = clamp(0.18 / columnHeight, 0.0015, 0.012);
        float topEdgeY = 1.0 - smoothstep(topEdgeWidth, topEdgeWidth * 2.0, 0.5 - in.localPosition.y);
        float xSideMask = step(0.75, abs(faceNormal.x));
        float zSideMask = step(0.75, abs(faceNormal.z));
        float topFaceEdges = topMask * max(edgeX, edgeZ);
        float sideVerticalEdges = sideMask * max(xSideMask * edgeZ, zSideMask * edgeX);
        float sideTopEdges = sideMask * topEdgeY;
        float edgeMask = max(topFaceEdges, max(sideVerticalEdges, sideTopEdges));

        // Draw edges on top faces and on side faces pointed toward the camera.
        float isFrontFacing = step(0.1, dot(faceNormal, viewDir));
        float visibleFaceMask = max(topMask, sideMask * isFrontFacing);
        edgeMask *= visibleFaceMask;
        finalColor = mix(finalColor, float3(0.0), saturate(edgeMask * 0.95));

        // ── Determine alpha for this fragment ───────────────────
        float alpha = 1.0;

        finalColor = applyLevelGrade(finalColor, uniforms.levelType);
        return float4(finalColor, alpha);

    } else {
        // ═════════════════════════════════════════════════════════
        // ── VEHICLE / OBSTACLES: simple Phong shading ───────────
        // ═════════════════════════════════════════════════════════
        float3 N = normalize(in.worldNormal);
        bool isShip = uniforms.renderStyle == 1;
        float3 surfaceColor = baseColor;
        bool hasTexture = uniforms.useTexture == 1;
        if (!hasTexture && !isShip) {
            surfaceColor = baseColor * 0.72 + keyTint * 0.18;
        }

        float3 ambient = surfaceColor * (isShip ? 0.26 : 0.20);
        float3 lit = ambient;
        lit += phongDirectionalLight(surfaceColor, N, viewDir, keyLightDir, keyLightColor, isShip ? 0.94 : 0.72, isShip ? 96.0 : 18.0, isShip ? 0.62 : 0.08);
        lit += phongDirectionalLight(surfaceColor, N, viewDir, fillLightDir, fillLightColor, isShip ? 0.32 : 0.26, isShip ? 32.0 : 10.0, isShip ? 0.16 : 0.02);

        if (isShip) {
            // Ship: monochrome shiny silver, separated by specular response and stencil outline.
            float shipRim = pow(1.0 - saturate(dot(N, viewDir)), 1.6);
            finalColor = lit;
            finalColor += float3(0.18, 0.18, 0.19) * shipRim;
        } else {
            // Obstacles: biome tinted Phong.
            finalColor = lit;
            finalColor += glowTint * pow(1.0 - saturate(dot(N, viewDir)), 2.6) * 0.10;
        }

        // Speed tint
        float speedFx = saturate((uniforms.vehicleSpeed - 90.0) / 240.0);
        finalColor += isShip ? float3(speedFx * 0.035) : glowTint * speedFx * 0.06;
    }

    // ── Atmospheric perspective + fog + Space Haze ────────────────
    float dist = length(in.worldPosition - uniforms.vehiclePosition);
    float2 fogRange = levelFogRange(uniforms.levelType);
    float fogFactor = smoothstep(fogRange.x, fogRange.y, dist);
    fogFactor = pow(fogFactor, 1.35);

    float2 skyUV = in.worldPosition.xz * 0.002;
    float hazeNoise = fbm_simple(skyUV + uniforms.time * 0.01, 3) * 0.5 + 0.5;
    float starNoise = fract(sin(dot(floor(in.worldPosition.xz * 0.5), float2(12.9898, 78.233))) * 43758.5453);
    float stars = step(0.985, starNoise) * saturate(hazeNoise + 0.2) * 1.5;

    float3 nebulaColor = mix(fogBaseColor, keyTint * 0.6 + glowTint * 0.4, hazeNoise);
    nebulaColor += float3(stars);

    float3 distantFogColor = mix(nebulaColor, keyTint * 0.5 + glowTint * 0.5, fogFactor);
    float3 fogColor = distantFogColor;
    if (uniforms.isTerrain == 0) {
        float layerWave = 0.5 + 0.5 * sin(in.worldPosition.z * 0.016 + in.worldPosition.x * 0.009);
        fogColor = mix(distantFogColor, distantFogColor * 0.65 + keyTint * 0.25, layerWave * 0.35);
    }
    
    finalColor = mix(finalColor, fogColor, fogFactor);
    finalColor = applyLevelGrade(finalColor, uniforms.levelType);
    return float4(finalColor, 1.0);
}
