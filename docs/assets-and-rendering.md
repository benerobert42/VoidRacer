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
- applies the selected texture to preview materials
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
