# Architecture

This document describes the current structure of the game as implemented in the codebase.

## High-Level Stack

- `SwiftUI` drives the app shell, menu flow, store flow, and the in-game HUD.
- The iOS status bar is hidden globally so phone system chrome does not overlap menu, store, level-select, or gameplay controls.
- `GameEngineWrapper` bridges Swift and Objective-C++ into the C++ game simulation.
- `C++` owns the core simulation state for the vehicle, track, and physics update loop.
- `Metal` renders gameplay.
- `SceneKit` is currently used in the store to preview ship models with the same monochrome silver material direction used in gameplay.

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
- adaptive run visual modifiers that preserve level identity while changing only a small visual mood layer
- persistence of the last selected level
- pilot rank and pilot XP
- active contract tiers
- owned ships
- inactive skin persistence kept for future use
- equipped ship
- persistence through `UserDefaults`
- sending the currently equipped mesh and texture names to the renderer bridge
- flagging when a gameplay entry animation should play

### `MainMenuView`

Current responsibilities:

- present a simplified landing screen with only the primary actions
- show the last selected level as a live animated terrain background
- present controls as retro sci-fi neon panels instead of generic gradient or plain glass blocks
- let the player enter the store
- let the player move into the dedicated level-selection flow

This screen is now intentionally closer to `Race the Sun` minimalism than to a feature-dense mobile dashboard.

Current main-menu design contract:

- the live terrain preview must cover the full screen edge-to-edge with no black side gaps
- the top area must not contain selected mode, rank, currency, missions, or other dashboard data
- the `VOID RACER` title stands alone without a subtitle
- the only primary actions are `Play` and `Store`
- action cards use a dark translucent panel, vivid neon accent rail, thin neon border, glow, scanline icon treatment, and old-school retro-sci-fi proportions
- future menu work should preserve this direction unless the full art direction is intentionally changed

### `LevelSelectView`

Current responsibilities:

- present one level at a time in a horizontal page-style carousel
- render the selected level as a live terrain-only preview
- keep only an arrow-only back control near the upper-left safe area
- avoid rank, currency, mode, mission, and other dashboard UI on this screen
- keep the bottom selection UI to the level name plus one `Play` action
- use the same retro sci-fi neon action-card language established by the main menu
- keep the browsing flow lightweight and tactile
- let the player commit to a level with a single `Play` action

### `StoreView`

Current responsibilities:

- start on the currently equipped ship
- let the player browse ships by horizontal swiping
- show a large rotating 3D preview for each ship page
- show simplified ship attributes and price
- keep the top chrome to an arrow-only back control so the store always has a clear escape route
- use one consistent neon action color for buy/equip controls across all ships
- let the player buy or equip ships
- keep skins hidden while the core ship store is simplified

### `GameView`

Current responsibilities:

- host the Metal gameplay view
- play a short ship drop-in animation before controls unlock
- forward steering drag input to the engine
- display the minimal in-run HUD
- keep the iOS status bar hidden globally so clock, Wi-Fi, and battery chrome do not compete with app UI
- trigger near-miss messaging
- delay death handoff briefly before game-over routing
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
- ignores ship textures for the current monochrome material baseline
- falls back to generated geometry if needed
- renders terrain and obstacles with Metal
- supports a preview-only mode that scrolls terrain without gameplay input
- can hide the ship, obstacles, and chaser for menu backgrounds
- can offset the ship vertically to support entry animation
- applies a short camera shake when collisions happen
- renders a dedicated neon chaser wall instead of relying only on terrain tint
- anchors terrain instances from `track.grid.originZ`
- renders terrain in one opaque pass only
- renders visible-face neon wireframe edges inside the terrain shader
- renders the ship with a stencil-masked 1-pixel black outline so the body stays readable without glow
- renders the ship body as shiny monochrome silver using simple Phong shading and high specular response
- applies a render-only yaw boost so the ship visually faces into turns without altering controls or physics
- uses an explicit ship render style for the vehicle body so scenery and obstacle meshes cannot accidentally receive ship material shading
- accepts a constrained per-run visual modifier from SwiftUI; this only boosts existing level edge glow, path glow, and speed streaks, and never changes physics, collision, scoring, or terrain geometry

### Store Preview Rendering

The store uses a separate preview path in SwiftUI via `SceneKit`.

Current preview behavior:

- loads `OBJ` assets from the bundled ship folder
- ignores texture images while skins are paused
- applies a shiny monochrome silver Phong material to the preview geometry
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

### `Track`

Owns the current terrain grid.

The current implementation uses:

- a `60 x 80` terrain grid with gameplay constrained to the inner corridor
- height-derived terrain data
- a single per-run randomized river centerline shared by CPU collision and Metal rendering
- one active opaque terrain-column type
- transient collision-effect timers for hit feedback
- no active destructible or transparent terrain states in the baseline renderer
- no decorative terrain-like landmark columns during the stabilization baseline

### `PhysicsWorld`

Handles the per-frame update loop:

- ramps base forward speed over time
- starts the run at roughly `66` baseline forward speed
- doubles baseline forward speed every `180` seconds
- keeps the ship at the lower current hover height over the riverbed
- clamps and moves lateral steering with the original proportional snap response
- advances the chaser wall
- keeps the chaser matched to the run's baseline speed so a clean line does not lose ground passively
- force-disables reserved power-up timers while the solid-terrain baseline is active
- checks hull collisions
- checks graze state
- updates score multiplier
- updates score
- accumulates run credits over time and from stylish play
- converts terrain impacts into health loss and slowdown instead of immediate death
- records hit cells as short-lived world-grid collision effects
- rebuilds the visible terrain grid from deterministic height data plus transient collision-effect timers
- does not currently mutate terrain cells for pads, destruction, or persistent collision state

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
- inactive skin ownership data
- equipped ship
- inactive equipped-skin data kept for future use

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
