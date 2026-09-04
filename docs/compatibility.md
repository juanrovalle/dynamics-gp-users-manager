# Compatibility and verification status

Version: 4.0.0. SQL schema: 4.

| Component | Implementation target | Verification status |
| --- | --- | --- |
| Administration workstation | Windows 11 x64 | WPF build and local demonstration rendering verified; clean-machine install acceptance required |
| Administration server | Windows Server 2016 / 2019 / 2022 / 2025 x64 with Desktop Experience | Installer policy tested with simulated OS inputs; no actual Server installation executed locally |
| Server Core / Nano Server | No local graphical console | Rejected by Setup; use a separate supported administration computer |
| Windows Server 2012 / 2012 R2, Windows 10, ARM64, x86 | Outside the package target | Not accepted by this installer |
| Runtime | .NET 10, self-contained | Included in Windows publish; no customer SDK requirement |
| SQL Server | 2016 SP1 or later with Agent | Minimum enforced by preflight; no SQL deployment executed in this development environment |
| SQL Server Express | Not supported by this distribution | Agent is required |
| GP client | Exact version/build recorded by the customer | No real GP build has been certified or verified here |
| Native messages | SY30000 with compatible columns/types/defaults | Adapter and schema checks implemented; real reception after removal must be tested |
| SSRS | Optional report | XML and query bindings checked; report rendering not verified here |
| Digital signature | Optional build-time signing | Certificate not supplied; this generated package is unsigned |

The server installer recognizes LTSC build families 14393, 17763, 20348 and 26100 and requires the Desktop Experience installation type. Accepting a platform is not evidence of successful deployment on it. Keep Windows, SQL and GP within their vendors' support lifecycles and apply current security updates.

Platform references: [Microsoft .NET on Windows](https://learn.microsoft.com/en-us/dotnet/core/install/windows), [Windows Server releases](https://learn.microsoft.com/en-us/windows/release-health/windows-server-release-info), [Server Core vs Desktop Experience](https://learn.microsoft.com/en-us/windows-server/get-started/install-options-server-core-desktop-experience).

The SQL minimum is an implementation prerequisite, not a claim that every combination of SQL Server and GP is supported by Microsoft. Apply the customer's GP support matrix as well.

Record for every validated installation: Windows build; SQL product version, edition and collation; GP version/build; GP system database; company; local or RDS/Citrix client; authentication mode; message schema; backup reference; test date; tester; results. Keep “not run” distinct from “failed.”

No Microsoft certification or universal GP compatibility is claimed by this document. Dynamics GP UserOps is an independent product and is not affiliated with or endorsed by Microsoft.
