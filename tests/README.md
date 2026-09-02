# Verification guide

## Tests that do not require SQL Server

From the repository root on Windows with the .NET 10 SDK:

```powershell
.\tests\Validate.ps1
dotnet run --project tests/GPManager.Tests
dotnet build src/GPManager.Desktop
dotnet run --project src/GPManager.Desktop -- --smoke-test C:\Temp\GPUM-UI
```

The console test runner checks state thresholds, SQL identifier validation, authentication connection strings, password-free profile persistence, SQL batch parsing, embedded migration resources and T-SQL syntax using Microsoft's ScriptDom parser. It exits nonzero on failure.

The WPF smoke test renders all five console screens and all six wizard steps using fictitious, read-only data. Inspect the generated PNGs and `result.txt`. It does not connect to SQL Server or send messages.

`Validate.ps1` checks PowerShell syntax, SQL include paths, unsafe database-name rejection and SSRS report XML/query bindings.

## Windows installer platform tests

With Inno Setup installed, run:

```powershell
.\tests\Test-WindowsPlatform.ps1 -InnoCompiler 'C:\Program Files\Inno Setup 7\ISCC.exe'
```

The harness compiles the exact platform-policy include used by Setup and executes 24 cases: Server Desktop Experience, Server Core, Nano, Windows 11, Windows 10, older/unlisted versions and unknown metadata. It exits before installation and writes a log under `artifacts/platform-tests`. It does not install files, shortcuts, registry keys or an uninstaller. These are simulated OS-input tests, not actual Server deployments. The normal build runs this harness before packaging.

## SQL integration suite

**Use a disposable SQL Server instance only.** The fixture refuses to reuse existing test databases. Do not substitute production database names.

The SQL integration GitHub Actions workflow creates an isolated SQL Server 2022 container, runs a legacy-schema migration twice, checks a fresh installation and executes:

- `integration.sql`: data preservation, quota selection, manual cleanup guards, rollback, constraints and caller transaction handling.
- `automation.sql`: paused installation, explicit activation, activity protection, atomic native-message failure, forced removal, one removal per execution, native-message sequence preservation.
- `administration.sql`: quota edits, stale-revision rejection, user mapping, customer registration without maintenance lockout, pause, notification confirmation and reader permission denial.

To reproduce manually with a disposable server, use sqlcmd as a **developer test dependency**, working from `src/Install`:

```powershell
sqlcmd -S TESTSERVER -E -b -i ../../tests/fixture.sql
sqlcmd -S TESTSERVER -E -b -i install.sql -v ManagerDatabase=GPManagerTest GPDatabase=GPManagerTestGP DexDatabase=GPManagerTestDex
# Run the preceding migration command a second time to test repeatability.
sqlcmd -S TESTSERVER -E -b -i ../../tests/integration.sql
sqlcmd -S TESTSERVER -E -b -i ../../tests/automation.sql
sqlcmd -S TESTSERVER -E -b -i ../../tests/administration.sql
```

The fixture models a subset of GP tables. Passing it does not prove compatibility with a real GP installation. The SQL suite has not been executed on this development machine; a workflow definition is not evidence of a successful CI run.

## Full environment acceptance

Follow [the step-by-step installation and testing guide](../docs/installation-and-testing.html). Required checks include a clean Windows machine without .NET/sqlcmd, both authentication modes, restricted permissions, interrupted connections, original-schema upgrades, duplicate jobs, concurrent edits and executions, rollback, Agent operation with the console closed, server restart, actual GP message delivery after removal, update and uninstall preservation.

Retain exact version/build information, screenshots, diagnostic exports and observed outcomes. Do not record “pass” for a test that was only reviewed in source.
