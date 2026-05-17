#ifndef MathUtils_hpp
#define MathUtils_hpp

#include <math.h>

class MathUtils {
public:
    static float fract(float x) {
        return x - floorf(x);
    }
    static float hash(float x, float y) {
        float px = fract(x * 0.3183099f + 0.1f);
        float py = fract(y * 0.3183099f + 0.1f);
        px *= 17.0f; py *= 17.0f;
        return fract(px * py * (px + py));
    }
    static float mix(float a, float b, float t) {
        return a + (b - a) * t;
    }

    // Value noise with analytical derivatives
    // out_dx, out_dy receive the partial derivatives
    static float noised(float x, float y, float& out_dx, float& out_dy) {
        float ix = floorf(x); float iy = floorf(y);
        float fx = fract(x);  float fy = fract(y);
        // Quintic interpolation
        float ux = fx * fx * fx * (fx * (fx * 6.0f - 15.0f) + 10.0f);
        float uy = fy * fy * fy * (fy * (fy * 6.0f - 15.0f) + 10.0f);
        float dux = 30.0f * fx * fx * (fx * (fx - 2.0f) + 1.0f);
        float duy = 30.0f * fy * fy * (fy * (fy - 2.0f) + 1.0f);

        float a = hash(ix + 0.0f, iy + 0.0f);
        float b = hash(ix + 1.0f, iy + 0.0f);
        float c = hash(ix + 0.0f, iy + 1.0f);
        float d = hash(ix + 1.0f, iy + 1.0f);

        float k0 = a;
        float k1 = b - a;
        float k2 = c - a;
        float k4 = a - b - c + d;

        float value = k0 + k1 * ux + k2 * uy + k4 * ux * uy;
        out_dx = dux * (k1 + k4 * uy);
        out_dy = duy * (k2 + k4 * ux);
        return value;
    }

    static float noise(float x, float y) {
        float ix = floorf(x); float iy = floorf(y);
        float fx = fract(x); float fy = fract(y);
        float ux = fx * fx * fx * (fx * (fx * 6.0f - 15.0f) + 10.0f);
        float uy = fy * fy * fy * (fy * (fy * 6.0f - 15.0f) + 10.0f);
        return mix(mix(hash(ix + 0.0f, iy + 0.0f), hash(ix + 1.0f, iy + 0.0f), ux),
                   mix(hash(ix + 0.0f, iy + 1.0f), hash(ix + 1.0f, iy + 1.0f), ux), uy);
    }

    // Derivative-aware FBM (erosion dampening on slopes)
    static float fbm_d(float x, float y, int octaves) {
        float f = 1.0f;
        float a = 0.5f;
        float t = 0.0f;
        float dx = 0.0f, dy = 0.0f;
        float c05 = cosf(0.5f);
        float s05 = sinf(0.5f);

        for (int i = 0; i < octaves; i++) {
            float ndx, ndy;
            float n = noised(x * f, y * f, ndx, ndy);
            float slopeAtten = 1.0f / (1.0f + dx * dx + dy * dy);
            t += a * n * slopeAtten;
            dx += a * ndx * f;
            dy += a * ndy * f;
            f *= 2.0f;
            a *= 0.5f;
            float nx = (c05 * x + s05 * y) + 100.0f;
            float ny = (-s05 * x + c05 * y) + 100.0f;
            x = nx; y = ny;
        }
        return t;
    }

    // Ridged noise FBM
    static float fbm_ridged(float x, float y, int octaves) {
        float f = 1.0f;
        float a = 0.5f;
        float t = 0.0f;
        float prev = 1.0f;
        float c05 = cosf(0.5f);
        float s05 = sinf(0.5f);

        for (int i = 0; i < octaves; i++) {
            float n = noise(x * f, y * f);
            n = 1.0f - fabsf(n * 2.0f - 1.0f);
            n = n * n;
            t += a * n * prev;
            prev = n;
            f *= 2.0f;
            a *= 0.5f;
            float nx = (c05 * x + s05 * y) + 100.0f;
            float ny = (-s05 * x + c05 * y) + 100.0f;
            x = nx; y = ny;
        }
        return t;
    }

    // Domain-warped FBM
    static float fbm_warped(float x, float y, int octaves) {
        float wx = noise(x * 0.7f + 1.7f, y * 0.7f + 9.2f);
        float wy = noise(x * 0.7f + 8.3f, y * 0.7f + 2.8f);
        return fbm_d(x + wx * 1.5f, y + wy * 1.5f, octaves);
    }

    // Simple value noise FBM (for jagged terrain)
    static float fbm_simple(float x, float y, int octaves) {
        float v = 0.0f;
        float a = 0.5f;
        float c05 = cosf(0.5f);
        float s05 = sinf(0.5f);
        for (int i = 0; i < octaves; i++) {
            v += a * noise(x, y);
            float nx = (c05 * x + s05 * y) * 2.0f + 100.0f;
            float ny = (-s05 * x + c05 * y) * 2.0f + 100.0f;
            x = nx; y = ny;
            a *= 0.5f;
        }
        return v;
    }

    // Custom smoothstep to avoid simd header dependency
    static float math_smoothstep(float edge0, float edge1, float x) {
        float t = fmaxf(0.0f, fminf(1.0f, (x - edge0) / (edge1 - edge0)));
        return t * t * (3.0f - 2.0f * t);
    }

    static float clamp(float x, float minValue, float maxValue) {
        return fmaxf(minValue, fminf(maxValue, x));
    }

    // Winding riverbed logic using a single stable centerline. Per-run parameters
    // vary the curve without desynchronizing CPU collision and GPU rendering.
    static float getRiverCenterX(float gridZ,
                                 float primaryPhase,
                                 float secondaryPhase,
                                 float frequencyScale,
                                 float curveScale) {
        constexpr float kRiverPlayableHalfWidth = 100.0f;
        constexpr float kRiverTransitionWidth = 40.0f;
        constexpr float kRiverCenterLimit = kRiverPlayableHalfWidth - kRiverTransitionWidth;
        constexpr float kRiverPrimaryFrequency = 0.0074f;
        constexpr float kRiverSecondaryFrequency = 0.021f;
        float clampedFrequencyScale = clamp(frequencyScale, 0.86f, 1.18f);
        float clampedCurveScale = clamp(curveScale, 0.78f, 1.10f);
        float riverBaseX = (sinf(gridZ * kRiverPrimaryFrequency * clampedFrequencyScale + primaryPhase) * (31.0f * clampedCurveScale) +
                            sinf(gridZ * kRiverSecondaryFrequency * clampedFrequencyScale + secondaryPhase) * (16.0f * clampedCurveScale));

        return clamp(riverBaseX, -kRiverCenterLimit, kRiverCenterLimit);
    }

    static float getRiverCenterX(float gridZ) {
        return getRiverCenterX(gridZ, 0.0f, 0.9f, 1.0f, 0.92f);
    }

    static float getDistFromRiver(float gridX,
                                  float gridZ,
                                  float primaryPhase,
                                  float secondaryPhase,
                                  float frequencyScale,
                                  float curveScale) {
        return fabsf(gridX - getRiverCenterX(gridZ, primaryPhase, secondaryPhase, frequencyScale, curveScale));
    }

    static float getDistFromRiver(float gridX, float gridZ) {
        return fabsf(gridX - getRiverCenterX(gridZ));
    }

    // Returns the discrete column height for grid coords
    static float getTerrainHeight(float worldX,
                                  float worldZ,
                                  float slopeAngle,
                                  float primaryPhase,
                                  float secondaryPhase,
                                  float frequencyScale,
                                  float curveScale) {
        float colSpacing = 5.0f;
        float gridX = floorf((worldX + colSpacing*0.5f) / colSpacing) * colSpacing;
        float gridZ = floorf((worldZ + colSpacing*0.5f) / colSpacing) * colSpacing;

        float tcx = gridX * 0.04f;
        float tcy = gridZ * 0.04f;

        // Mountains are rugged and high
        float h_mountain = fbm_simple(tcx, tcy, 4) * 45.0f + 10.0f; // 10 to 55 height
        
        // River path has noticeable but short noise (max 1/3 the 15 unit depth -> 5 units amplitude)
        float h_river = fbm_simple(tcx, tcy, 2) * 2.5f - 17.5f; // approx -17.5 to -12.5 height

        // Blend them based on distance from the river centerline
        float distFromCenter = getDistFromRiver(gridX, gridZ, primaryPhase, secondaryPhase, frequencyScale, curveScale);
        float pathMix = math_smoothstep(15.0f, 40.0f, distFromCenter);

        float finalHeight = mix(h_river, h_mountain, pathMix);
        
        // Removed hard clamping to allow noisy terrain even in the pure riverbed

        // Quantize height to distinct vertical steps for the voxel look
        return floorf(finalHeight * 0.5f) * 2.0f;
    }

    static float getTerrainHeight(float worldX, float worldZ, float slopeAngle) {
        return getTerrainHeight(worldX, worldZ, slopeAngle, 0.0f, 0.9f, 1.0f, 0.92f);
    }
};

#endif /* MathUtils_hpp */
