# HAL Behavior Verification Tests

Smoke tests for **BEHAV-01 through BEHAV-05** (Phase 5 plan 05-08, decision D-04).

These scripts verify that the refactored HAL machinery produces the expected
runtime state inside Arma 3. They are **observational** — they check that
variables are set, loops have run, and functions are compiled. They do **not**
assert specific tactical decisions, because HAL's AI is stochastic.

The `tests/` directory lives at the repository root and is **not** packed into
any PBO. It is excluded from the HEMTT build (HEMTT only compiles `addons/*`).

---

## Prerequisites

1. NR6-HAL mod loaded in Arma 3 (with CBA_A3 dependency).
2. A test mission with at least:
   - One **HAL Core** module placed and synced to a group leader.
   - One **HAL Include** module with synced subordinate AI groups.
   - For BEHAV-03: hostile units within ~1000 m of the friendly groups.
   - For BEHAV-04: at least one artillery-capable group (mortar / howitzer)
     synced via the Include module, plus enemies in range.

## Running the tests

1. Launch the mission via the editor (singleplayer or multiplayer preview).
2. Wait until mission start (HAL needs `hal_core_postInit` to fire).
3. Open the debug console (`Esc` -> Debug Console).
4. Paste **one** of the following lines and press *Local Exec*:

   ```sqf
   0 = [] execVM "tests\test_BEHAV_01_init.sqf";
   0 = [] execVM "tests\test_BEHAV_02_groups.sqf";
   0 = [] execVM "tests\test_BEHAV_03_scan.sqf";
   0 = [] execVM "tests\test_BEHAV_04_arty.sqf";
   0 = [] execVM "tests\test_BEHAV_05_chatter.sqf";
   0 = [] execVM "tests\test_BEHAV_06_regression.sqf";
   ```

5. Watch the on-screen `systemChat` log. Each test prints:
   - A `=== <test name> ===` banner.
   - One `[PASS]` or `[FAIL]` line per assertion.
   - A final summary `=== <test name>: X/Y passed, Z failed ===`.

> The mission must have access to the `tests/` directory. The simplest way is
> to copy the `tests/` folder into the mission folder so the relative path
> `tests\test_BEHAV_*.sqf` resolves. Alternatively, paste the script body
> directly into the debug console.

## What each test verifies

| Test     | Wait | Verifies                                                       |
|----------|------|----------------------------------------------------------------|
| BEHAV-01 | 20 s | `hal_core_allHQ` populated; codeSign + 6 personality traits + `personality` string set on HQ; `hal_core_allLeaders` non-empty |
| BEHAV-02 | 30 s | HQ `friends` list non-empty; subordinate groups have waypoints; `lastFriends` snapshot exists; side match |
| BEHAV-03 | 60 s | `hal_core_fnc_EnemyScan` compiled; `eS` flag set on HQ; at least one enemy group tagged with `markerES`; `cyclecount` advanced |
| BEHAV-04 | 90 s | `hal_common_fnc_artyMission` compiled; artillery-capable group present in friends; `batteryBusy` variable touched; HQ `fineness` initialised |
| BEHAV-05 | 30 s | `hal_common_fnc_AIChatter` compiled; `aIChatDensity` setting in valid range; `hQChat` boolean set; at least one HQ for binding |

## Limitations

- **Tests verify machinery, not outcomes.** They check that the refactored
  call sites populate the same observable variables as the legacy `nr6_hal/`
  loader. They cannot assert that the AI made the *same* tactical choice as
  before — that is inherently non-deterministic.
- **Timing-dependent.** Wait values are conservative for an idle dedicated
  server. On a stressed machine you may need to extend the `sleep` calls in
  the script (search for `Waiting Ns`).
- **BEHAV-04 is the loosest test.** Whether a fire mission actually runs
  depends on enemy presence, ROE, ammo state and `fineness` rolls. The test
  passes if the artillery wiring is in place and the battery exists.
- **BEHAV-05 cannot capture sideChat directly.** It validates the chatter
  function is compiled and the gating settings are populated; visual
  confirmation in the chat HUD is the manual verification step.

## Acceptance criteria

A test PASSES the BEHAV requirement if all assertions print `[PASS]`. A FAIL
indicates that the refactored machinery is missing a variable or function
that the legacy `nr6_hal/` build provided. Investigate by:

1. Checking the failing variable name in `addons/core/functions/` or
   `addons/common/functions/`.
2. Confirming the relevant `XEH_postInit.sqf` ran (`diag_log` entries).
3. Comparing against the pre-refactor baseline behaviour documented in
   `.planning/phases/05-settings-localization-compat-cleanup/05-RESEARCH.md`
   Block 6 (Observable States).

## Files

- `test_BEHAV_01_init.sqf` — HQ initialisation.
- `test_BEHAV_02_groups.sqf` — Group management & friends list.
- `test_BEHAV_03_scan.sqf` — Enemy scan loop.
- `test_BEHAV_04_arty.sqf` — Artillery / CFF wiring.
- `test_BEHAV_05_chatter.sqf` — AI chatter machinery.
- `test_BEHAV_06_regression.sqf` — **Regression wall** (2026-04-14 debug baseline).
- `lint-hal.sh` — Static analysis for Phase 4/5 migration defect families.

---

## Static Lint (lint-hal.sh)

Catches the defect families we spent 18 debugging rounds fixing on 2026-04-14.
Runs without Arma — pure bash + grep — so it can gate commits locally or in CI.

```bash
# From repo root
bash tests/lint-hal.sh
```

**Checks (5 families, see `.planning/debug/runtime-init-errors.md`):**

| # | Family | Catches |
|---|--------|---------|
| F1 | Literal `\\` in `#include` paths | Round 3 (74-file tasking bug) |
| F2 | Bare `call hal_X_name` refs not in `XEH_PREP.hpp` | Rounds 7, 10, 14, 15 |
| F3 | Cross-addon `GVAR(x)` read where writer is a different addon | Rounds 12, 13, 15, 16, 18 |
| F4 | Stale `RydHQ_*`/`RydBB*`/`Rydx*` reads outside `compat_nr6hal` | Rounds 2, 6, 7, 10, 11 (warning only — many are setVariable keys) |
| F5 | Undefended `GVAR(x) pushBack/forEach/count/+` operations | Rounds 1, 2, 6, 11, 17 (warning only — spot-check) |

**Exit codes:**
- `0` = clean, no HIGH severity defects
- `1` = one or more HIGH families failed (F1, F2 with >5 hits, F3 with >5 hits)
- `2` = tool error (not run from repo root)

**What it catches vs. what it misses:**

F1, F2, F3 are deterministic — a failure means a real bug. F4 and F5 are
best-effort spot-check warnings with false positives (F4 catches setVariable
string keys which are internal storage, not compat debt). Runtime-only bugs
— null-group `getVariable`, HashMap Group key, boolean-vs-string type
collisions — cannot be caught statically. Use BEHAV-06 for those.

## Regression Wall (BEHAV-06)

`test_BEHAV_06_regression.sqf` verifies every critical variable and function
seeded across Rounds 1–18. Any failure means a Phase 4/5 migration bug has
regressed.

It asserts:

- **Round 1-2:** `hal_common_handles`, `hal_missionmodules_active`, `hal_common_debug[B-H]`
- **Round 4:** `hal_core_allHQ` populated (leader discovery worked)
- **Round 5-6:** `hal_core_callSignsN` + 7 `hal_data_*` class arrays populated
- **Round 7:** 8 `aIC_*` AI-chatter arrays seeded in boss/hac/common
- **Round 12:** `hal_missionmodules_included` → HQ `hal_core_included` bridge
- **Round 14:** 15 hac/common functions compiled as `hal_*_fnc_*` (not bare globals)
- **Round 15-16:** `gPauseActive`, `mARatio`, `mortar_A3`, `allArty` seeds
- **Round 18:** 30 bridged module-setting variables on the HQ object

**How to run** (same flow as other BEHAV tests):

```sqf
0 = [] execVM "tests\test_BEHAV_06_regression.sqf";
```

Watch `systemChat` — all checks should print `[PASS]`. Any `[FAIL]` is a
regression. The test waits 60 seconds for HAL's init cycle to complete before
asserting, so give it a full minute.

**What a failure tells you:**
- Failure in the `Round N` section → look at the Round N commit(s) in git log
  and/or the `.planning/debug/runtime-init-errors.md` writeup for that round
- The failure messages are named after the variable, so you can grep source
  for the name and find the writer that should be populating it
