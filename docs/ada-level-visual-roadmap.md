# Apple Design Award Visual Roadmap

This document defines a focused visual direction for level aesthetics with one goal: make the game feel award-worthy, not placeholder.

It builds on the current state of the project and references patterns that appear repeatedly in Apple Design Award game winners and finalists.

It should also treat `Race the Sun` as a direct experiential benchmark for:

- elegant camera framing
- strict speed readability
- silhouette-led obstacle language
- minimalist but premium atmosphere
- calm, modern, horizon-driven visual tension

## Why This Matters

Right now the game loop has strong foundations:

- speed pressure
- near-miss risk
- readable controls

But the environment still reads as functional prototype shading instead of a crafted world. Apple Design Award-level visuals usually require a cohesive art language where lighting, color, motion, and interaction all reinforce one identity.

## Inspiration Signals From Apple Design Awards

Key recurring visual qualities from recent Apple coverage:

- Distinct and cohesive visual theme is explicitly called out in the Visuals and Graphics criteria.
- Worlds feel authored, not procedurally generic, even when systems are dynamic.
- Materials and atmosphere carry emotional tone, not just readability.
- Camera and motion are used intentionally to support interaction and mood.

Reference pages:

- 2025 Apple Design Awards (Visuals & Graphics winner game: Infinity Nikki):  
  <https://www.apple.com/newsroom/2025/06/apple-unveils-winners-and-finalists-of-the-2025-apple-design-awards/>
- 2024 Apple Design Awards (Visuals & Graphics winner game: Lies of P):  
  <https://www.apple.com/newsroom/2024/06/apple-announces-winners-of-the-2024-apple-design-awards/>

Additional gameplay/feel benchmark:

- Race the Sun (App Store):  
  <https://apps.apple.com/us/app/race-the-sun/id700227648>

## Visual Pillars For This Game

The game should own a clear identity:

1. Neon river abyss fantasy
2. High-speed readability without flatness
3. Reactive world tied to player risk and flow
4. Premium material treatment for ships and terrain
5. Memorable mood shifts per level, not only hue swaps

The visual target is not maximal noise. `Race the Sun` is the reminder that restraint, clarity, horizon composition, and bold silhouettes can feel more premium than piling on effects.

## Current Visual Problems

- Terrain shading is mostly gradient + simple lighting, so it feels flat and synthetic.
- Color changes carry too much of the burden instead of shape, atmosphere, and material response.
- Levels read too similarly in silhouette and spatial rhythm.
- VFX language is underutilized for gameplay states (grazing, boost, danger, chaser pressure).
- The scene still lacks the composed, instantly readable horizon language that makes `Race the Sun` feel premium at speed.

## Target Art Direction By Level

These are level identities that should differ in lighting behavior, sky treatment, and material response.

### Neon Synthwave

- Tone: electric night-city channel
- Palette: cyan, magenta, deep ultramarine
- Atmosphere: low haze with scanline-like layered depth
- Material mood: glossy wet reflections on riverbed edges
- Race the Sun cue: keep silhouettes clean and let the horizon do a lot of the emotional work

### Fiery Retrowave

- Tone: collapsing heat corridor
- Palette: ember orange, crimson, acid yellow highlights
- Atmosphere: drifting heat distortion and subtle ash
- Material mood: matte-burnt stone with emissive cracks
- Race the Sun cue: preserve obstacle readability even when the scene is hot and dramatic

### Cyberpunk Void

- Tone: deep techno-abyss
- Palette: toxic green, ultraviolet, cold steel highlights
- Atmosphere: volumetric mist ribbons and data-like light streaks
- Material mood: hard specular surfaces with noisy glow accents
- Race the Sun cue: strong distant composition matters as much as local shader detail

### Debug Mode

- Keep this intentionally diagnostic, but preserve enough readability that it still feels coherent with the game’s visual stack.

## Rendering Upgrade Plan

This is ordered by impact-to-effort and keeps performance in mind.

## Phase 1: Depth And Material Foundation (Immediate)

1. ~~Improve terrain normal response:~~
- ~~derive better normals from terrain height gradients (or per-instance analytic normal approximation)~~
- ~~increase shape readability through directional contrast~~

2. ~~Add two-band lighting model:~~
- ~~primary directional light + soft fill light~~
- ~~slight rim contribution for silhouettes~~
- ~~stencil-masked ship outline for reliable ship separation~~

3. ~~Introduce distance-based atmospheric perspective:~~
- ~~color fog by level palette~~
- ~~depth tint curve that preserves midground contrast~~

4. ~~Ship material upgrade:~~
- ~~keep texture fidelity~~
- ~~add controlled specular and rim highlights~~
- ~~avoid flat-white fallback look in any path~~

## Phase 2: Motion And Mood (High Value)

1. ~~Reactive glow zones:~~
- ~~grazing increases nearby terrain pulse intensity~~
- ~~chaser proximity causes environmental warning shift~~
- ~~carved playable path receives stronger neon surface glow~~
- ~~opaque terrain edges receive additive neon treatment on visible faces~~

2. ~~Layered sky/void treatment (first pass):~~
- ~~far gradient + animated noise layer + subtle parallax bands~~
- biome-specific sky rhythm is now present at a base level, but still needs a stronger authored pass

3. Speed language:
- shader-driven edge flashes are in
- true streak particles aligned to velocity are not implemented yet

4. ~~Pad identity upgrade:~~
- ~~boost/elevation/flatten pads need unmistakable silhouettes and emissive behavior before contact~~

## Phase 3: Signature Finishing Pass

1. ~~Environmental storytelling props (first pass):~~
- ~~sparse but high-impact landmark silhouettes per biome~~
- this is present, but still too sparse to fully break the infinite-grid feel

2. Curated color grading per level:
- base grading exists
- final LUT-like balancing and UI validation are not complete yet

3. ~~Camera polish:~~
- ~~keep gameplay framing strict and readable~~
- add tiny context-sensitive cinematic accents only when non-disruptive (intentionally deferred)

## Gameplay-Visual Coupling Rules

To reach award-level cohesion, visuals must reinforce gameplay states:

- graze should feel dangerously beautiful, not only score-positive
- boosts should visibly alter scene tempo
- chaser pressure should affect world mood before failure
- collectible pads should be instantly legible at speed
- camera and obstacle framing should support the same kind of effortless readability that makes `Race the Sun` feel fair at extreme speed
- ship readability is a hard requirement: the ship outline should remain visible without relying on glow

## Specific Technical Tasks In This Codebase

Primary files:

- `SkiRacingGame/Sources/GraphicsEngine/Shaders.metal`
- `SkiRacingGame/Sources/GraphicsEngine/GameRenderer.mm`
- `SkiRacingGame/Sources/GameLogic/PhysicsWorld.cpp`

Proposed concrete tasks:

1. Expand fragment terrain model from flat gradient to a layered BRDF-like stylized lighting model.
2. Add per-level atmospheric fog color and density controls in uniforms.
3. Add emissive channel logic for pad types and graze/reactive states.
4. Add velocity-reactive post-style effects (lightweight, shader-based).
5. Ensure gameplay and store ships share a consistent material language.

## Performance Guardrails

- Target stable 60 FPS on iPhone/iPad priority paths.
- Favor cheap shader math over heavy multi-pass effects initially.
- Use per-level toggles to degrade gracefully on lower-tier hardware.
- Prioritize readability first, then spectacle.

## Quality Bar Checklist

Before calling visuals “award-ready,” each level should pass:

1. Instantly recognizable mood from a single screenshot.
2. Clear gameplay readability at peak speed.
3. Distinct silhouette language across levels.
4. Material response that feels intentional, not placeholder.
5. Reactivity that ties effects to player decisions.
6. The scene still reads well if judged by `Race the Sun` standards: clean horizon, elegant composition, and no effect clutter that harms flow.

## Near-Term Execution Recommendation

Best next implementation sequence:

1. Shader depth/material pass
2. Per-level atmosphere pass
3. Reactive VFX pass (graze/chaser/boost)
4. Final color and polish pass

This sequence improves visual quality fast without destabilizing core gameplay.
