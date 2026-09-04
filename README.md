# Dynamics GP UserOps

Dynamics GP UserOps 4.0.0 is a Windows administration product for managing Microsoft Dynamics GP session quotas by department. Administrators use an English-language desktop console; SQL Server Agent continues running the quota engine every minute when the console is closed.

## Product capabilities

- Self-contained C# / WPF console for Windows 11 x64 and Windows Server 2016, 2019, 2022, or 2025 x64 with Desktop Experience.
- Six-step installation and upgrade wizard: Connect, Verify, Install, Configure, Test, and Activate.
- Five administration areas: Overview, Departments, Users, Activity, and Settings.
- Versioned SQL migrations executed with Microsoft.Data.SqlClient. Customer computers do not need `sqlcmd`, IIS, a .NET installation, or software on every GP workstation.
- Department quotas, enabled/disabled departments, GP-user assignments, optimistic concurrency, audit history, native GP message queuing, and password-free diagnostics.
- Server-side pause/resume and status reporting. Closing or uninstalling the console does not silently stop the SQL engine.
- Optional SSRS report; SSRS is not required for normal operation.

The application interface is English. Setup and the complete offline guides are available in English and Spanish.

## Installation

Download the distributed `Setup.exe`, verify its SHA-256 checksum and digital signature, and install it on a supported graphical Windows computer. Setup includes the application, .NET runtime, migration scripts, license, and documentation and makes no Internet downloads. SQL Server and Dynamics GP are existing customer prerequisites.

Open the offline [guide selector — English / Español](docs/index.html), or choose a guide:

| Guide | English | Español |
| --- | --- | --- |
| Installation and testing | [English](docs/installation-and-testing.en.html) | [Español](docs/installation-and-testing.es.html) |
| Windows Server | [English](docs/windows-server.en.html) | [Español](docs/windows-server.es.html) |

New installations use `DynamicsGPUserOps` as the default manager database and remain paused until an administrator explicitly activates automation. An upgrade from GP Users Manager 3.x removes only the old Windows console, retains its SQL database and jobs, and copies the password-free profile from `%LocalAppData%\GPUsersManager` to `%LocalAppData%\DynamicsGPUserOps` on first launch. The original profile is not deleted. Existing database names and policies are preserved.

## Engine behavior

The engine selects the most recent session in an enabled department whose quota is exceeded. It removes at most one session per execution, serializes concurrent executions, and records the result. Existing SQL tables, roles, views, and procedures named `gpManager*` and `SP_GPUM_*` remain the compatible database contract in version 4.

Forced record removal is not a graceful GP logout and does not kill a SQL connection. It can interrupt work. An optional policy blocks a selected candidate when SY00800/SY00801 activity exists; the absence of those records is not proof of inactivity.

Native notifications use a schema-checked SY30000 adapter. Removal, audit, and notification insertion share a transaction, so a notification error rolls back the removal. `QUEUED_GP` means queued, not read. Confirm actual reception after removal with the customer's installed GP client. See [notification integration](docs/gp-notifications.md).

Overview displays **No recent execution** after more than three minutes without a recorded completion. The status does not by itself identify whether Agent, permissions, connectivity, or another condition is responsible.

## Security and lifecycle

- Installation uses a SQL administrator; daily operation and job execution use separately selected existing identities with scoped roles.
- SQL passwords remain in process memory only and are never saved to profiles, logs, or diagnostics.
- Database connections require encryption; trusting a server certificate is an explicit IT choice.
- Uninstall removes Windows files only. SQL databases, configuration, audit data, and jobs are retained.
- Maintenance dates are informational. Version 4.0.0 has no activation server, license file, expiration lock, or remote shutdown.

## Build from source

Developer prerequisites are Windows, the .NET 10 SDK from `global.json`, NuGet access, and Inno Setup 7. Customer machines do not need these tools.

```powershell
dotnet run --project tests/DynamicsGP.UserOps.Tests
.\build.ps1 -InnoCompiler 'C:\Program Files\Inno Setup 7\ISCC.exe'
```

The package is written to `artifacts/installer/Setup.exe`. Provide `-CertificateThumbprint` and `-RequireSignature` for a signed commercial build. No private certificate is included in the repository, and an unsigned development package must not be represented as signed.

For a read-only demonstration:

```powershell
.\DynamicsGPUserOps.exe --demo
```

The legacy PowerShell/SQLCMD installer under `src/Install` remains available for DBA-controlled maintenance. It is not the customer installation path.

## Verification

See [automated tests](tests/README.md), [compatibility status](docs/compatibility.md), and [release notes](docs/release-notes.md). Local build, static analysis, SQL parsing, and screenshot rendering are not substitutes for acceptance on a real SQL Server and Dynamics GP installation. Record the exact Windows, SQL, GP, and client builds actually tested.

## Commercial distribution and license

The intended offer is a purchase per managed SQL instance, implementation services, and optional annual maintenance. The purchased version continues working without renewal. Commercial terms do not replace or restrict the existing [MIT license](LICENSE). Third-party components retain their own licenses. See [commercial delivery scope](docs/commercialization.md).

Microsoft Dynamics GP is a trademark or product of Microsoft. Dynamics GP UserOps is an independent product and is not affiliated with, endorsed by, sponsored by, or supported by Microsoft.
