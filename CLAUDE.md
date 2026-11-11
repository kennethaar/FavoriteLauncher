# FavoriteLauncher

Single-file AutoHotkey v2 tray app (`FavoriteLauncher.ahk`) for quickly opening favorite folders, documents, programs and web addresses.

## Running

- Requires AutoHotkey v2.0 (`#Requires AutoHotkey v2.0`). Run the `.ahk` file directly; `#SingleInstance Force` replaces a running instance.
- No build step, no tests. Verify changes by running the script and exercising the GUI.
- Use AutoHotkey v2 syntax only — never v1.

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
