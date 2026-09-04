# Release notes — 4.0.0

## Dynamics GP UserOps identity

- Renamed the product, projects, namespaces, assemblies, executable, installation folder, Start menu group, diagnostics, and Windows metadata to **Dynamics GP UserOps**.
- Added the `DynamicsGPUserOps.exe` executable, a navy/blue UO monogram, and a new installer AppId.
- Converted the WPF application to English and retained bilingual English/Spanish Setup and offline guides.
- Added the independent-product notice. Dynamics GP UserOps is not affiliated with or endorsed by Microsoft.

## User experience

- Introduced a navy/blue enterprise visual system with a persistent product header, left navigation, status badges, cards, cleaner tables, improved keyboard focus, disabled states, DPI behavior, and scroll reset on navigation.
- Renamed the application areas to Overview, Departments, Users, Activity, and Settings.
- Renamed wizard steps to Connect, Verify, Install, Configure, Test, and Activate.
- Corrected smoke-test capture rendering so the product header and footer are included instead of clipped.

## Upgrade and compatibility

- Setup detects the GP Users Manager 3.x Windows product, requires an interactive upgrade with the old console closed, replaces only the legacy console, and leaves SQL databases and Agent jobs running.
- Legacy checks run on every installation attempt. Cancellation or uninstall failure cannot bypass the check on retry; a successful uninstaller exit is followed by verification that the old product registration was removed.
- First launch copies a password-free profile from `%LocalAppData%\GPUsersManager` to `%LocalAppData%\DynamicsGPUserOps`. The original profile is retained.
- New installations default to the `DynamicsGPUserOps` database. Upgrades continue using the database name stored in the imported profile.
- Schema version 4 updates branded metadata and the test-message procedure only. Existing `gpManager*` tables, roles, views, `SP_GPUM_*` procedures, policies, and jobs remain compatible.
- New jobs use a Dynamics GP UserOps name. An existing selected job keeps its actual name and schedule identity; Setup does not create a duplicate.

## Packaging and verification

- Setup supports Windows 11 x64 and Windows Server 2016, 2019, 2022, and 2025 x64 with Desktop Experience. Server Core, Nano Server, Windows 10, x86, and ARM64 are outside this package target.
- The application remains self-contained; customers do not need .NET, `sqlcmd`, IIS, or Internet access during installation.
- Build validation covers product identity, profile migration, ApplicationName, schema 4, SQL contract preservation, icon frames, guide structure, 24 platform-policy cases, 12 retry-safe legacy-upgrade workflow cases, all embedded T-SQL batches, and screenshot output.
- Code signing is supported when a certificate thumbprint is supplied. Development builds without a certificate are explicitly reported as unsigned.

## Operational cautions

New installations are paused until an administrator explicitly activates automation. A GP message status of `QUEUED_GP` does not confirm that the user read it. Forced record removal is not a graceful GP logout. Complete acceptance with the exact customer SQL Server, Dynamics GP build, GP client, and native-message schema before enabling business-user enforcement.

Uninstall removes Windows application files only. SQL data, jobs, and local password-free profiles remain. No automatic downgrade of schema 4 is provided; recovery uses the customer's coordinated backup and restore procedure.

## Previous release — 3.0.1

- Added Windows Server Desktop Experience targets and 24 platform-policy tests.
- Added complete offline English/Spanish installation, testing, and server guides.
- Retained SQL schema 3 and the GP Users Manager 3.x application identity.

## Previous release — 3.0.0

- Added the WPF console, six-step SQL wizard, self-contained Setup, versioned migrations, scoped SQL roles, job control, diagnostics, audit history, customer registration, native GP notifications, and automated test sources.

This repository is licensed under MIT. Third-party components retain their own licenses.
