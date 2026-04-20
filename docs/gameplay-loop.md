# Gameplay Loop

This document describes the current playable loop based on the code today.

## Core Fantasy

The current game feels like an arcade hover-racer flying low over a stylized terrain field while avoiding lethal terrain columns and staying ahead of a chaser wall.

The current presentation direction mixes:

- neon sci-fi styling
- endless-runner pressure
- near-miss scoring
- collectible garage progression

`Race the Sun` should be treated as a core reference for the intended feel of this loop:

- the ship should stay compositionally centered and readable
- the world should create pressure through horizon flow and silhouette timing
- speed should feel clean and elegant, not chaotic or visually noisy
- sessions should have a calm-but-intense rhythm

## Current Run Loop

1. The player opens to a simplified home screen with only `Play` and `Store`.
2. The home screen background shows the last selected level animating behind the UI as terrain-only motion.
3. Choosing `Play` opens a swipe-based level-selection screen.
4. Each level page shows a live terrain preview for that level without the ship.
5. Choosing `DROP IN` starts a run with the currently equipped ship and skin.
6. The ship appears above the terrain and falls into the level before control is handed over.
7. The vehicle automatically moves forward.
8. The player steers left and right by dragging.
9. The player survives by avoiding terrain collisions and not letting the chaser overtake them.
10. The player can pass close to danger to trigger graze state.
11. Graze state raises score multiplier and improves run-credit gain.
12. Three live run contracts track survival, credits, and near misses.
13. The player may hit rare terrain pads that apply temporary effects.
14. Terrain collisions now damage the ship and slow it down instead of killing instantly.
15. Impacted columns flash red, pop upward, glow, and collapse away over about `0.5` seconds.
16. A short camera shake reinforces the impact before the UI changes.
17. The run ends when health reaches zero or the chaser catches the player.
18. Credits earned during the run are combined with contract/rank rewards.
19. Death routes to a dedicated game-over screen with a prominent retry option and last-run summary.

## Current Skill Drivers

The current game rewards:

- lane control
- precision steering
- staying calm at increasing speeds
- flirting with danger to keep graze value active

## Current Failure States

A run can currently end from:

- direct terrain collision
- health loss from obstacle collision
- the chaser wall catching the player

In debug mode, some lethal behavior is softened to support testing.

## Current Collision Feedback

Normal gameplay now surfaces collisions more like a premium mobile arcade runner instead of keeping that feedback in debug-only space.

Current behavior:

- terrain cells struck by the ship are marked red immediately
- those cells rise slightly, glow, and collapse away over `0.5` seconds
- the gameplay camera applies a quick impact shake
- the run stays in gameplay long enough for that feedback to read before the game-over screen appears
- the ship now survives repeated terrain hits, but each impact costs health and briefly slows forward speed

This direction is intentionally aligned with successful endless-runner UX:

- `Race the Sun`: keep the failure moment readable and compositionally clean
- `Subway Surfers`: reset quickly, but not so quickly that the player misses what happened
- `Temple Run 2`: make retry friction low and the fail state legible

## Current Run Systems

### Speed Ramp

The run starts at a lower speed and increases steadily over time.

Current implementation details:

- starts around `70`
- ramps toward `140` over the first minute
- caps at `300`

This creates a natural pressure curve even before the chaser and terrain complexity are considered.

### Early Progression Layer

The first phase of the progression ladder is now in the game.

Current behavior:

- the player has a persistent pilot rank
- runs grant XP based on survival time, style, score, and credits earned
- three persistent contract tracks reward survival time, banked credits, and near misses
- completed contracts immediately tier up to the next target
- contracts and rank rewards add bonus credits on top of run credits

This adds short-term purpose without changing the core controls.

### Steering

Steering is drag-based.

Current behavior:

- horizontal drag is mapped into a steering range of `-1` to `1`
- the simulation moves toward a target lateral position
- return-to-center is slower than active steering

This gives the movement a controlled hover feel rather than an instant lane snap.

Future steering/camera target:

- move closer to `Race the Sun` readability
- keep the ship compositionally centered on screen
- let terrain define the danger envelope
- avoid camera behavior that makes the ship feel detached from player intent

### Graze System

The vehicle has both:

- a lethal hull radius
- a wider graze radius

Current behavior:

- when the player passes near terrain without colliding, `isGrazing` becomes true
- score multiplier rises while grazing
- multiplier slowly decays when not grazing
- HUD feedback reinforces the near-miss moment

This is the most important "high-skill, high-style" scoring mechanic in the current build.

It now also matters more to progression because near misses feed one of the active run contracts.

### Chaser

The chaser is a constantly advancing wall behind the player.

Current behavior:

- advances every frame
- matches the ship's non-boost baseline forward speed
- can become more distant when the player hits boost
- kills the player instantly when it overtakes them, except in debug mode
- is reinforced visually by a dedicated neon wall and stronger warning glow on nearby terrain

This system prevents passive play and keeps every run urgent.

This urgency should increasingly take inspiration from `Race the Sun`:

- failure pressure should come from relentless forward commitment
- survival should feel like threading through a hostile horizon
- the player should feel that distance itself is the score fantasy

### Terrain Pads

The current track generation can place rare special pads:

- `BoostPad`
- `ElevationPad`
- `FlattenPad`

Current effects:

- `BoostPad`: temporary speed boost
- `ElevationPad`: raises flight height temporarily
- `FlattenPad`: sends a forward wave that marks a path of cells as destroyed, but only through the terrain window that existed when the effect was triggered

## Current Death Flow

The game now uses a two-step fail flow instead of dropping instantly back to menu.

Current order:

1. The player dies.
2. Impact feedback continues briefly in the gameplay scene.
3. Run coins are banked.
4. The app transitions to a dedicated game-over screen.
5. The player can retry immediately or return to the main menu.

This is the right shape for the current game because it supports the `Race the Sun` goal of clean high-speed readability while also following strong mobile retry conventions.

## Current Menu Flow

The front-end flow now leans more deliberately into premium mobile arcade conventions:

- `Race the Sun` for a minimal front door and strong focus on the run itself
- `Temple Run 2` and `Subway Surfers` for low-friction movement from front door to level or run choice
- large animated environmental previews instead of static level thumbnails

Current behavior:

- home is intentionally sparse and fast to parse
- level browsing is swipe-driven rather than list-driven
- level commitment uses a single clear call to action
- the start of a run has a short authored arrival beat instead of an abrupt spawn

## Current Meta Loop

Outside of a run, the current player loop is:

1. bank coins from a run
2. visit the store
3. unlock a ship or skin
4. equip a new look
5. start another run

Right now this is mostly a cosmetic and collection loop, because ship stats shown in the store do not yet change runtime gameplay.

## Current Design Strengths

- The run starts readable and becomes more intense.
- Graze adds style-based scoring, not just survival.
- The store creates a reason to keep banking coins.
- Ships and skins give the player visible ownership and identity.
- Failure now has visible payoff and a low-friction retry path instead of an abrupt menu drop.

## Current Gaps

- Ship stats are not yet connected to the simulation.
- Progression is collection-driven more than mechanic-driven.
- The game does not yet have missions, streak goals, or daily systems.
- There is not yet a strong reason to prefer one ship in a gameplay sense.

## Good Future Extension Directions

These fit the current code direction well:

- tie life/armor/speed/agility to the actual `Vehicle` setup
- add short-term goals like "graze streak" or "distance survived"
- add milestone unlocks that sit between skins and whole ships
- introduce limited-time or level-specific rewards later if desired

Additional guidance from `Race the Sun`:

- prioritize visual clarity over clutter
- keep the first two seconds of every run immediately legible
- build mastery through obstacle reading and rhythm, not only upgrade accumulation
- let menu transitions feel like extensions of the world, not detached utility screens
