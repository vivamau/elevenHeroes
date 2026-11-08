# Eleven Heroes

Native SwiftUI football management simulation for macOS 14 or later. The build script produces one universal application containing Apple Silicon (arm64) and Intel (x86_64) executables.

## Run

Open `dist/Eleven Heroes.app`. New career setup asks whether to generate fictional data or use database clubs. Choose **Generate fictional data** for a fresh league with 8 clubs and 160 players, preview the clubs, then select one and play a matchweek. Back and Cancel leave the saved career intact. Use Squad to select exactly eleven starters; the Overview tactical board provides defensive, balanced and attacking approaches. Match Centre includes results and a generated goal report. League standings update after every round.

## Develop

Open `Package.swift` in Xcode, or run:

```sh
swift run
swift test
./scripts/build-app.sh
```

The app is locally ad-hoc signed. Public distribution requires your Apple Developer signing identity and notarization. The Intel executable is cross-compiled; runtime testing on an Intel Mac remains necessary.

## Database

`db/db.sqlite` is opened read-only and bundled unchanged. The supplied file contains the country catalog and lookup records but no clubs, so setup asks before generating a labelled fictional league with 8 clubs and 160 players. Club names use fictional templates; player assignments and ratings are randomized for each generation. No fictional data is inserted into your database.

Use **Manage database…** in the sidebar (⇧⌘D) to search, create and edit countries, cities, championships, teams, stadiums and players. The manager opens inside the main app window with the same dark-and-lime theme, branded sidebar, rounded headings and panel styling as the main game. **Back to main page** (⌘[) returns to Overview and refreshes database data without changing your saved career. Record editors and generation dialogs stay attached to that window. The browser, record editors and generation dialogs share the colors and branding defined in `AppTheme.swift`. Add/Edit opens a compact grouped editor with aligned labels, bordered inputs, and a separate action footer. The first text field receives keyboard focus and Tab moves between fields. Create/Save validates the form; cancelling a changed draft asks whether to discard it. Create countries and cities first, then choose them in the other forms. Assign players to teams and teams to championships using the optional relationship pickers. Names, country codes, numeric ranges, dates and foreign keys are validated. The player editor has Details, Physical and Mental tabs. All 7 physical skills and 12 mental skills are editable on a 1–20 scale, alongside condition (0–100%), preferred foot and morale. New manual profiles start at 10 with 100% condition. Preferred-foot and morale options come exclusively from `player_foot` and `player_morale`; their labels and IDs are preserved. Random generation samples only existing lookup rows. Neither editor nor generator inserts lookup values, and empty lookup tables block player creation with an error. Randomize skills updates the draft only; Save writes both skill tables atomically with the player. Older profiles with missing skill rows show defaults and receive those rows when saved. Existing saved attributes are preserved when changing profile details. Birth dates are stored as YYYYMMDD; founding dates are stored as years. Changing a squad or championship assignment replaces that record's previous membership links; unchanged assignments preserve existing links.

Each dataset has **Generate fake data…**. Choose 1–100 records; **Replace all data and generate** clears all world records before generating the selected dataset and required dependencies. This also removes manager records and all player skills, positions, statistics and memberships. Position, preferred-foot and morale lookup definitions are preserved. Saved careers remain unchanged. Clearing and generation share one transaction, so a failed batch restores the entire previous world. Missing countries, cities, championships and teams are created as needed and included in the completion summary. Team generation optionally adds 22 players per team (enabled by default). Player generation fills the smallest newly generated squads first and creates complete randomized physical and mental attributes, condition, preferred foot and morale. Country codes are unique synthetic three-letter codes, not official ISO assignments. Player names and club names come from the supplied CSV; generated places and competitions retain Sample or Fictional names. Each batch is transactional: a failure rolls back all new records and dependencies. To create a playable database quickly, generate at least two teams with squads enabled, then start a database career.

On first launch, the app creates a writable working copy at `~/Library/Application Support/ElevenHeroes/db.sqlite`. Edits persist across launches and are used by new careers; existing seasons retain their saved snapshot. The bundled source is never modified. Both Swift Package/Xcode builds and the universal app bundle include `db.sqlite`, so launching outside the project folder works. On upgrade, an existing `football.sqlite` working copy is copied to `db.sqlite` without removing the old file.

Use **Import database…** (⌘O) to copy another SQLite file with the supplied schema into the working database, including partially populated files. Imports retain the previous working copy as `football-backup-<UUID>.sqlite` in the same directory. To restore one, import that backup. Starting a database career requires at least two teams with eleven linked players each. Incomplete squads are listed in setup and excluded from the career without changing their database records. All eligible teams participate in a single home-and-away league; championship associations and contract dates are not yet used.

Players come from `player` and `team_players`, with city names from `city`. Overall ratings average pace, stamina and strength from `player_skills_physical`, assuming 1–20 attributes and multiplying by five (bounded to 1–99). Missing attributes default to 10. Mental attributes are stored and editable but do not yet affect the match engine. Positions come from `position` and `player_position`; legacy players without assignments retain provisional roles. GK, D, M and A positions map to the corresponding simulation roles. Tactical pitch placement is illustrative; manual selection permits any eleven players.

## Simulation and saves

A double round-robin calendar handles both even and odd team counts. Results use Poisson goal sampling, selected-XI strength, home advantage and tactical scoring variance. Goal scorers and minutes are generated for the match report. This is an initial management simulation, without injuries, player development or a real-time match engine.

The current career autosaves atomically to `~/Library/Application Support/ElevenHeroes/season.json`, including roster data, selection, tactics, fixtures and results. Starting a new career offers to save a separate JSON copy before replacing the autosave. Use **Load career…** in the sidebar or **File → Load Career…** (Shift-Command-O) to resume a saved JSON career. Loading automatically backs up the current career in `~/Library/Application Support/ElevenHeroes/Careers/`; the file picker opens that folder when available. Invalid files or save failures leave the current career intact. The selected file and the football database remain unchanged.

Tests cover schedules, season accounting, save round trips, opt-in generation, all six database record types, editing, persistence, playable roster loading, validation, transaction rollback and recoverable imports.

Click a team name in the database manager, league table, fixtures, or sidebar to view its squad inside the app. The team page shows city, player count, ratings and provisional positions, with Back navigation. Database team pages also show founding year and championship. Career selection previews the squad before the explicit Start career action.

Player names in database lists, team pages and the career squad open an inline profile with Back navigation. Profiles show birth date and city, database lookup labels for foot and morale, and recorded physical and mental attributes. New database careers snapshot these profiles in the save. Older saves and fictional careers without detailed profiles show their stored name, position and rating with an explanation; they never borrow records from the working database by matching IDs.

Database lists offer Delete via the trash button or context menu, with a confirmation describing the consequences. Player deletion removes skills, statistics and memberships; team deletion removes memberships but keeps players; championship deletion keeps teams. Countries and cities still referenced by other records cannot be deleted. Deletion is transactional and never alters saved careers.

Database generation uses `db/player_profiles.csv`, prepared into bundled `player_profiles.json` by `scripts/prepare-player-profiles.py` (automatically run by the universal build script; run it before Swift Package builds when changing the CSV). It removes trailing numeric IDs from names and reads date_of_birth, foot, position, main_position and current_club_name. Invalid dates, deceased profiles and non-club statuses are excluded. Team batches select unused CSV club names with at least 22 usable profiles when squads are enabled. Separate player batches prefer that team's unused CSV profiles and fall back to other unused profiles. Names and birth dates already present in the database are not duplicated by generation. Skills, condition and morale remain simulated; unavailable feet use existing lookup options. Cities and championships remain placeholders rather than inferred real-world club geography.

CSV positions map to existing database codes: GK, DR, DL, DC, MC, MB, MA, ML, AR, AL and AC. Right midfield falls back to MC and second striker to AC; main_position supplies a broad fallback when the detailed position is unavailable. Each generated player receives a strong, non-acquired assignment dated today. Missing required position codes fail the batch atomically. Older working databases missing position tables receive the schema and lookup records from the bundled template. Existing position tables and assignments are preserved.

Database replacement is performed only when the user presses Replace all data and generate. Selecting a dataset or opening the dialog does not delete anything. Generating countries alone creates countries only; generating teams with squads creates teams, players and required places/competitions.

Squad screens and team pages use a wide player table with name, position, overall rating, birth date/city, foot, morale, all physical attributes and all mental attributes. Scroll horizontally for additional columns and vertically through the squad. Headings sort the table; search matches player names and positions. The career squad retains starting-XI checkboxes and Pick best XI. Player names open profiles. Missing saved details display an em dash.

The application synchronizes the 249-country catalog from countries.csv into its working database at startup, when opening database management, and after import. The universal build regenerates the bundled catalog and template via scripts/import-countries.py. Recognized ISO2 codes are normalized to ISO3; existing country IDs and custom countries are retained. Duplicate catalog matches consolidate city and championship references atomically. A database reset can remove countries, but opening database management again restores the catalog.

Championship names in database management open an inline championship page showing country, assigned/configured team counts and the assigned teams. Team names lead to team squads and player profiles. Back returns through each level without leaving the main app window.

Country names in database management open their assigned leagues. The navigation path stays within the app: Countries → country → league → team → player. Back returns one level at a time and preserves the country-list search. Countries without leagues show guidance for assigning one.

**Clear database…** in the manager sidebar removes all world records after confirmation, preserving position, player_foot and player_morale lookup tables and saved careers. The clear is transactional. An internal metadata flag prevents country catalog synchronization from silently repopulating an explicitly cleared database on restart; importing a fresh database without that flag restores normal catalog synchronization.

Empty-world generation uses all three CSV catalogs: countries.csv for country names/codes, team_details.csv for team names/countries/latest available competitions, and player_profiles.csv for squads matched by source club ID. Country generation no longer invents countries. Team records without a matched catalog country or enough player profiles are excluded. UK home nations map to the United Kingdom country entry; selected country-name aliases are normalized during preparation. Club cities and foundation years remain generated because the team file does not supply them, and a missing competition receives a labelled placeholder league. Clearing the database still leaves it empty until generation is requested.

## Transfer market

Open **Market** to search by player name, club or database position (MB, ML, etc.), inspect a player, and make an offer. Each new career starts with **10,000 credits**. Affordable offers must meet the listed value. If removing the player lowers the selling club’s best-eleven overall by more than 2 points, the club requires a random 5–20% premium above that value, rounded up to whole credits. A new premium is sampled for each submitted offer; a 20% premium meets any possible demand. A decline of exactly 2 points does not trigger this rule. Accepted transfers deduct the full offered amount; refused offers leave the squads, credits and autosave unchanged. The player moves into your squad, where you can select them for the starting XI. Transfers and balances autosave together; a failed save leaves both unchanged.

Player values use `player_value.player_value_cost`, with `player_value_date` recorded as YYYYMMDD. New database players and existing players missing a value receive a random **1–100 credit** value. Existing costs are preserved; the latest dated value is used. Fictional leagues generate values in the same range. Database migration supports older copies missing the table or cost column. Deleting or clearing players removes their values too.

### Starting values and weekly salaries

New careers replace seed valuations with a common market scale based on the manager’s stadium and chosen starting ticket price:

```text
Potential stadium income = stadium capacity × ticket price
Starting player value = max(100, round((potential stadium income ÷ 22) × (overall ÷ 70)))
```

A 70-overall player is worth approximately one twenty-second of a full stadium’s ticket income. Higher and lower ratings scale proportionally. Missing stadium capacity defaults to 20,000 seats. The same reference applies to all players, including players outside the league, and is saved for future youth replacements. Career market values have no 100-credit cap; the database’s 1–100 values are seed data only.

Initial weekly salaries are sampled uniformly in whole credits from **10% to 20% of market value** (lower bound rounded up, upper bound rounded down), with a **10-credit minimum**. For example, 30,000 seats at 10 credits produces a value of **13,636 credits** for a 70-overall player and a weekly salary of **1,364–2,727 credits**. Transfer offers let the manager negotiate the salary; these salaries remain user-controlled, subject to the 10-credit minimum.

After each home or away match, the full squad’s weekly wages—including substitutes and reserves—are deducted from the budget. Home ticket income is attendance × ticket price. Wages can take the budget below zero, and completed matches cannot charge twice. Bye rounds do not deduct wages.

These starting valuations apply only to new careers. Existing careers keep their saved market values; effective salaries below 10 credits use the minimum. Changing ticket prices in later seasons does not automatically revalue players. Starting funds remain **10,000 credits**.

New database careers snapshot all database players for market search, including players outside the playable league. Players without a club appear in search but cannot be purchased yet. Existing careers use their saved squads and start with 10,000 credits if no balance was previously recorded; older players without saved values use their overall rating (bounded to 1–100). Transfers affect only the current career, leaving the source database and other careers intact.

The market’s **Your team** tab lets you list players and invite bids. **Offers** shows incoming bids from other clubs in your league, with the buyer, price and value comparison. Clubs send up to three new bids after each completed matchweek, prioritising listed players. Starting a career, listing players and opening the market do not generate bids. Offers persist with the career and do not reroll when reopening the market. Review an offer to see the resulting budget and squad size, then accept or reject it. Accepting transfers the player to the bidding club for the exact offered amount. Sales cannot reduce your squad below **16 players** (11 starters plus 5 substitutes). Selling a starter selects a replacement, preferring the same role. The squad, lineup, offers and credits save together; a failed save cancels the change.

## Stadium improvements

Open **Stadium** in the sidebar to expand your club's ground. Enter the number of new seats to add; the cost is your current ticket price × the number of new seats × 100 credits. The expanded capacity takes effect for future home matches and increases home ticket income. Wages and balances follow the existing career economy rules.

## Player stats and value history

Player pages include a **Stats → Player value** chart and a selectable history of dates, teams and credit values. Database histories read `player_value_date`, `player_value_cost` and `player_value_team_id`, ordered by date and then record ID. Multiple records on the same date remain visible in recording order. A single valuation shows one point; no past values are invented. Unknown historical teams are labeled “Team not recorded.”

Generated values now reference the assigned team. Database reassignments append a valuation for the new team without overwriting earlier records. New careers begin a fresh history with their recalculated starting values and salaries; career transfers append the current valuation for the destination club, with the matchweek; the amount offered is a transfer fee and does not change the recorded valuation. Career histories persist in the save and never modify the source database. Fictional careers begin recording at career creation. Older saves still load and show their current value; their history begins with future transfers rather than borrowing potentially unrelated live database records.

Player detail pages use a compact overview with personal information and a value chart side by side, plus physical and mental attributes in two-column panels. The **History…** action opens the full dated value log. Narrow layouts stack the panels while retaining readable text.

## Continuing a career

Careers start in the current calendar year. After the final matchweek, **Start season [year]** begins the following year with fresh fixtures and standings. Squads, transfers, credits, lineup, tactics and transfer listings carry over; pending bids expire and weekly offers resume after playing a matchweek. Completed seasons retain their results and champion in the save, with champions shown in Overview. The transition saves atomically.

Player ages appear in squad lists and player details and increase by one each season, including players outside the playable league. Initial ages use birth dates as of 1 July in the starting year; players without a birth date start at 24. Birth dates and the source database remain unchanged. Older careers without a year begin at 2026. Players retire at 41; age-based rating changes and development rules are not yet modelled.

Click a season under **Previous seasons** to open its final league table, top scorers and top assists. New matches record goal scorers and optional assists for every league fixture (a scorer cannot assist their own goal). Rankings combine a player’s contributions across clubs; archived club names and results stay fixed. Older seasons retain their league tables but show an incomplete-records notice for missing player statistics.

The season recap shows every match below the league table, grouped by matchweek, with scores, scorers and assists. New matches also save goal minutes; older goal records show an unknown minute, and fixtures without player events show a missing-records message.

## Retirement

Players aged 41 or older retire before participating in a season, including when starting or loading a career. At the annual rollover, ageing happens before retirement. Retired players leave squads, lineups, listings and bids, but historical goals, assists and player records remain saved. You choose and buy one replacement per retirement in Market before playing another matchweek; purchases use your existing credits. Other league clubs automatically buy same-role replacements from outside the playable league, preserving other league squads and recording the transfer fee. Younger players from Development FC enter the market when needed to keep long careers supplied.

Every playable team requires at least two goalkeepers. Sales and purchases cannot leave a selling club below that minimum. After retirement or when loading an older career, computer teams buy missing goalkeeper cover; the manager must purchase any missing keepers before playing. Development FC supplies goalkeeper options when needed.

Generating teams also creates one stadium per club in its generated home city, with 5,000–30,000 initial seats. Standalone stadium generation uses the same capacity range. Stadium improvement history starts empty; future expansion rows belong in `stadium_improvement`. Clearing or replacing the database removes improvement rows before stadiums, and failed generation rolls back both.

City generation is additive: it preserves countries and all existing records, fills every country without a city, and distributes further requested cities across countries. The requested number is a minimum, so full country coverage may exceed it. An empty country table is populated from the country catalog first.

Generated clubs are linked to their stadiums through `stadium_team (team_id, stadium_id)`. Older working databases receive this table automatically. Stadium/team deletion and database replacement remove these associations in foreign-key order.

New matches save attendance at 55–100% of the home stadium capacity, capped at capacity. Database careers use `stadium_team` and base seats plus recorded improvements; fictional teams or missing stadium data use a 20,000-seat fallback. Match Centre and season recaps show attendance and venue. Previously played matches without attendance remain labelled as unrecorded.
