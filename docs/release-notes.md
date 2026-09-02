# Release notes — 3.0.1

## Windows Server installation

- One Setup.exe for Windows 11 and Windows Server 2016, 2019, 2022 and 2025 x64 with Desktop Experience.
- Fixed the Windows-11-only minimum that rejected older Windows Server build families.
- Separate workstation/server checks, fail-closed metadata detection, and explicit rejection of Server Core, Nano Server and unlisted server builds.
- Added 24 executable installer-policy test cases and server installation/RDP guidance.
- Application/package version is 3.0.1; SQL schema remains version 3. No quota policy, job engine or licensing behavior changed.
- Same installer identity and installation directory for updating 3.0.0. Actual Windows Server and SQL/GP deployment acceptance remains to be executed; this is not a claim of tested Server compatibility.

## Previous release — 3.0.0

## Added

- WPF Windows console and six-step SQL installation/upgrade wizard.
- Self-contained Windows x64 distribution packaged as Setup.exe.
- Embedded, versioned migrations using Microsoft.Data.SqlClient.
- Server-side configuration, pause/resume and execution status.
- Audited department editing and GP-user assignment with revision checks.
- Existing Windows/SQL identity provisioning and separate job runtime identity.
- Explicit previous-job selection and final activation.
- Customer registration without online activation or expiration enforcement.
- Password-free diagnostics, local demonstration and UI smoke-test mode.
- Installation/test guide, optional code-signing build and automated test sources.

## Preserved

- Existing MIT license, departments and user mappings.
- SQL Server Agent as the engine, with one removal per execution.
- Existing settings and policies on upgrade.
- Optional SSRS report and DBA maintenance scripts.

## Operational notes

New installations are paused. Queuing a GP notification is not confirmation that it was read. Forced record removal is not a graceful GP logout. Review the compatibility document and complete environment acceptance before enabling real-user enforcement.

Uninstall removes the console only. SQL objects/jobs and the local password-free profile remain. No rollback-to-an-older-schema procedure is provided; recovery requires the customer's coordinated backup/restore procedure.

The package generated in this development environment is unsigned. Local tests do not replace SQL Server/GP execution tests.
