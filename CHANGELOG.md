# Changelog

All notable changes to FavoriteLauncher. Versions follow [Semantic Versioning](https://semver.org/):
MAJOR for incompatible changes (for example to the ini format), MINOR for new features, PATCH for bug fixes.

## [Unreleased]

### Added
- `build.ahk`: runs the tests and, if they all pass, compiles `FavoriteLauncher.exe` and checks its version and icon. (#8)
- The exe shows as "FavoriteLauncher" in Task Manager. (#8)

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
