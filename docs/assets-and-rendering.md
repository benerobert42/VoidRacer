# Assets And Rendering

This document explains how ship assets are currently organized and how the game loads them.

## Asset Folder Structure

Ship assets currently live in:

- `SkiRacingGame/Assets/Executioner`
- `SkiRacingGame/Assets/Challenger`
- `SkiRacingGame/Assets/Dispatcher`
- `SkiRacingGame/Assets/Imperial`
- `SkiRacingGame/Assets/Insurgent`

Typical contents:

- `OBJ/`
- `Textures/`
- `Blend/`
- `FBX/`
- `glTF/`

Current runtime systems rely on:

- `OBJ` for geometry
- `Textures` for ship skins

## Naming Conventions

Current runtime naming pattern:

- mesh name = ship name
- texture name = `ShipName_SkinName`

Examples:

- `Executioner.obj`
- `Executioner_Blue.png`
- `Imperial_Red.png`

This naming scheme is important because both the gameplay renderer and the store preview depend on it.

## Gameplay Renderer Loading

Gameplay uses `AssetManager.mm` plus `GameRenderer.mm`.

Current behavior:

- `GameEngineWrapper` stores the selected mesh and texture names
- `GameRenderer` asks `AssetManager` to load those asset names
- `AssetManager` searches bundled resources recursively

This recursive search was added so the app can bundle full ship folders instead of copying flat Bob-era resources into the app root.

## Store Preview Loading

The store preview uses `SceneKit`.

Current behavior:

- loads the selected ship from `Bundle.main`
- expects the object file at `ShipName/OBJ/ShipName.obj`
- expects textures under `ShipName/Textures/`
- applies the default blue texture to preview materials while visible skin selection is paused
- rotates the ship slowly in place

## Xcode Resource Setup

The Xcode project currently bundles ship folders directly as resources:

- `Executioner`
- `Challenger`
- `Dispatcher`
- `Imperial`
- `Insurgent`

The old `Bob`-specific bundle wiring was removed from the active flow.

## Current Rendering Split

### Metal

Used for:

- gameplay rendering
- terrain
- ship during the run
- shader-driven world visuals

Current gameplay rendering rules:

- terrain geometry is anchored from the CPU `track.grid.originZ` instead of recomputing origin from the vehicle in the shader
- terrain renders in a single opaque pass with backface culling
- gameplay rendering explicitly uses counter-clockwise front-face winding so ModelIO/OBJ faces cull correctly
- transparent, destructible, pad, and destroyed-cell rendering paths are disabled for the current baseline
- decorative landmark cubes are disabled so only the streamed terrain grid supplies terrain-like columns
- PBR is temporarily commented out; terrain, ship, and obstacles currently use simple Phong shading
- terrain uses one flat level-theme base color for all faces; height/elevation gradients and path glow are disabled
- collision feedback temporarily overrides terrain albedo to vivid red and raises the hit column with a `0.5s` sine pop, without changing persistent terrain state
- wireframe-like terrain edges are shader-rendered in black only on visible faces
- ship rendering uses a stencil-masked 1-pixel black outline around the textured body
- ship texture/rim treatment is selected by explicit render style, not by "any non-terrain mesh", so obstacles stay visually separate from the vehicle

### SceneKit

Used for:

- store preview
- rotating showcase model
- texture/material preview

This split is currently pragmatic:

- Metal remains best for the in-game renderer
- SceneKit is faster to iterate on for showroom-style previews

## Current Known Constraints

- The preview path and gameplay path are separate, so visual parity can drift if one path changes and the other does not.
- Store stats and visuals are richer than gameplay differentiation right now.
- Local builds can fail if the machine is missing the Metal toolchain component, even when asset wiring is correct.
- Stencil use is now part of the gameplay ship outline path, so pipeline and view depth/stencil formats must stay aligned.

## Best Practices For Future Assets

When adding new ships, keep these rules:

1. Use one folder per ship.
2. Keep mesh and texture filenames aligned with the ship enum naming.
3. Ensure at least one default texture exists and follows the same naming convention.
4. Prefer consistent orientation and scale between ships.
5. If adding a new source format, do not change runtime loading unless necessary.

## Recommended Future Improvements

- Move ship definitions into a data file that also describes asset names and stats.
- Add validation tooling for missing textures or naming mismatches.
- Consider a shared material/preview helper so store preview and gameplay visuals stay closer over time.
