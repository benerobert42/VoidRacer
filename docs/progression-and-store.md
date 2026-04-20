# Progression And Store

This document captures the current garage, economy, and store design as implemented in code, plus a few best-practice notes for future tuning.

## Current Progression Philosophy

The current system mixes two motivational loops:

- short-term wins through skin unlocks
- longer-term goals through ship unlocks
- first-pass pilot rank progression through XP and run contracts

This is a strong foundation for retention because players can make visible progress even when they cannot yet afford the next major unlock.

`Race the Sun` should also be a reference here, especially for how progression can support a pure run loop without burying it:

- progression should sharpen identity and mastery
- progression should not bury the elegance of "start run fast, survive longer, chase distance"
- unlocks should enhance the fantasy of flight and precision, not overpower it

## Current Economy

### Currency

The game currently uses a single persistent soft currency:

- `coins` in the code
- presented as `credits` in the store UI

The player earns coins during a run and banks them when the run ends.

When the player dies, the gained amount is surfaced in the game-over UI so the run still ends with visible progress.

The current run payout now has multiple layers:

- run credits earned during gameplay
- contract completion rewards
- pilot-rank reward credits when a rank-up happens

## Current Pilot Progression

The first progression-ladder phase is now implemented as a lightweight meta system.

Current behavior:

- the player has a persistent `pilot rank`
- the player earns `XP` after each run
- XP comes from survival, score, near misses, and earned credits
- rank-ups grant bonus credits
- three active contracts scale upward each time they are cleared

Current contract tracks:

- survive for a target number of seconds
- bank a target number of credits in one run
- land a target number of near misses in one run

### Current Starting State

New players currently begin with:

- one owned ship: `Executioner`
- one unlocked default skin: `Executioner_Blue`
- a starting currency balance in `AppState`

## Current Unlock Catalog

### Ships

Current ship prices:

- `Executioner`: free starter
- `Challenger`: `850`
- `Dispatcher`: `1350`
- `Imperial`: `1850`
- `Insurgent`: `2400`

### Skins

Each ship currently has the same skin price ladder:

- `Blue`: free/default
- `Green`: `180`
- `Orange`: `240`
- `Purple`: `320`
- `Red`: `420`

## Current Store Layout

The store is intentionally structured to make choices feel concrete and aspirational.

Current order:

1. Large 3D rotating ship preview
2. Skin choices for the selected ship
3. Attribute and pricing section
4. Garage list of all ships

This layout supports a mobile-game style loop:

- show the reward first
- offer cosmetic variation second
- justify the purchase with stats and pricing third
- keep the larger catalog visible below

## Current Ship Stats

Current displayed stats:

- life
- armor
- speed
- agility

These values currently support presentation and future balancing direction. They do not yet change runtime gameplay behavior.

## Current Progression Notes By Ship

### Executioner

- free starter ship
- forgiving first collectible anchor
- default blue skin available immediately

### Challenger

- first aspirational ship
- close enough in price to feel reachable early

### Dispatcher

- heavier, tank-flavored fantasy
- good mid-tier "I own something different now" unlock

### Imperial

- prestige-oriented unlock
- meant to feel more premium in presentation

### Insurgent

- current end-of-ladder target
- highest price
- strongest "garage completion" energy

## What Makes This Loop Addictive In Practice

Strong mobile progression loops usually stack several layers of reward:

- immediate feedback from the current run
- a clear post-run summary so the player understands what that run earned
- a visible banked currency total
- a cheap next purchase that feels close
- a bigger aspirational unlock to chase afterward
- collection progress that increases identity and ownership

The current system already supports this shape fairly well.

The current fail-state UI now leans into a proven endless-runner pattern:

- primary `try again` action
- secondary exit action
- visible last-run result
- visible banked currency win even on failure

That structure is consistent with the fast-reset rhythm seen across successful iOS arcade runners and helps keep failure from feeling like lost time.

It is now also the moment where contract clears and pilot-rank gains are surfaced, which gives failed runs a stronger sense of forward motion.

## Best-Practice Tuning Principles

If the goal is stronger retention without making the game feel manipulative, these are the best next rules to follow:

### 1. Keep A Short-Term Goal Always Reachable

Players should almost always have something nearby:

- a skin they can afford soon
- a ship that feels like the next milestone

Dead zones where nothing feels reachable usually hurt momentum.

### 2. Make Ships Change Play, Not Just Price

The store becomes much stronger if stats matter in real gameplay.

Good future mapping:

- life -> total survivability
- armor -> collision damage reduction
- speed -> forward acceleration or top-speed modifier
- agility -> steering response and lateral snap speed

### 3. Use Cosmetics As Recovery Rewards

When the player cannot yet buy the next ship, a skin purchase keeps the loop alive.

That is one of the healthiest reasons to keep cosmetics cheaper than ships.

### 4. Show Collection Progress Often

Visible progress bars or "owned X/Y ships" helps because completion itself becomes motivating.

The current store already hints at this with garage and unlock counts.

### 5. Avoid Overcomplicating Currencies Too Early

Right now, one persistent soft currency is the correct choice.

Adding premium currencies, shards, or multiple overlapping resources too early would add noise without enough systemic depth yet.

## Recommended Future Progression Features

These fit the current game especially well:

- mission objectives tied to grazing, distance, or survival time
- unlock tracks for each ship
- skin sets earned by mastery, not only currency
- daily or weekly challenges once the run loop is stable
- milestone bonuses for owning multiple ships

Additional `Race the Sun`-inspired directions:

- objective chains that unlock ship improvements or variants
- leaderboard and best-distance framing that keeps raw run performance prestigious
- lightweight daily variation that refreshes the terrain feel without changing the core fantasy

## What To Keep Updated In This Document

Whenever progression changes, this file should be updated for:

- prices
- stat meanings
- unlock order
- currency rules
- what is cosmetic only vs gameplay-affecting
