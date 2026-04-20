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

Each ship currently supports these skins:

- Blue
- Green
- Orange
- Purple
- Red

Current global skin prices:

- Blue: free
- Green: 180
- Orange: 240
- Purple: 320
- Red: 420

## Track Content

The procedural terrain grid can currently include:

- standard terrain columns
- destructible cells
- boost pads
- elevation pads
- flatten pads

Reserved but currently not meaningfully active in the visible game loop:

- turrets
- equalizer cells

## HUD Content

Current in-run HUD includes:

- score
- run coin total
- hull percent
- grazing indicator
- near-miss text feedback

## Current Content Rules

- ship ownership persists across launches
- skin ownership persists across launches
- each owned ship automatically has its blue skin available
- the equipped ship determines the gameplay mesh and texture used during the run

## Open Content Questions

These are not yet settled in code:

- whether ship stats should affect actual gameplay
- whether different levels should reward different currencies or progression tracks
- whether some skins should become achievement unlocks instead of store purchases
- whether each ship should get unique abilities beyond stat tuning
