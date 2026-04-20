# Architecture

This document describes the current structure of the game as implemented in the codebase.

## High-Level Stack

- `SwiftUI` drives the app shell, menu flow, store flow, and the in-game HUD.
- `GameEngineWrapper` bridges Swift and Objective-C++ into the C++ game simulation.
- `C++` owns the core simulation state for the vehicle, track, and physics update loop.
- `Metal` renders gameplay.
- `SceneKit` is currently used in the store to preview ship models with their selected textures.

## App Flow

The top-level app state lives in `SkiRacingGame/Sources/App/AppState.swift`.

Current screens:

- `menu`
- `levelSelect`
- `store`
- `game`
- `gameOver`

`ContentView` switches between those screens based on `AppState.currentScreen`.

## Main App Responsibilities

### `AppState`

`AppState` is the main orchestration object for:

- screen navigation
- player currency
- selected level
- persistence of the last selected level
- pilot rank and pilot XP
- active contract tiers
- owned ships
- unlocked skins
- equipped ship and equipped skin
- persistence through `UserDefaults`
- sending the currently equipped mesh and texture names to the renderer bridge
- flagging when a gameplay entry animation should play

### `MainMenuView`

Current responsibilities:

- present a simplified landing screen with only the primary actions
- show the last selected level as a live animated terrain background
- present controls as a glass-like floating layer instead of solid gradient blocks
- let the player enter the store
- let the player move into the dedicated level-selection flow

This screen is now intentionally closer to `Race the Sun` minimalism than to a feature-dense mobile dashboard.

### `LevelSelectView`

Current responsibilities:

- present one level at a time in a horizontal page-style carousel
- render the selected level as a live terrain-only preview
- use the same glass-like control layer for lightweight browsing controls
- keep the browsing flow lightweight and tactile
- let the player commit to a level with a single `DROP IN` action

### `StoreView`

Current responsibilities:

- show a large rotating 3D preview of the selected ship
- let the player browse skins for that ship
- show ship attributes and price
- let the player buy or equip ships
- let the player buy or equip skins
- show garage progression framing

### `GameView`

Current responsibilities:

- host the Metal gameplay view
- play a short ship drop-in animation before controls unlock
- forward steering drag input to the engine
- display the HUD
- show live contract progress during the run
- trigger near-miss messaging
- delay death handoff long enough for collision feedback to play
- bank run coins into the persistent store economy when a run ends

### `GameOverView`

Current responsibilities:

- show a dedicated post-death state instead of dropping directly to menu
- display last-run score
- display the credits gained from the last run
- display XP gained and current pilot rank
- display contracts cleared during the run
- offer a prominent retry action
- offer a secondary return-to-menu action

## Rendering Systems

### Gameplay Rendering

Gameplay rendering is handled by:

- `SkiRacingGame/Sources/GraphicsEngine/GameRenderer.mm`
- `SkiRacingGame/Sources/GraphicsEngine/AssetManager.mm`
- `SkiRacingGame/Sources/GraphicsEngine/Shaders.metal`

Current renderer behavior:

- loads the equipped ship mesh by name
- loads the equipped texture by name
- falls back to generated geometry if needed
- renders terrain and obstacles with Metal
- supports a preview-only mode that scrolls terrain without gameplay input
- can hide the ship, obstacles, and chaser for menu backgrounds
- can offset the ship vertically to support entry animation
- renders transient collision feedback for impacted terrain cells
- applies a short camera shake when collisions happen
- renders a dedicated neon chaser wall instead of relying only on terrain tint

### Store Preview Rendering

The store uses a separate preview path in SwiftUI via `SceneKit`.

Current preview behavior:

- loads `OBJ` assets from the bundled ship folder
- loads the selected texture from that ship's `Textures` folder
- applies the texture to the preview geometry
- rotates the ship slowly in place

This keeps the store preview decoupled from the gameplay renderer.

### Menu Preview Rendering

The home screen and level-selection screen now use the main Metal renderer in a non-gameplay preview configuration.

Current preview behavior:

- scroll terrain continuously toward the camera without moving the actual gameplay vehicle
- force the requested level palette for each preview
- hide the ship, obstacles, and chaser
- keep the camera locked to a clean forward-looking composition inspired by `Race the Sun`

## Game Simulation

The core simulation is in `SkiRacingGame/Sources/GameLogic/`.

Main types:

- `GameEngine`
- `Vehicle`
- `Track`
- `PhysicsWorld`

### `GameEngine`

Owns:

- the current `Vehicle`
- the current `Track`
- the `PhysicsWorld`
- current level type
- total elapsed run time

It resets the run when the level changes.

### `Vehicle`

Owns the player run state:

- position and velocity
- health
- steering input
- run coins
- run coin accumulation state
- score
- a short impact shake timer used by the renderer
- a terrain-impact slowdown timer and damage cooldown
- graze and overdrive values
- chaser state
- boost, elevation, and flatten-wave timers

### `Track`

Owns the current terrain grid and procedural cell flags.

The current implementation uses:

- a `60 x 80` terrain grid with gameplay constrained to the inner corridor
- height-derived terrain data
- rare boost pads
- rare elevation pads
- rare flatten pads
- flags for destructible, collision-feedback, and destroyed states
- a short collision effect timer on each impacted cell

### `PhysicsWorld`

Handles the per-frame update loop:

- ramps base forward speed over time
- applies boost multipliers
- clamps and moves lateral steering
- advances the chaser wall
- keeps the chaser matched to the run's baseline speed so a clean line does not lose ground passively
- applies elevation state
- propagates the flatten-wave effect
- checks hull collisions
- checks graze state
- updates score multiplier
- updates score
- accumulates run credits over time and from stylish play
- converts terrain impacts into health loss and slowdown instead of immediate death
- decays impact feedback timers after death so visuals can finish cleanly
- rebuilds the visible terrain grid from world-space destruction and collision records so streamed terrain does not inherit stale slot-based effects

## Assets

Assets currently live under `SkiRacingGame/Assets/`.

Each ship folder can contain:

- `OBJ`
- `Textures`
- optionally `Blend`, `FBX`, and `glTF`

The shipping gameplay/store flow currently relies on:

- `Executioner`
- `Challenger`
- `Dispatcher`
- `Imperial`
- `Insurgent`

The old `Bob` flow has been replaced by these ship folders.

## Persistence

Persistent player data currently uses `UserDefaults`.

Stored values:

- coins
- pilot rank
- pilot XP
- contract tiers
- owned ships
- unlocked skins
- equipped ship
- equipped skins per ship

## Current Architectural Notes

- Store stats are currently presentation data only. They do not yet affect gameplay physics or survivability.
- Gameplay still uses one shared `Vehicle` simulation profile regardless of the equipped ship.
- The store economy is persistent across launches, while run currency is banked after a run.
- Post-death flow now intentionally pauses on the gameplay scene for roughly half a second so impact feedback and camera shake can land before transitioning to the game-over UI.
- Metal remains the runtime dependency for gameplay builds. Missing local Metal toolchain components can block local builds even when Swift/UI code is valid.

## Recommended Next Steps

When the project grows, the cleanest next architectural moves are:

1. Introduce a shared gameplay balance model so ship stats can affect the real simulation.
2. Move content definitions into a dedicated data source instead of hardcoding them in Swift enums.
3. Separate "current implementation" docs from "target design" docs once the project begins evolving faster.
