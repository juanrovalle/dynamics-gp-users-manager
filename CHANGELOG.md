# Changelog

All notable changes to Dynamics GP UserOps are documented in this file. Release packages and checksums are published on the repository's [Releases page](https://github.com/juanrovalle/dynamics-gp-users-manager/releases).

## Unreleased

### Changed

- Refreshed the GitHub repository presentation with a 30-second product tour, product screenshots, a three-step quick start, use cases, release links, and clearer product positioning.
- Updated GitHub Actions to Node.js 24-based action versions.
- Made the nested-call rejection contract explicit in the session-removal integration test.


### Added

- Self-contained Dynamics GP UserOps WPF application for Windows 11 and supported Windows Server Desktop Experience releases.
- Six-step Connect, Verify, Install, Configure, Test, and Activate deployment workflow.
- Overview, Departments, Users, Activity, and Settings administration areas.
- Department quotas, GP-user assignments, audit history, native GP message queuing, diagnostics, and scoped SQL roles.
- English application interface and complete English/Spanish offline deployment guides.
- Automated logical, platform-policy, legacy-upgrade, SQL integration, and DPI screenshot tests.

### Changed

- Renamed GP Users Manager to Dynamics GP UserOps, including projects, namespaces, assemblies, executable, Windows metadata, installer identity, and local profile directory.
- Added an enterprise navy/blue visual system and an original UO monogram.
- Changed the default database name for new installations to `DynamicsGPUserOps`.
- Preserved the existing `gpManager*` tables, roles, views, and `SP_GPUM_*` procedures as the compatible SQL contract.

### Upgrade notes

- Upgrades from GP Users Manager 3.x preserve the existing SQL database, policies, data, and selected Agent job.
- The password-free 3.x local profile is copied on first launch; the original profile is retained.
- New installations remain paused until a real GP message test is confirmed and an administrator explicitly activates automation.

See [the detailed 4.0.0 release notes](docs/release-notes.md) for the full operational and compatibility notes.

## [3.0.1]

- Added supported Windows Server Desktop Experience targets, platform-policy tests, and complete offline English/Spanish server guides.

## [3.0.0]

- Added the first WPF administration console, versioned SQL migrations, scoped roles, job control, diagnostics, audit history, native GP notification integration, and self-contained Windows packaging.
