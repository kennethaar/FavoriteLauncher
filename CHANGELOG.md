# Changelog

All notable changes to FavoriteLauncher. Versions follow [Semantic Versioning](https://semver.org/):
MAJOR for incompatible changes (for example to the ini format), MINOR for new features, PATCH for bug fixes.

## [1.4.1] - 2026-11-12

### Fixed
- The tray menu has a **Restart** item again. (#15)

## [1.4.0] - 2026-11-11

### Added
- Tray menu item **What's new** opens the changelog. (#14)
- **Start with Windows**: a checkbox in the first-run welcome window (on by default) and a checkmark item in the tray menu. (#13)
- **Update banner**: when GitHub has a newer release, a banner above the search box says so. **What's new** opens the release notes; ✕ hides it until the next version. The check runs each time the app starts. (#12)

### Changed
- A single click on the tray icon opens the launcher. The first tray item is now called **Open launcher**. (#14)

## [1.3.0] - 2026-11-11

### Added
- New favorite type **Command**: a command line such as `ipconfig /all`. You choose whether the window stays open to show the output or the command runs hidden. (#10)
- Icons and short examples on the Add choices. (#10)

### Changed
- All windows use the standard Windows font size (9pt) with smaller fields, buttons and spacing. (#10)

## [1.2.0] - 2026-11-11

### Added
- `build.ahk`: runs the tests and, if they all pass, compiles `FavoriteLauncher.exe` and checks its version and icon. (#8)
- The exe shows as "FavoriteLauncher" in Task Manager. (#8)
- **Test** button for the direct shortcut. It checks whether another favorite, Windows or another program already uses the shortcut. It warns about Alt+letter (opens menus), single keys, common shortcuts such as Ctrl+S, and Ctrl+Alt keys that type a character on your keyboard (AltGr). Risky shortcuts can still be used after you confirm. (#9)

### Changed
- Adding a favorite takes two steps: first choose a folder, document, program or web address, then set the name and shortcut. The name is filled in from the location. The Edit window uses the same order: location, name, shortcut. (#9)
- Direct shortcuts are paused while the Add/Edit window is open, so pressing an existing shortcut in the shortcut box records it instead of opening a favorite. (#9)

## [1.1.0] - 2026-11-11

### Added
- Launcher window grows with the number of favorites, up to 80% of the screen height. (#5)
- Version number, shown in the About window and the tray tooltip. (#7)
- Automated test suite (`tests\FavoriteLauncher.Tests.ahk`). (#7)

### Changed
- Launcher window title is now "FavoriteLauncher". (#6)

### Fixed
- Message boxes and file/folder pickers opened behind the launcher, making it hard to add or edit favorites. (#1)
- Closing the Add/Edit window could move focus to another app instead of the launcher. (#2)
- List icons were shown at twice the normal size. (#3)
- `FavoriteLauncher.ico` was not shown on the launcher, Add/Edit and About windows. (#4)

## [1.0.0] - 2026-11-11

### Added
- First version: launcher with search, favorites for folders, documents, programs and web addresses,
  optional direct shortcuts, and file dialog navigation.
