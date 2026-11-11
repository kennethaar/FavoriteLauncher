# Changelog

All notable changes to FavoriteLauncher. Versions follow [Semantic Versioning](https://semver.org/):
MAJOR for incompatible changes (for example to the ini format), MINOR for new features, PATCH for bug fixes.

## [1.1.0] - 2026-11-11

### Added
- Launcher window grows with the number of favorites, up to 80% of the screen height.
- Version number, shown in the About window and the tray tooltip.
- Automated test suite (`tests\FavoriteLauncher.Tests.ahk`).

### Changed
- Launcher window title is now "FavoriteLauncher".

### Fixed
- Message boxes and file/folder pickers opened behind the launcher, making it hard to add or edit favorites.
- Closing the Add/Edit window could move focus to another app instead of the launcher.
- List icons were shown at twice the normal size.
- `FavoriteLauncher.ico` was not shown on the launcher, Add/Edit and About windows.

## [1.0.0] - 2026-11-11

### Added
- First version: launcher with search, favorites for folders, documents, programs and web addresses,
  optional direct shortcuts, and file dialog navigation.
