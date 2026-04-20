#include <metal_stdlib>
using namespace metal;

// ── Constants ────────────────────────────────────────────────────────
constant float PI = 3.14159265359;

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
    uint cellFlags; // packed CellFlags bits for fragment coloring
    float collisionTimer;
    uint edgeExposure; // packed bits: 0=+X, 1=-X, 2=+Z, 3=-Z
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
};

// Per-instance grid cell state passed from CPU
struct GridCellGPU {
    uint16_t flags;
    float collisionTimer;
};

// Flag constants matching CellFlags enum
constant uint16_t FLAG_DESTRUCTIBLE = 1 << 0;
constant uint16_t FLAG_DESTROYED    = 1 << 1;
constant uint16_t FLAG_BOOST_PAD    = 1 << 2;
constant uint16_t FLAG_HAS_TURRET   = 1 << 3;
constant uint16_t FLAG_TURRET_ACTIVE= 1 << 4;
constant uint16_t FLAG_EQUALIZER    = 1 << 5; // unused
constant uint16_t FLAG_ELEVATION_PAD= 1 << 6;
constant uint16_t FLAG_FLATTEN_PAD  = 1 << 7;
constant uint16_t FLAG_COLLIDED     = 1 << 8;
constant float COLLISION_EFFECT_DURATION = 0.5;
constant float TERRAIN_LEAD_DISTANCE = 150.0;
constant float RIVER_CURVE_SCALE = 0.92;
constant float RIVER_PRIMARY_FREQUENCY = 0.0074;
constant float RIVER_SECONDARY_FREQUENCY = 0.021;
constant float RIVER_BRANCH_FREQUENCY = 0.0046;

// ── Helpers ──────────────────────────────────────────────────────

// Convert HSV to RGB
float3 hsv2rgb(float3 c) {
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

// Deterministic flag computation from world coordinates.
// Must match the logic in Track.cpp so flags are always locked to terrain.
float hashMetal(float x, float y) {
    float px = fract(x * 0.3183099 + 0.1);
    float py = fract(y * 0.3183099 + 0.1);
    px *= 17.0; py *= 17.0;
    return fract(px * py * (px + py));
}

// ── Terrain Logic Helpers ────────────────────────────────────────

float getDistFromRiverMetal(float gridX, float gridZ) {
    const float kRiverPlayableHalfWidth = 100.0;
    const float kRiverTransitionWidth = 40.0;
    const float kRiverCenterLimit = kRiverPlayableHalfWidth - kRiverTransitionWidth;
    float dampening = smoothstep(0.0, 500.0, abs(gridZ));
    float riverBaseX = (sin(gridZ * RIVER_PRIMARY_FREQUENCY) * (31.0 * RIVER_CURVE_SCALE) +
                        sin(gridZ * RIVER_SECONDARY_FREQUENCY + 0.9) * (16.0 * RIVER_CURVE_SCALE)) * dampening;
    
    // Split driver: positive when river branches
    float splitFactor = (sin(gridZ * RIVER_BRANCH_FREQUENCY + 10.0) * 0.72) +
                        (sin(gridZ * 0.0095 + 1.7) * 0.28);
    float branchOffset = smoothstep(0.04, 0.52, splitFactor) * (21.0 * RIVER_CURVE_SCALE);
    
    if (branchOffset > 2.0) {
        float riverX1 = clamp(riverBaseX + branchOffset, -kRiverCenterLimit, kRiverCenterLimit);
        float riverX2 = clamp(riverBaseX - branchOffset, -kRiverCenterLimit, kRiverCenterLimit);
        return min(abs(gridX - riverX1), abs(gridX - riverX2));
    }
    return abs(gridX - clamp(riverBaseX, -kRiverCenterLimit, kRiverCenterLimit));
}

uint computeCellFlags(float worldX, float worldZ) {
    float distFromRiver = getDistFromRiverMetal(worldX, worldZ);
    uint flags = 0;
    
    // River edge: cluster groups of columns are destructible (breakable through)
    // They sit in the 12-22 unit transition zone right at the river wall
    if (distFromRiver > 12.0 && distFromRiver < 22.0) {
        float groupX = floor(worldX / 15.0) + 1000.0;
        float groupZ = floor(worldZ / 15.0) + 1000.0;
        float groupHash = hashMetal(groupX * 0.73 + 1.3, groupZ * 0.91 + 2.7);
        if (groupHash < 0.30) {
            flags |= FLAG_DESTRUCTIBLE;
        }
    }
    
    // Boost pads: rare, only in the low riverbed
    if (distFromRiver < 10.0) {
        float bx = floor(worldX / 5.0) + 500.0;
        float bz = floor(worldZ / 5.0) + 500.0;
        float boostHash = hashMetal(bx * 1.17 + 3.4, bz * 0.83 + 7.1);
        if (boostHash < 0.005) {
            flags |= FLAG_BOOST_PAD;
        }
    }
    
    // Elevation pads: very rare, only in the deep center of the riverbed
    if (distFromRiver < 6.0) {
        float ex = floor(worldX / 5.0) + 700.0;
        float ez = floor(worldZ / 5.0) + 700.0;
        float elevHash = hashMetal(ex * 1.53 + 5.7, ez * 1.21 + 9.3);
        if (elevHash < 0.004) {
            flags |= FLAG_ELEVATION_PAD;
        }
    }
    
    // Flatten pads: very rare, only in the deep center of the riverbed
    if (distFromRiver < 6.0) {
        float fx = floor(worldX / 5.0) + 800.0;
        float fz = floor(worldZ / 5.0) + 800.0;
        float flatHash = hashMetal(fx * 1.83 + 2.7, fz * 1.41 + 6.3);
        if (flatHash < 0.003) {
            flags |= FLAG_FLATTEN_PAD;
        }
    }
    
    return flags;
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
    
    // Blend them based on distance from the nearest river branch center
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
        
        // Z instance is positioned relative to the vehicle so it scrolls seamlessly.
        float vehicleZ_snapped = floor((uniforms.vehiclePosition.z + colSpacing*0.5) / colSpacing) * colSpacing;
        
        // Draw centered behind/ahead
        float worldCenterX = gridX_idx * colSpacing;
        float worldCenterZ = vehicleZ_snapped + TERRAIN_LEAD_DISTANCE - (gridZ_idx * colSpacing);
        
        float h = terrainHeight(float2(worldCenterX, worldCenterZ), uniforms.slopeAngle);
        
        // Compute static flags from world position (deterministic, locked to terrain)
        uint staticFlags = computeCellFlags(worldCenterX, worldCenterZ);
        
        // Read only the Destroyed/Collided flags from dynamic GPU state (per-instance mutable)
        GridCellGPU cell = gridState[instance_id];
        uint allFlags = staticFlags | (cell.flags & (FLAG_DESTROYED | FLAG_COLLIDED));
        out.collisionTimer = cell.collisionTimer;
        
        // If destroyed, collapse the column to below the void
        bool isDestroyed = (allFlags & FLAG_DESTROYED) != 0;
        if (isDestroyed) {
            h = -220.0;
            out.collisionTimer = 0.0;
        }

        // Pass merged flags to fragment shader for color coding
        out.cellFlags = allFlags;
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
        worldPos.x = worldCenterX + in.position.x * colSpacing;
        worldPos.z = worldCenterZ + in.position.z * colSpacing;

        float topY = h;
        float bottomY = -50.0;
        if (isDestroyed) {
            topY = -220.0;
            bottomY = -220.0;
        } else if (out.collisionTimer > 0.0) {
            float progress = saturate(1.0 - (out.collisionTimer / COLLISION_EFFECT_DURATION));
            float popLift = sin(progress * 3.14159265) * 7.0;
            float collapse = smoothstep(0.42, 1.0, progress);
            topY = mix(h + popLift, -52.0, collapse);
            bottomY = mix(-50.0 + popLift * 0.22, -56.0, collapse);
        }
        
        if (in.position.y > 0.0) {
            worldPos.y = topY;
        } else {
            worldPos.y = bottomY;
        }
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
        out.position = uniforms.viewProjectionMatrix * worldPos;
        out.worldPosition = worldPos.xyz;
        out.localPosition = in.position;
        out.texCoord = in.texCoord;
        out.worldNormal = (uniforms.modelMatrix * float4(in.normal, 0.0)).xyz;
    }

    return out;
}

// ═══════════════════════════════════════════════════════════════════
// ── PBR Helpers (Mobile-optimised Cook-Torrance) ──────────────────
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
        // Inverted-hull silhouette: vivid neon glow outline for ship
        float pulse = 0.88 + 0.12 * sin(uniforms.time * 6.5);
        float outerPulse = 0.94 + 0.06 * sin(uniforms.time * 13.0);
        float3 glowColor = glowTint * 3.2 * pulse * outerPulse;
        glowColor += float3(1.0, 1.0, 1.0) * 0.45;
        return float4(applyLevelGrade(saturate(glowColor), uniforms.levelType), 0.95);
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
        baseColor = colorTexture.sample(textureSampler, in.texCoord).rgb;
    }

    float3 finalColor = baseColor;

    // ═════════════════════════════════════════════════════════════
    // ── TERRAIN: PBR shading ────────────────────────────────────
    // ═════════════════════════════════════════════════════════════
    if (uniforms.isTerrain == 1) {
        float3 faceNormal = normalize(in.worldNormal);
        float topMask = step(0.75, faceNormal.y);
        float bottomMask = step(0.75, -faceNormal.y);
        float sideMask = saturate(1.0 - topMask - bottomMask);

        // ── Elevation-based albedo ──────────────────────────────
        float colTopH = in.texCoord.y;
        float t = clamp((colTopH + 20.0) / 75.0, 0.0, 1.0);
        float3 topAlbedo = terrainElevationColor(t, uniforms.levelType);
        float3 floorAlbedo = fogBaseColor * 0.32 + keyTint * 0.10 + float3(0.02, 0.02, 0.025);
        float3 sideAlbedo = mix(topAlbedo * 0.7, floorAlbedo, 0.22);
        float3 albedo = topAlbedo * topMask + sideAlbedo * sideMask + floorAlbedo * bottomMask;
        
        // PBR material parameters for terrain
        float metallic  = 0.0;   // terrain is dielectric
        float roughness = 0.72;  // fairly rough stone/ground
        
        // ── Cell-type color overrides (same colors as before) ────
        uint flags = in.cellFlags;
        bool isGlass = (flags & FLAG_DESTRUCTIBLE) != 0;
        if (flags & FLAG_DESTROYED) {
            discard_fragment();
        }

        // Two-pass separation: opaque pass skips glass, transparent pass skips opaque
        if (uniforms.renderStyle == 0 && isGlass) {
            discard_fragment();
        }
        if (uniforms.renderStyle == 6 && !isGlass) {
            discard_fragment();
        }

        if (flags & FLAG_COLLIDED) {
            float progress = saturate(1.0 - (in.collisionTimer / COLLISION_EFFECT_DURATION));
            float impactPulse = 1.0 - smoothstep(0.0, 1.0, progress);
            float burst = sin(progress * 3.14159265);
            albedo = mix(albedo, float3(1.0, 0.05, 0.05), topMask + sideMask * 0.58);
            albedo += float3(1.0, 0.08, 0.08) * (0.35 + burst * 0.75 + impactPulse * 0.45);
        } else if (flags & FLAG_BOOST_PAD) {
            float pulse = 0.55 + 0.45 * sin(uniforms.time * 7.5);
            albedo = mix(albedo, float3(0.0, 1.0, 1.0) * pulse, topMask + sideMask * 0.35);
            roughness = 0.35; // sleeker
        } else if (flags & FLAG_ELEVATION_PAD) {
            float pulse = 0.45 + 0.55 * sin(uniforms.time * 5.5);
            albedo = mix(albedo, float3(0.3, 1.0, 0.3) * pulse, topMask + sideMask * 0.35);
            roughness = 0.35;
        } else if (flags & FLAG_FLATTEN_PAD) {
            float pulse = 0.5 + 0.5 * sin(uniforms.time * 6.2);
            albedo = mix(albedo, float3(1.0, 0.2, 0.6) * pulse, topMask + sideMask * 0.35);
            roughness = 0.35;
        } else if (isGlass) {
            // Fly-through columns: lighter, slightly translucent-looking albedo
            albedo = mix(albedo, keyTint * 0.6 + float3(0.5, 0.55, 0.65), topMask + sideMask * 0.90);
            roughness = 0.30; // smoother / glassier
            metallic = 0.15;
        } else if (flags & FLAG_HAS_TURRET) {
            albedo = mix(albedo, float3(1.0, 0.4, 0.0), topMask + sideMask * 0.45);
            metallic = 0.4;
            roughness = 0.45;
        }

        // ── Geometry-matched normal for lighting ────────────────
        float3 N = normalize(
            in.terrainTopNormal * topMask +
            float3(0.0, -1.0, 0.0) * bottomMask +
            faceNormal * sideMask
        );

        // ── PBR lighting (key + fill) ───────────────────────────
        float3 ambient = albedo * (fogBaseColor * 0.4 + float3(0.06)) * 1.5;
        float3 lit = ambient;
        lit += pbrDirectionalLight(albedo, metallic, roughness, N, viewDir, keyLightDir, keyLightColor, 2.2);
        lit += pbrDirectionalLight(albedo, metallic, roughness, N, viewDir, fillLightDir, fillLightColor, 0.8);

        finalColor = lit;

        // ── Chaser proximity glow (gameplay effect, kept as-is) ──
        float distToChaser = abs(in.worldPosition.z - uniforms.chaserZ);
        if (distToChaser < 26.0) {
            float glow = 1.0 - distToChaser / 26.0;
            float warningPulse = 0.72 + 0.28 * sin(uniforms.time * 10.5 + in.worldPosition.x * 0.08);
            finalColor = mix(finalColor, float3(1.0, 0.05, 0.05), glow * (topMask + sideMask * 0.5) * 0.62);
            finalColor += float3(1.0, 0.14, 0.08) * glow * warningPulse * (topMask * 0.20 + sideMask * 0.10);
        }

        // ── Reactive glow near vehicle (gameplay effect, kept) ──
        float distToVehicle = distance(in.worldPosition.xz, uniforms.vehiclePosition.xz);
        float nearVehicle = exp(-distToVehicle * 0.045);
        float surfaceMask = topMask + sideMask * 0.45;
        float grazeBoost = uniforms.isGrazing > 0 ? 0.18 : 0.0;
        float reactive = nearVehicle * (grazeBoost + uniforms.overdriveCharge * 0.12);
        finalColor += keyTint * reactive * surfaceMask;

        // ── Speed edge flash (gameplay effect, kept) ────────────
        float speedFx = saturate((uniforms.vehicleSpeed - 80.0) / 220.0);
        float edgeFlash = speedFx * pow(1.0 - saturate(dot(N, viewDir)), 4.0) * 0.08;
        finalColor += keyTint * edgeFlash * surfaceMask;

        // ── Collision burst (gameplay effect, kept) ─────────────
        if (flags & FLAG_COLLIDED) {
            float progress = saturate(1.0 - (in.collisionTimer / COLLISION_EFFECT_DURATION));
            float burst = sin(progress * 3.14159265);
            finalColor += float3(1.0, 0.06, 0.06) * (0.55 + burst * 1.55);
            finalColor += float3(1.0, 0.42, 0.18) * pow(1.0 - saturate(dot(faceNormal, viewDir)), 3.4) * (0.25 + burst * 0.65);
        }

        // ── Destructible column: subtle extra Fresnel rim ───────
        // (replaces the old wireframe/pulsing glow — keeps them readable)
        if (isGlass) {
            float glassRim = pow(1.0 - saturate(dot(faceNormal, viewDir)), 2.4);
            finalColor += glowTint * glassRim * 0.25;
        }

        // ── Lightweight Edge Rendering ──────────────────────────────
        // Black lines on edges of normal columns
        if (!isGlass) {
            float3 absPos = abs(in.localPosition);
            // Edges happen when two axes are near 0.5
            float3 edges = smoothstep(0.46, 0.49, absPos);
            float edgeMask = max(max(edges.x * edges.y, edges.y * edges.z), edges.x * edges.z);
            finalColor = mix(finalColor, float3(0.0, 0.0, 0.0), edgeMask * 0.85);
        }

        // ── Determine alpha for this fragment ───────────────────
        float alpha = 1.0;
        if (isGlass) {
            alpha = 0.45; // simple transparency for fly-through columns
        }

        // ── Fog ─────────────────────────────────────────────────
        float dist = length(in.worldPosition - uniforms.vehiclePosition);
        float2 fogRange = levelFogRange(uniforms.levelType);
        float fogFactor = smoothstep(fogRange.x, fogRange.y, dist);
        fogFactor = pow(fogFactor, 1.35) * 0.72;
        finalColor = mix(finalColor, fogBaseColor, fogFactor);
        finalColor = applyLevelGrade(finalColor, uniforms.levelType);
        return float4(finalColor, alpha);

    } else {
        // ═════════════════════════════════════════════════════════
        // ── VEHICLE / OBSTACLES: PBR shading ────────────────────
        // ═════════════════════════════════════════════════════════
        float3 N = normalize(in.worldNormal);
        float3 surfaceColor = baseColor;
        bool hasTexture = uniforms.useTexture == 1;
        if (!hasTexture) {
            surfaceColor = baseColor * 0.72 + keyTint * 0.18;
        }

        bool isShip = hasTexture || (uniforms.renderStyle == 0 && uniforms.isTerrain == 0);

        float metallic  = isShip ? 0.6 : 0.1;
        float roughness = isShip ? 0.35 : 0.55;

        // Ambient
        float3 ambient = surfaceColor * (fogBaseColor * 0.35 + float3(0.08)) * 1.5;

        // PBR two-light
        float3 lit = ambient;
        lit += pbrDirectionalLight(surfaceColor, metallic, roughness, N, viewDir, keyLightDir, keyLightColor, 2.4);
        lit += pbrDirectionalLight(surfaceColor, metallic, roughness, N, viewDir, fillLightDir, fillLightColor, 0.7);

        if (isShip) {
            // Ship: neon rim separation (gameplay feel, kept)
            float shipRim = pow(1.0 - saturate(dot(N, viewDir)), 1.6);
            float3 separationTint = mix(float3(0.96, 0.96, 1.0), glowTint, 0.52);
            finalColor = lit;
            finalColor += separationTint * shipRim * 1.0;
            finalColor += glowTint * shipRim * 0.6;
            finalColor += separationTint * 0.12;
        } else {
            // Obstacles: biome tinted PBR
            finalColor = lit;
            finalColor += glowTint * pow(1.0 - saturate(dot(N, viewDir)), 2.6) * 0.18;
        }

        // Speed tint
        float speedFx = saturate((uniforms.vehicleSpeed - 90.0) / 240.0);
        finalColor += glowTint * speedFx * (isShip ? 0.20 : 0.10);
    }

    // ── Atmospheric perspective + fog ─────────────────────────────
    float dist = length(in.worldPosition - uniforms.vehiclePosition);
    float2 fogRange = levelFogRange(uniforms.levelType);
    float fogFactor = smoothstep(fogRange.x, fogRange.y, dist);
    fogFactor = pow(fogFactor, 1.35);
    if (uniforms.isTerrain == 1) {
        fogFactor *= 0.72;
    }
    float3 fogColor = fogBaseColor;
    if (uniforms.isTerrain == 0) {
        float layerWave = 0.5 + 0.5 * sin(in.worldPosition.z * 0.016 + in.worldPosition.x * 0.009);
        fogColor = mix(fogBaseColor, fogBaseColor * 0.65 + keyTint * 0.25, layerWave * 0.35);
    }
    
    finalColor = mix(finalColor, fogColor, fogFactor);
    finalColor = applyLevelGrade(finalColor, uniforms.levelType);
    return float4(finalColor, 1.0);
}
