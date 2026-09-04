# Verification guide

## Tests that do not require SQL Server

From the repository root on Windows with the .NET 10 SDK:

```powershell
.\tests\Validate.ps1
dotnet run --project tests/DynamicsGP.UserOps.Tests
dotnet build src/DynamicsGP.UserOps.Desktop
dotnet run --project src/DynamicsGP.UserOps.Desktop -- --smoke-test C:\Temp\UserOps-UI --smoke-scale 1
dotnet run --project src/DynamicsGP.UserOps.Desktop -- --smoke-test C:\Temp\UserOps-UI-125 --smoke-scale 1.25
dotnet run --project src/DynamicsGP.UserOps.Desktop -- --smoke-test C:\Temp\UserOps-UI-150 --smoke-scale 1.5
```

The console test runner checks product version and ApplicationName, state thresholds, SQL identifier validation, authentication connection strings, password-free profile persistence and 3.x profile migration, SQL batch parsing, the schema-v4 contract, embedded migration resources, and T-SQL syntax using Microsoft's ScriptDom parser. It exits nonzero on failure.

The WPF smoke test renders all five console screens and all six wizard steps using fictitious, read-only data. Run it at 100%, 125%, and 150%, then inspect all 33 PNGs and each `result.txt`. It does not connect to SQL Server or send messages.

`Validate.ps1` checks PowerShell syntax, SQL include paths, unsafe database-name rejection, SSRS report XML/query bindings and the bilingual guides. The normal build and Windows CI workflow both run this validation.

To check only documentation, without the SDK or a database:

```powershell
.\tests\Validate-Guides.ps1
```

The guide validator checks all six HTML files for well-formed structure, unique anchors, valid local links, offline dependencies and PowerShell snippet syntax. It compares English/Spanish section structure and all 17 acceptance scenarios, verifies the legacy Spanish copy and checks that the installer includes documentation and all five guide shortcuts. These are static checks, not browser rendering or completed SQL/GP acceptance tests.

## Windows installer platform tests

With Inno Setup installed, run:

```powershell
.\tests\Test-WindowsPlatform.ps1 -InnoCompiler 'C:\Program Files\Inno Setup 7\ISCC.exe'
```

The harness compiles the exact platform-policy include used by Setup and executes 24 cases: Server Desktop Experience, Server Core, Nano, Windows 11, Windows 10, older/unlisted versions and unknown metadata. It exits before installation and writes a log under `artifacts/platform-tests`. It does not install files, shortcuts, registry keys or an uninstaller. These are simulated OS-input tests, not actual Server deployments. The normal build runs this harness before packaging.

## Legacy installer upgrade workflow tests

```powershell
.\tests\Test-LegacyUpgrade.ps1 -InnoCompiler 'C:\Program Files\Inno Setup 7\ISCC.exe'
```

The harness compiles the same `LegacyUpgrade.iss` workflow used by Setup, with mocked Windows adapters, and runs 12 cases. It covers clean installs, silent/running-console guards, a missing uninstaller, cancellation, launch failure, nonzero exit, residual product registration, repeated attempts, successful retries, and Spanish error text. A canceled or failed attempt must never allow a later attempt to bypass the legacy check. Setup verifies that the previous product registration disappeared after a successful uninstaller exit.

The harness does not install or uninstall a product and does not touch registry entries, SQL databases, or jobs. Its results supplement, but do not replace, an actual 3.0.1-to-4.0.0 Windows upgrade test. The normal build runs it before packaging.

## SQL integration suite

**Use a disposable SQL Server instance only.** The fixture refuses to reuse existing test databases. Do not substitute production database names.

The SQL integration GitHub Actions workflow creates an isolated SQL Server 2022 container, migrates legacy data to schema 4, injects and verifies a transactional v4 rollback, runs the successful v4 migration twice, checks a fresh installation and executes:

- `integration.sql`: data preservation, quota selection, manual cleanup guards, rollback, constraints and caller transaction handling.
- `automation.sql`: paused installation, explicit activation, activity protection, atomic native-message failure, forced removal, one removal per execution, native-message sequence preservation.
- `administration.sql`: quota edits, stale-revision rejection, user mapping, customer registration without maintenance lockout, pause, notification confirmation and reader permission denial.

To reproduce manually with a disposable server, use sqlcmd as a **developer test dependency**, working from `src/Install`:

```powershell
sqlcmd -S TESTSERVER -E -b -i ../../tests/fixture.sql
sqlcmd -S TESTSERVER -E -b -i install.sql -v ManagerDatabase=GPManagerTest GPDatabase=GPManagerTestGP DexDatabase=GPManagerTestDex
# The CI workflow uses prepare-v4-rollback.sql and verify-v4-rollback.sql around an intentionally failed migration.
# Run the successful migration command a second time to test repeatability.
sqlcmd -S TESTSERVER -E -b -i ../../tests/integration.sql
sqlcmd -S TESTSERVER -E -b -i ../../tests/automation.sql
sqlcmd -S TESTSERVER -E -b -i ../../tests/administration.sql
```

The fixture models a subset of GP tables. Passing it does not prove compatibility with a real GP installation. The SQL suite has not been executed on this development machine; a workflow definition is not evidence of a successful CI run.

## Full environment acceptance

Follow the step-by-step installation and testing guide in [English](../docs/installation-and-testing.en.html) or [Español](../docs/installation-and-testing.es.html). For Windows Server, also follow the server guide in [English](../docs/windows-server.en.html) or [Español](../docs/windows-server.es.html). Required checks include a clean Windows machine without .NET/sqlcmd, both authentication modes, restricted permissions, interrupted connections, original-schema upgrades, duplicate jobs, concurrent edits and executions, rollback, Agent operation with the console closed, server restart, actual GP message delivery after removal, update and uninstall preservation.

Retain exact version/build information, screenshots, diagnostic exports and observed outcomes. Do not record “pass” for a test that was only reviewed in source.
