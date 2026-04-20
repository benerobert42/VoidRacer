# Future Ideas

This document captures forward-looking design ideas for making the game loop more engaging, more replayable, and more identity-driven. It is intentionally more speculative than the other docs in this folder.

The goal is to preserve a clear design direction while the implementation evolves.

## Design Goals

The future version of the game should aim for:

- stronger "one more run" energy
- higher player attachment to ships
- more meaningful progression between runs
- more reasons to return daily
- better differentiation between ships
- more player expression through both cosmetics and gameplay style

## Reference Patterns From Successful iOS Games

These ideas are informed by retention and engagement patterns commonly used by successful iOS games such as:

- [Race the Sun](https://apps.apple.com/us/app/race-the-sun/id700227648)
- [Subway Surfers](https://apps.apple.com/us/app/subway-surfers/id512939461)
- [Temple Run 2](https://apps.apple.com/us/app/temple-run-2-endless-escape/id572395608)
- [Crossy Road](https://apps.apple.com/us/app/crossy-road/id924373886)
- [Archero](https://apps.apple.com/us/app/archero/id1453651052)
- [Survivor.io](https://apps.apple.com/us/app/survivor-io/id1528941310)

The most relevant recurring patterns are:

- pure, fast, horizon-driven run readability
- calm visual composition paired with intense survival pressure
- challenge/objective-based unlock structure
- short-term mission goals layered on top of the main run loop
- visible collection progress
- multiple reward horizons
- daily or event-based variation
- character or hero-specific gameplay identity
- a strong "aspirational unlock" ladder

`Race the Sun` is especially important as a reference because it proves that a game can feel addictive and premium while staying visually disciplined and mechanically simple.

## Future Main Loop Vision

The ideal future loop:

1. The player logs in and sees a few clear goals.
2. The player chooses a ship based on playstyle, not only appearance.
3. A run begins with a specific intention:
   - finish a mission
   - push a score
   - level a ship
   - earn enough credits for a target unlock
4. During the run, the player makes meaningful choices:
   - when to use the ship's special skill
   - whether to play safely or push graze risk
   - whether to route toward utility pads
5. The run ends with layered rewards:
   - credits
   - mission progress
   - ship mastery progress
   - event progress
   - cosmetic or upgrade unlock movement
6. The store and progression screens convert that outcome into a visible next goal.

## Recommended System Additions

## 1. Mission System

Add three concurrent goals at a time.

Example mission categories:

- survive for `X` seconds
- graze `X` columns
- hit `X` boost pads
- finish with overdrive above a threshold
- travel a certain distance with a specific ship
- avoid collisions for a full run segment

Why this matters:

- gives every run purpose
- reduces the chance that failed high-score attempts feel wasted
- increases session variety without changing the core controls

Recommended structure:

- `1` easy mission
- `1` medium mission
- `1` ship-specific or event-specific mission

## 2. Ship Mastery Tracks

Each ship should have its own mastery path.

Mastery can reward:

- exclusive skins
- small badges or profile markers
- alternate ship VFX
- discounted themed cosmetics
- eventually skill upgrades or modifiers

Why this matters:

- makes ship ownership more personal
- gives players a reason to revisit ships they already own
- turns the garage into a progression space instead of just a store

## 3. Graze Combo Layer

The graze mechanic is already one of the strongest parts of the current game. It should become the main high-skill loop.

Recommended additions:

- graze chain counter
- combo break penalty
- milestone rewards every `N` grazes
- temporary overdrive or charge bursts from sustained risky play
- stronger audiovisual feedback at combo thresholds

Why this matters:

- increases tension
- creates memorable run moments
- makes advanced play style-driven instead of purely defensive

## 4. Rotating Events

Add temporary event rules that change the run texture without requiring a new game mode.

Examples:

- `Low Altitude Week`
  More graze score, lower safe clearance, better rewards

- `Heavy Hull Cup`
  Bonus rewards for armored ships

- `Overdrive Storm`
  Graze and boost interactions are amplified

- `Pathbreaker Trial`
  More dense terrain, higher value for destruction skills

Why this matters:

- gives returning players novelty
- makes the store feel more alive
- creates reasons to revisit multiple ships

## 5. Better Reward Horizons

The player should always have:

- something they can earn soon
- something they are building toward mid-term
- something aspirational at the top end

Recommended layers:

- short-term: skins, mission rewards, mastery ticks
- mid-term: ship unlocks, ship skill upgrades
- long-term: prestige cosmetics, completion sets, event-limited rewards

Why this matters:

- smooths out progression pacing
- prevents "nothing feels reachable" dead zones

## 6. Stronger Store Feedback

The store should always answer:

- what do I own?
- what can I nearly afford?
- what is my next best target?
- what do I gain from buying this?

Recommended additions:

- "Next unlock in X credits"
- ownership counts by ship and by skin
- mastery progress on the ship card
- clearer display of ship skill fantasy

## Refining The Main Game Loop

The current loop is strong in feel, but still underdeveloped in choice.

Current loop:

- steer
- avoid
- graze
- survive
- bank credits

Future loop should become:

- choose ship for a purpose
- enter run with active goals
- use skill at the right time
- decide between safety and greed
- chase combo/missions/mastery simultaneously
- convert performance into progression

This means each run should support three different motivations at once:

- survival motivation
- style/score motivation
- progression motivation

The `Race the Sun` lesson here is important:

- the base run must stay satisfying even before meta rewards are considered
- progression should amplify replayability, not compensate for a weak run
- the clean "one more attempt" feeling is part of the product identity

## Ship Special Skill Framework

Each ship should have exactly one signature active skill.

The skill should:

- be easy to understand
- look visually exciting
- support a distinct playstyle
- create clutch moments
- reinforce the ship fantasy

Each skill should also use one shared rule system so the game stays readable.

Recommended shared rules:

- every ship has one active ability
- ability charges through gameplay, preferably through risky or skillful play
- abilities should not fully erase the need for steering
- most skills should solve one type of problem better than others
- cooldowns or charge gain should be tuned around one or two strong uses per meaningful run segment

Important guardrail from `Race the Sun`:

- ship skills must not destroy the purity of obstacle reading and forward flow
- abilities should create clutch expression, not turn the game into ability spam

Recommended charge sources:

- grazing
- distance survived
- hitting pads
- collecting charge pickups later if desired

## Proposed Ship Skills

These are first-pass proposals, intended to establish ship identity.

### Executioner

Fantasy:

- precise attack interceptor

Skill:

- `Laser Cutter`

Behavior:

- fires a focused forward beam
- destroys or clears a path through a narrow set of terrain columns ahead
- best used reactively when boxed in

Why it works:

- easy to understand
- immediately useful
- complements the starter ship role

Playstyle:

- balanced
- good for players learning path planning

### Challenger

Fantasy:

- high-speed evasive duelist

Skill:

- `Phase Dash`

Behavior:

- a short burst of phasing movement
- lets the ship slide rapidly laterally while briefly avoiding collision
- can be used to snap through impossible-looking gaps

Why it works:

- supports stylish, skilled play
- feels fast and expressive
- rewards precise timing

Playstyle:

- aggressive and technical
- for players who want mobility expression

### Dispatcher

Fantasy:

- heavy armored breaker

Skill:

- `Bulwark`

Behavior:

- becomes temporarily invincible
- can smash through hazards without taking damage
- may destroy weaker obstacles on impact

Why it works:

- perfectly matches the tank fantasy
- creates a powerful "panic button"
- distinguishes heavy ships from agile ships

Playstyle:

- forgiving
- good for survival-focused players

### Imperial

Fantasy:

- elegant control ship with premium utility

Skill:

- `Gravity Lift`

Behavior:

- jumps or elevates the ship into a higher flight lane for a short duration
- avoids low and mid-height hazards
- can chain into stylish route choices

Why it works:

- feels premium and graceful
- visually dramatic
- enables a very different form of escape than invincibility or destruction

Playstyle:

- strategic
- rewards route reading

### Insurgent

Fantasy:

- reckless overdrive predator

Skill:

- `Void Surge`

Behavior:

- large forward speed burst plus amplified graze value for a short window
- increases risk and reward at the same time
- best used by players willing to play dangerously

Why it works:

- strong endgame identity
- pushes mastery rather than safety
- turns skill into a scoring engine

Playstyle:

- high-risk, high-reward
- ideal for score chasers

## Skill Design Constraints

To keep the game healthy, ship skills should avoid:

- solving every problem the same way
- having too much overlap
- making steering feel unimportant
- being so long-lasting that they replace core play

Each skill should answer a different question:

- `Laser Cutter`: how do I open a path?
- `Phase Dash`: how do I escape sideways?
- `Bulwark`: how do I survive a bad moment?
- `Gravity Lift`: how do I bypass terrain vertically?
- `Void Surge`: how do I convert skill into explosive momentum?

## Suggested Gameplay Stat Mapping

To support ship identity, stats should eventually affect the simulation.

Recommended mapping:

- `life`: max hull durability
- `armor`: collision damage reduction
- `speed`: baseline forward speed growth and boost scaling
- `agility`: lateral movement response and recovery speed

This would turn the ship choice into a real gameplay decision instead of only a cosmetic/store choice.

## Future Upgrade Layer For Skills

Each special skill could later gain light upgrades without becoming too complex.

Examples:

- lower charge requirement
- longer duration
- wider effect
- extra score bonus while active
- one alternate modifier branch

Important note:

The base skill should come first. Upgrades should only be added after the base loop already feels strong.

## Best Immediate Next Steps

If the goal is to improve the game loop in a focused way, the strongest next design order is:

1. make ship stats affect real gameplay
2. implement one special skill per ship
3. add a shared charge system tied to skillful play
4. add mission structure around those systems
5. add ship mastery progression

## Open Questions

These should be resolved before final implementation:

- should skills be button-activated or auto-triggered when charged?
- should all ships charge at the same rate?
- should skills recharge from grazing only, or from survival plus grazing?
- should skills be available immediately, or only after the player unlocks the ship?
- should some skills be stronger in certain level/event types?

## Working Recommendation

The strongest current direction is:

- active skill button
- shared charge meter
- charge primarily from grazing, with a small passive gain from survival time
- every ship unlocked with its core skill already active
- no upgrade branches yet

That approach keeps the system readable while still giving each ship a distinct identity.
