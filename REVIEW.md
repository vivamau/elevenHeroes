# Project Review: Eleven Heroes

## Snapshot

- **Stack:** Swift 6 / SwiftUI macOS 14+ app, bundled SQLite via a `CSQLite` system library, Swift Testing.
- **Size:** ~6.3k LOC across 32 source files + 26 test suites.
- **State:** `swift test` passes (72/72) and `./scripts/build-app.sh` produces a universal (arm64 + x86_64) ad-hoc-signed app bundle.

## Architecture summary

`GameStore` (`App.swift`) is the central `@Observable` state object and owns the career lifecycle, save/load, database preparation, and screen routing. Domain logic is split across `Season` extensions (`Models`, `CareerSeasons`, `Market`, `CareerEconomy`, `TransferOffers`, `Retirement`). Persistence is a JSON autosave (`season.json`) plus a read/write SQLite working copy at `~/Library/Application Support/ElevenHeroes/db.sqlite`. The database layer (`DatabaseManager.swift`) wraps SQLite directly, with migrations, transactional edits/generation/clearing, and country-catalog sync.

## Strengths

- **Broad test coverage:** schedules, season accounting, save round trips, DB CRUD, validation, transaction rollback, imports, transfers, economy, retirement.
- **Transactional database operations:** create/edit/delete/generate/clear/import all use savepoints and roll back on failure.
- **Migration-friendly schema:** older working DBs receive position, player-value, stadium, and stadium-team tables/columns automatically.
- **Clear domain separation:** economy, transfers, offers, retirement, season rollover are isolated extension files.
- **Reusable theming:** `AppTheme` keeps the dark/lime visual language consistent across game and DB manager.

## Issue found and fixed

**Salary bounds were inverted in `CareerEconomy.initializeEconomy`.**

README/test contract: weekly salary is sampled uniformly from **10%–20%** of market value (lower bound rounded up, upper bound rounded down, 10-credit minimum).

```swift
// Before
let lower = max(Self.minimumSalary, (creditsValue + 9) / 3)   // ~33%
let upper = max(lower, creditsValue / 5)                      // 20%
// After
let lower = max(Self.minimumSalary, (creditsValue + 9) / 10)  // 10%
let upper = max(lower, creditsValue / 5)                      // 20%
```

This caused `CareerEconomyTests.startingPricesScaleWithStadiumAndOverall` to fail for every player (42 issues); all tests now pass.

## Remaining observations / latent risks

1. **Large files / mixed concerns:** `App.swift` (662 lines) and `DatabaseManager.swift`/`DatabaseManagerView.swift` (~650 each) combine UI, SQL, and business logic. Refactoring into smaller view models would improve maintainability.
2. **Retirement replacement economy:** `Retirement.retireIneligiblePlayers()` calls `initializeEconomy` on an already-valued market player, recomputing `marketValue`/`salary` but leaving prior `valueHistory` entries in place, then appends a new record. This may produce inconsistent value history for replacement players. Worth adding a test before changing.
3. **Negative IDs for development players:** `addYoungMarketPlayer` uses `min(0, …) - 1`, producing negative IDs. Works, but is fragile if IDs are ever assumed positive.
4. **Credit/revenue ordering in simulation:** `creditBalance` is updated twice (revenue then wages) relying on the computed `credits` property reflecting the first write. It works, but the two-step mutation is subtle; consolidating into one calculation would be safer.
5. **No notarization/signing pipeline:** build script ad-hoc signs only; public distribution still requires manual signing/notarization (documented, but worth automating if shipping).
6. **Generated `dist/` is checked into the working tree** despite `.gitignore` listing `dist/`; the folder is large and should probably be removed from version control.

## Recommendations

- Keep the economy fix; consider adding a focused test asserting salary bounds for a few rating tiers.
- Add a test around retirement replacement value history before refactoring it.
- Split `App.swift` into `OverviewView`, `SquadView`, `LeagueView`, `MatchesView` to reduce review burden.
- Remove `dist/` and `.build/` from source control; keep them as build outputs only.
- Optionally expose a `--configuration release` build target and signing identity in `build-app.sh`.

## Verification

- `swift test` → **72/72 passed**
- `swift build` → **success**
- `./scripts/build-app.sh` → **universal bundle built successfully**
