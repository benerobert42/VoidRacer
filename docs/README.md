# Docs Index

This folder captures the current state of the game and provides a working baseline for future design updates.

Core inspiration references used across these docs:

- `Race the Sun` for camera feel, horizon-driven speed, minimalist high-speed readability, and calm-but-tense atmosphere
- `Subway Surfers`, `Temple Run 2`, and `Crossy Road` for replay loops, progression pacing, and return motivation

Start here:

- `architecture.md`
- `gameplay-loop.md`
- `progression-and-store.md`
- `assets-and-rendering.md`
- `content-catalog.md`

Recent implementation areas these docs now cover:

- active collision feedback in normal gameplay, not only debug visualization
- quick-hit camera shake and short-lived terrain destruction on impact
- a dedicated game-over screen with fast retry and last-run summary
- a simplified home screen with only `Play` and `Store`
- a swipeable level-selection flow with live terrain previews
- a short ship drop-in animation before player control begins
- first-pass pilot progression through rank XP and run contracts
- softer terrain-collision damage with slowdown instead of instant death
- liquid-glass-inspired menu controls layered above live terrain previews

Recommended workflow:

1. Treat these docs as the factual baseline for what the code does today.
2. Edit them freely as your ideas evolve.
3. When the implementation changes, update the matching doc so the project does not drift into guesswork.

Suggested rule:

- use the docs to record intent and design rules
- use the code to record exact implementation details
- keep both aligned enough that future changes stay fast and safe
