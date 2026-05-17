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
5. The level-selection UI stays sparse: arrow-only back control, level name, and a single `Play` action.
6. Choosing `Play` starts a run with the currently equipped ship.
7. The ship appears above the terrain and falls into the level before control is handed over.
8. The vehicle automatically moves forward.
9. The player steers left and right by dragging.
10. The player survives by avoiding terrain collisions and not letting the chaser overtake them.
11. The player can pass close to danger to trigger graze state.
12. Graze state raises score multiplier and improves run-credit gain.
13. Three live run contracts track survival, credits, and near misses.
14. Terrain collisions damage the ship and slow it down instead of killing instantly.
15. A short camera shake reinforces the impact.
16. The in-run HUD stays sparse: centered life bar, thinner armor bar, and score below them.
17. The iOS status bar is hidden across all app views so system chrome does not overlap or visually compete with the game UI.
18. Contract and mission detail is reserved for pause/post-run surfaces instead of crowding the notch area during play.
19. The run ends when health reaches zero or the chaser catches the player.
20. Credits earned during the run are combined with contract/rank rewards.
21. Death routes to a dedicated game-over screen with a prominent retry option and last-run summary.

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

The current baseline keeps collision feedback visual-only while terrain rendering is being stabilized.

Current behavior:

- the gameplay camera applies a quick impact shake
- the ship now survives repeated terrain hits, but each impact costs health and briefly slows forward speed
- hit terrain cells turn vivid red, pop upward, and settle back down over roughly `0.5s`
- terrain cells do not change type, transparency, collision behavior, or lifetime when hit
- no collision, power-up, or destruction system currently mutates persistent terrain geometry

This direction is intentionally aligned with successful endless-runner UX:

- `Race the Sun`: keep the failure moment readable and compositionally clean
- `Subway Surfers`: reset quickly, but not so quickly that the player misses what happened
- `Temple Run 2`: make retry friction low and the fail state legible

## Current Run Systems

### Speed Ramp

The run starts at a lower speed and increases steadily over time.

Current implementation details:

- starts around `66`
- doubles every `180` seconds
- the chaser matches the same baseline speed so clean driving does not lose ground passively
- the ship now flies lower over the terrain, at roughly half the previous hover height

This creates a natural pressure curve while keeping terrain geometry stable.

### Riverbed Stability

The baseline terrain now uses a single stable river centerline per run, with randomized curve parameters on each new game start.

Current implementation details:

- no time-based curve-frequency ramp
- no split or branching riverbed in the stabilization baseline
- every new `Track` samples constrained river phases, frequency scale, and curve scale
- the river centerline starts at full procedural curvature instead of using an origin warm-up zone
- CPU collision terrain and Metal-rendered terrain share the same randomized single-channel distance function

This prevents the opening section from producing merged branch channels, while avoiding identical memorized starts across runs.

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
- lateral movement uses the original proportional snap response so touch intensity remains immediate
- ship yaw has a render-only turn attitude boost so the hull visibly faces into turns without changing input or physics
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
- kills the player instantly when it overtakes them, except in debug mode
- is reinforced visually by a dedicated neon wall

This system prevents passive play and keeps every run urgent.

This urgency should increasingly take inspiration from `Race the Sun`:

- failure pressure should come from relentless forward commitment
- survival should feel like threading through a hostile horizon
- the player should feel that distance itself is the score fantasy

### Terrain Pads

Terrain pads are temporarily disabled while the baseline terrain renderer is being solidified.

Current baseline:

- no boost pads
- no elevation pads
- no passive flatten pads outside the active skill collectible prototype
- no destructible or transparent terrain columns
- power-up timers are force-reset each frame so no stale effects can survive between terrain revisions

### Skill Collectible Prototype

The first ship-skill pickup is now prototyped as a glowing red cube hovering near ship height.

Current behavior:

- red skill cubes spawn periodically on the river centerline ahead of the ship
- skill cubes are intentionally compact, render with an emissive red core plus a black silhouette shell, and visually oscillate vertically
- the visual oscillation has a large amplitude for readability, but collection uses stable X/Z placement so the bob phase cannot make the player miss it
- collecting one triggers a timed forward flatten charge
- the flatten charge marks a 5-column-wide by up-to-40-row-long fixed-world area directly ahead of the ship
- flattened cells remain active for 3 seconds, are lowered in the terrain shader, and are ignored by terrain collision
- flattened records are also pruned once their world-space cells scroll out of the active terrain window
- this is intentionally implemented as transient cell flags, not permanent terrain mutation

### Jump Spring Prototype

The second active skill is a riverbed spring pad.

Current behavior:

- jump springs spawn periodically as `2 x 2` terrain-cell blocks inside the riverbed
- all four spring cells share one animation phase, so the `2 x 2` block moves up and down as a single platform
- spring cells render vivid red and use strong black visible edges for readability
- pickup detection uses an expanded swept footprint over the full block so high-speed movement should not skip the trigger
- flying over a spring raises the ship from normal riverbed clearance to roughly `4x` that clearance over 0.5 seconds
- the ship then cruises at the elevated height for 2 seconds with a `1.5x` forward-speed multiplier
- the ship falls back to normal flight height over the next 0.5 seconds while forward motion continues normally
- the gameplay camera follows the elevated ship because the camera target is tied to the vehicle position
- jump launch adds a large blue-white vertical streak under the ship
- elevated cruise strongly increases forward speed streak density, size, length, and brightness
- the camera follows the ship height directly, with only a mild backward pull and FOV widen during launch/cruise
- terrain cools and desaturates strongly while airborne to make altitude separation easier to read
- far terrain fades into jump fog while airborne so camera elevation does not expose the streamed terrain end

### Terrain Readability

Current behavior:

- all terrain columns render as one opaque column type with backface culling
- carved playable path surfaces receive a stronger neon top glow
- terrain edges receive additive neon wireframe treatment only on visible faces
- decorative landmark cubes are disabled for the baseline so there are no extra grid-like columns moving with the ship
- the ship has a stencil-masked 1-pixel black outline to keep it readable without glow
- ship material shading is opt-in through the vehicle render style, so non-ship scenery cannot inherit ship coloration

### Adaptive Visual Mood Layer

The game now keeps level identity separate from per-run mood.

Current behavior:

- each level keeps its authored base palette, geometry profile, and terrain identity
- after a run ends, `AppState` selects a constrained next-run mood from local telemetry
- current moods are `BASELINE`, `RECOVERY`, `FLOW`, and `OVERDRIVE`
- the modifier adjusts existing visual knobs only: path glow, visible terrain edge color/thickness, riverbed floor tint, and speed streak density/brightness
- the modifier never changes controls, scoring, collision, terrain generation, or difficulty
- this deterministic selector is the safe fallback path for a future Apple Intelligence visual director

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
3. unlock or equip a ship
4. start another run

Right now this is mostly a collection loop, because ship stats shown in the store do not yet change runtime gameplay.

## Current Design Strengths

- The run starts readable and becomes more intense.
- Graze adds style-based scoring, not just survival.
- The store creates a reason to keep banking coins.
- Ships give the player visible ownership and identity.
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
- add milestone unlocks that sit between whole ships
- introduce limited-time or level-specific rewards later if desired

Additional guidance from `Race the Sun`:

- prioritize visual clarity over clutter
- keep the first two seconds of every run immediately legible
- build mastery through obstacle reading and rhythm, not only upgrade accumulation
- let menu transitions feel like extensions of the world, not detached utility screens
