# FavoriteLauncher

Single-file AutoHotkey v2 tray app (`FavoriteLauncher.ahk`) for quickly opening favorite folders, documents, programs and web addresses.

## Running

- Requires AutoHotkey v2.0 (`#Requires AutoHotkey v2.0`). Run the `.ahk` file directly; `#SingleInstance Force` replaces a running instance.
- Build with `build.ahk` (see Building). `FavoriteLauncher.exe` is a build output (gitignored). It sits next to the script and shares `FavoriteLauncher.ini`. Run either the `.ahk` or the `.exe`, not both: both use `Ctrl+Alt+Space`.
- Use AutoHotkey v2 syntax only — never v1.
- The app only starts when `FavoriteLauncher.ahk` is the script being run (`A_LineFile = A_ScriptFullPath`). When another script `#Include`s it (the tests), only the functions and globals load. Keep all startup code inside `StartLauncher()`. Use `AppDir` (not `A_ScriptDir`) for files next to the script.

## Tests

- Suite: `tests\FavoriteLauncher.Tests.ahk`. It includes the main script, uses a temporary ini (never the user's), and briefly shows GUI windows.
- Run from the repository root:
  `"C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut tests\FavoriteLauncher.Tests.ahk`
  It prints `PASS`/`FAIL` per test and exits with the number of failures (0 = all passed).
- Add a test function and list it in the `RunAllTests([...])` call. Assertions: `AssertEqual`, `AssertTrue`, `AssertFalse`.
- Dialogs (MsgBox, FileSelect, DirSelect) are tested with `WatchForDialog()`. It records the dialog's owner window and closes the dialog from a timer thread.
- Test what the user sees, not just that something exists. For example, AHK puts its own default icon on every window, so check that the icon *is ours*.
- Running a script with `#SingleInstance Force` replaces the user's running launcher. After any live test of `FavoriteLauncher.ahk`, start it again.

## Building

- `"C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" /ErrorStdOut build.ahk` from the repository root. Or double-click `build.ahk` to see the result in a message box.
- Steps: run the full test suite → stop if any test fails → close a running `FavoriteLauncher.exe` → compile with Ahk2Exe (`C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe`, base = the v2 interpreter) → check that the exe's file version is `AppVersion.0` and its icon is `FavoriteLauncher.ico` → restart the exe if it was running. Exit code 0 = success.
- Exe metadata comes from the `;@Ahk2Exe-...` directives at the top of `FavoriteLauncher.ahk`.

## Versioning

- Semantic Versioning `MAJOR.MINOR.PATCH`: MAJOR = incompatible change (e.g. ini format), MINOR = new feature, PATCH = bug fix only.
- The version is in three places that must match (a test checks this): `global AppVersion` and `;@Ahk2Exe-SetVersion` in `FavoriteLauncher.ahk`, and a `## [x.y.z] - YYYY-MM-DD` section in `CHANGELOG.md`.
- The version is shown in the About window and the tray tooltip.
- Each release is tagged `vX.Y.Z` in git.

## Behavior

- `Ctrl+Alt+Space` opens the launcher (reserved; cannot be assigned to a favorite).
- In the launcher (`#HotIf IsLauncherActive()`): type to filter, Up/Down to move, Enter to open, F2 edit, Delete remove, Esc hide.
- Each favorite can have an optional direct global hotkey, registered via `Hotkey()` in `RegisterAllHotkeys()`.
- Opening a folder while a standard file dialog (`#32770`) is active navigates that dialog instead of opening Explorer (`NavigateFileDialog`).
- Tray menu: Open / About / Exit.

## Data

- Favorites persist in `FavoriteLauncher.ini` next to the script (gitignored — user-specific).
  - `[Settings]`: `Count`, `OnboardingShown`
  - `[FavoriteN]`: `Name`, `Target`, `Type`, `Hotkey`
- Favorite types: `folder`, `document`, `program`, `link`. Unknown types load as `folder`.
- If the ini is missing, defaults (Desktop, Downloads, Pictures) are created and the onboarding message is shown once.
- `Favorites` is kept sorted by name; `VisibleFavorites` holds the filtered/ranked view with `OriginalIndex` back into `Favorites`.

## Code conventions

- Globals declared at top; functions use `global` declarations explicitly.
- Search ranking in `GetMatchRank` (lower = better; 100 = no match). Sorting uses hand-written insertion sorts.
- Icons come from `SHGetFileInfoW` with a cache keyed by type/extension (`IconCache`); call `ClearIconCache()` after edits.
- When changing favorites: `UnregisterAllHotkeys()` → mutate → `SaveFavorites()` → `RegisterAllHotkeys()` → `ClearIconCache()` → `RefreshList()`.
- UI font: Segoe UI s10; secondary text color `c666666`.
- Every new `Gui` calls `SetWindowIcon(gui)`. Windows opened from the launcher use `+Owner` + `MainGui.Hwnd` so they stay in front.
- Dialogs must open in front of the always-on-top windows. Call `someGui.Opt("+OwnDialogs")` in the handler before any `MsgBox`/`FileSelect`/`DirSelect`. A `MsgBox` shown while no app window is visible gets the `0x40000` (always-on-top) option.
- The list height is set by `FitListToFavorites()` from the total number of favorites (min 3 rows, window at most 80% of the screen height). It is called from `RefreshList()`.

## Working agreements

- **New features: mockups first.** Before implementing any new feature, present 3 different ASCII mockups of the UI/flow and let the user pick one. Do not write implementation code until a mockup has been chosen.
- **Tests first.** For every feature or bug fix, write or extend a test *before* the implementation, run the suite, and confirm the new test fails for the right reason. Then implement it and run the full suite again until everything passes. After every feature or fix, run `build.ahk`. It runs the full suite (never only the new test) and produces a fresh `FavoriteLauncher.exe`.
- **One GitHub issue per change.** Open an issue for each feature, change or bug fix (labels `enhancement` or `bug`). When it ships, list it under the version in `CHANGELOG.md` with its issue number, bump the version, commit with `Fixes #N`, tag `vX.Y.Z`, and close the issue with a comment such as "Fixed in v1.2.0".
- **Follow best practice** for AutoHotkey v2 and Windows UI conventions (standard keyboard shortcuts, native controls, consistent spacing and fonts, clear error messages).
- **Apply Steve Krug's "Don't Make Me Think" principles:**
  - Make things self-evident: labels, buttons and actions should be obvious without explanation.
  - Use plain, familiar wording; no jargon or clever names.
  - Reduce choices and noise; omit needless words and controls.
  - Make clickable/actionable things look clickable; make the default action obvious.
  - Follow conventions users already know instead of inventing new patterns.
  - Design for scanning, not reading: clear visual hierarchy, short text.
  - Prevent errors where possible; when they happen, explain plainly what went wrong and how to fix it.
