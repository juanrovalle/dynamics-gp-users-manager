# GP Users Manager for Windows

GP Users Manager 3.0.1 manages Microsoft Dynamics GP session quotas by department. A Windows administration console configures the product; SQL Server Agent runs the quota engine every minute, even when the console is closed.

## What is included

- A C# / WPF console for Windows 11 and Windows Server 2016/2019/2022/2025 x64 with Desktop Experience, targeting .NET 10 with a bundled runtime.
- A six-step installation and upgrade wizard: connect, verify, install, configure, test, activate.
- Five administration screens: overview, departments, GP user assignments, history, settings.
- Versioned SQL migrations executed through Microsoft.Data.SqlClient. Customers do not need sqlcmd, IIS, a .NET installation or an application on every GP workstation.
- Department quotas, enabled/disabled departments, optimistic concurrency checks and audited changes.
- Server-side pause/resume, execution status, password-free diagnostic export and customer registration.
- An optional SSRS report. SSRS is not required for normal operation.

The console is currently in Spanish. The setup program supports English and Spanish.

## Installation

Download the distributed `Setup.exe`, install the console on Windows 11 x64 or Windows Server 2016/2019/2022/2025 x64 with Desktop Experience and open **Asistente de instalación / actualización**.

The same installer covers Windows workstations and servers. It rejects Server Core, Nano Server, Windows 10 and unlisted server builds; server eligibility is checked separately from the Windows 11 minimum. The installer includes the application, runtime, embedded migration scripts and documentation. No Internet access is needed on the customer's computer. SQL Server and Dynamics GP are existing customer prerequisites; they are not installed by Setup.

For server-specific steps, local/remote SQL connections and RDP operation, see [Windows Server installation](docs/windows-server.md). The console is not a Windows service: the existing SQL Server Agent engine remains independent of console or RDP sessions.

Follow the complete [installation and testing guide](docs/installation-and-testing.html), also available from the Start menu after installation. It includes account preparation, every wizard step, expected test results, upgrades, uninstall behavior and troubleshooting.

New databases have automation **paused** until an administrator explicitly activates it. Upgrades retain existing data, configuration and policies. When earlier quota jobs are detected, the wizard requires an explicit selection; the other detected jobs are disabled only during the confirmed final step.

## How the engine works

The engine selects the most recent session belonging to an enabled department whose quota is exceeded. It removes **at most one session per execution**, serializes concurrent executions and records the outcome.

The original forced-removal policy is retained: selected GP/Dexterity records are removed from ACTIVITY, DEX_SESSION, DEX_LOCK, SY00800 and SY00801. This does **not** gracefully close the GP client or kill a SQL connection. Removing records from an active session can interrupt work. Validate the policy with controlled test users before enabling it for business users.

An optional policy blocks the selected candidate when SY00800/SY00801 activity exists. Absence of these records is not proof of inactivity. When the selected candidate is blocked, the engine does not remove an older user instead.

Native notifications use a schema-checked SY30000 adapter. Removal, audit and notification insertion share a transaction: a notification error rolls the removal back. **QUEUED_GP means queued, not read.** Verify actual delivery with the installed GP client, including after removal. See [notification integration](docs/gp-notifications.md).

The overview reports “Sin ejecución reciente” after more than three minutes without a recorded completion. That status alone does not identify whether Agent, permissions, connectivity or another cause is responsible.

## Security and persistence

- Installation requires a SQL administrator. Daily operation uses separately selected existing Windows or SQL identities.
- Reader, administrator and automation roles are separate. The wizard adds permissions; it does not remove permissions previously assigned outside the product.
- The job owner is an explicitly selected SQL administrator. It restores the required tempdb permissions after server restarts, then impersonates a restricted engine login for quota processing.
- SQL passwords remain in process memory only. Saved profiles contain connection metadata, not passwords. Database connections require encryption; trusting a server certificate is an explicit IT choice.
- Uninstalling the console leaves SQL databases, configuration and jobs intact. Automation continues unless explicitly paused.
- Maintenance dates are informational. There is no online activation, license file or expiration lockout.

## Building from source

Developer prerequisites: Windows, .NET 10 SDK (see `global.json`), NuGet access and Inno Setup 7. Customer machines do not need these tools.

```powershell
dotnet run --project tests/GPManager.Tests
.\build.ps1 -InnoCompiler 'C:\Program Files\Inno Setup 7\ISCC.exe'
```

The package is written to `artifacts/installer/Setup.exe`. Supply `-CertificateThumbprint` and `-RequireSignature` for a digitally signed build; the certificate must already be installed in the certificate store. No private certificate is included in this repository.

For a read-only demonstration:

```powershell
.\GPUsersManager.exe --demo
```

The legacy PowerShell/SQLCMD installer remains available under `src/Install` for DBA-controlled maintenance. It is not the customer installation path and does not replace the console wizard's permission and activation steps.

## Testing and compatibility

See [automated tests](tests/README.md), [compatibility and verification status](docs/compatibility.md), and [release notes](docs/release-notes.md).

Local compilation, unit tests, SQL parsing and demonstration-screen rendering are not equivalent to a successful SQL Server/GP deployment. Record the exact SQL version, GP version/build and client configuration used for environment acceptance. Do not advertise combinations that have not been tested.

## Commercial distribution and license

The intended offer is a purchase per managed instance, installation services and optional annual maintenance. The purchased version keeps working without renewal. Commercial terms do not replace or restrict the repository's existing [MIT license](LICENSE). Third-party components retain their own licenses.

See [commercial delivery scope](docs/commercialization.md).
