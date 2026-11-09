# Match Game Logic

The match simulation has been extracted from `Season.simulate` into a dedicated,
parametrizable engine in `Sources/ElevenHeroes/MatchEngine.swift`. This keeps the
domain model focused on state while making the rules reusable by future AI agents.

## Components

- `MatchSimulationParameters` — all tunable constants (home advantage, base goals,
  power/form weights, max goals, tactic profiles). Conforms to `Codable`, so an AI
  can persist and compare experiments.
- `TacticProfile` — per-tactic attack/defense modifiers.
- `MatchSimulationContext` — inputs for one fixture: clubs, selected club, lineup,
  tactic, round, prior fixtures, year.
- `MatchSimulator` — stateless engine that computes expected goals and samples
  a final score through a seeded RNG.

## Algorithm

1. **Team power**
   - Selected club uses the average rating of its chosen lineup.
   - Other clubs use `Club.strength` (average of the best 11).

2. **Form**
   - Last 5 matches for each club are scored as win = +1, draw = 0, loss = -1.
   - The average is scaled by `formWeight`.

3. **Expected goals**
   - Home: `baseHomeGoals + homeAdvantage + (homePower - awayPower) * powerWeight
     + homeForm * formWeight + tacticBoost`
   - Away: `baseAwayGoals - homeAdvantage - (homePower - awayPower) * powerWeight
     + awayForm * formWeight + tacticBoost`
   - Values are clamped to `[0.2, 4.5]`.

4. **Score sampling**
   - Goals are sampled with a Poisson process using the seeded RNG, capped by
     `maxGoals`.

## Parametrization

`Season.matchParameters` (optional) overrides the defaults. If `nil`, the simulator
uses `MatchSimulationParameters.default`. AI agents can:

- Instantiate `MatchSimulator(parameters:)` with custom values.
- Call `expectedGoals(context:)` to inspect the model without sampling.
- Call `simulate(context:rng:)` to generate a reproducible result.
- Persist parameters and compare outcomes across experiments.

## Tactics and Training

Tactics are stored in the `tactic` table of `db.sqlite` (`tactic_name`,
`tactic_attack`, `tactic_defense`). The Training screen lets the user edit these
profiles and choose the active tactic for the season.

When a tactic is applied, its `attack` and `defense` values are written into
`MatchSimulationParameters.tactics` for the corresponding tactic name. During
simulation, the active tactic's `attack` boost is added to both teams' expected
goals (reflecting overall match tempo), while its `defense` modifier adjusts the
balance between scoring and conceding. Thus changing tactics in Training directly
alters the match engine parameters used for future fixtures.

## Determinism

All randomness flows through the caller's `RandomNumberGenerator`, so simulations
are reproducible given the same seed and inputs. This makes the engine suitable
for AI training, evaluation, and replay.