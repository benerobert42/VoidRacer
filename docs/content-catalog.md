# Content Catalog

This is the current playable and store-facing content catalog based on the code.

## Levels

Current levels are defined in `AppState.swift`.

### `NEON SYNTHWAVE`

- subtitle: `Cyan and Magenta grids`
- icon: `network`

### `FIERY RETROWAVE`

- subtitle: `Scorched neon wasteland`
- icon: `flame`

### `CYBERPUNK VOID`

- subtitle: `Terminal hacker space`
- icon: `cpu`

### `DEBUG MODE`

- subtitle: `Constant speed, visual logging`
- icon: `ant.fill`

## Ships

### Executioner

- price: free
- role: starter all-rounder
- stats:
  - life: 3
  - armor: 2
  - speed: 3
  - agility: 4
- symbol: `paperplane.fill`

### Challenger

- price: 850
- role: early aspirational unlock
- stats:
  - life: 3
  - armor: 3
  - speed: 4
  - agility: 4
- symbol: `bolt.horizontal.circle.fill`

### Dispatcher

- price: 1350
- role: heavy/tank fantasy ship
- stats:
  - life: 5
  - armor: 5
  - speed: 2
  - agility: 2
- symbol: `shield.lefthalf.filled`

### Imperial

- price: 1850
- role: prestige mid-late unlock
- stats:
  - life: 4
  - armor: 4
  - speed: 4
  - agility: 3
- symbol: `crown.fill`

### Insurgent

- price: 2400
- role: top-tier chase unlock
- stats:
  - life: 4
  - armor: 3
  - speed: 5
  - agility: 5
- symbol: `flame.fill`

## Skins

Skin texture assets currently exist for each ship:

- Blue
- Green
- Orange
- Purple
- Red

Visible skin buying/equipping is currently paused.

The active game and store preview path ignores these textures and renders every ship with the default shiny silver material while the ship-only store is being stabilized.

## Track Content

The procedural terrain grid can currently include:

- standard terrain columns

Reserved but currently not meaningfully active in the visible game loop:

- destructible cells
- boost pads
- elevation pads
- flatten pads
- turrets
- equalizer cells

## HUD Content

Current in-run HUD includes:

- score
- centered life bar
- centered armor bar
- near-miss text feedback

The iOS status bar is hidden across all app views so clock, Wi-Fi, and battery chrome do not overlap menu, store, level-selection, or gameplay controls.

Mission/contract detail is intentionally kept out of the active top HUD and should appear on pause or post-run surfaces.

## Current Content Rules

- ship ownership persists across launches
- inactive skin ownership data may persist from earlier builds
- each ship currently renders with the default shiny silver material
- the equipped ship determines the gameplay mesh used during the run

## Open Content Questions

These are not yet settled in code:

- whether ship stats should affect actual gameplay
- whether different levels should reward different currencies or progression tracks
- whether skins should return as mastery or achievement unlocks
- whether each ship should get unique abilities beyond stat tuning
