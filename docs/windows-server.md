# Dynamics GP UserOps — Windows Server installation (4.0.0)

Offline HTML editions of this guide are available in [English](windows-server.en.html) and [Español](windows-server.es.html), with a [language selector](index.html). Both editions are included in Setup and linked from the Start menu.

The same Setup.exe is prepared for Windows 11 x64 and Windows Server 2016, 2019, 2022 and 2025 x64 **with Desktop Experience**. Version 4.0.0 uses SQL schema 4.

This describes the package's installation targets, not completed certification on those servers. Run and record acceptance tests on the customer's exact Windows, SQL Server and GP build.

## 1. Choose the administration host

Install the console on an administration server with a graphical desktop, or on a separate Windows 11 workstation. It may be on the SQL Server machine, but that is not required.

Do not install this graphical console on Server Core or Nano Server. The installer rejects those installation types. If SQL/GP is hosted on a headless server, use a separate supported administration computer and validate the server-side SQL/GP compatibility independently.

Do not change server roles, add IIS, enable RDP or expose SQL ports simply to install the console. IT must approve any infrastructure changes separately. Installing the console on a domain controller is not recommended; a detected server product type is not a recommendation for that architecture.

## 2. Check prerequisites

From PowerShell on the intended administration computer:

```powershell
Get-CimInstance Win32_OperatingSystem |
    Select-Object Caption, Version, BuildNumber, OSArchitecture, ProductType
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' |
    Select-Object InstallationType
```

InstallationType must be `Server`, not `Server Core` or `Nano Server`. Setup accepts LTSC build families 14393 (2016), 17763 (2019), 20348 (2022) and 26100 (2025). Monthly revisions within those families do not require another installer.

Prepare an existing SQL Server with Agent, the GP system database and the separate manager database name. Keep the operating system, SQL and GP within the customer's supported lifecycle and patch policy. Runtime support alone does not certify GP.

Prepare the account responsibilities from the main guide: Windows installer elevation, SQL installation administration, daily product operation, and restricted motor identity plus explicitly selected Agent owner. No SQL passwords are passed to Setup.

## 3. Install the Windows files

1. Copy Setup.exe and compare its SHA-256 with the provided checksum.
2. Sign in locally or through an authorized RDP desktop session.
3. Run Setup as a Windows administrator, review the license and install.
4. Open Dynamics GP UserOps from the Start menu.
5. Follow the six-step SQL installation wizard in [the main guide](installation-and-testing.en.html).

The package includes the .NET Desktop Runtime. No SDK, sqlcmd, ASP.NET Hosting Bundle or IIS is needed. Installation makes no Internet downloads.

Optional unattended **file installation**, from elevated PowerShell:

```powershell
# Work in the folder containing Setup.exe.
New-Item -ItemType Directory -Path 'C:\Temp\UserOps' -Force | Out-Null
$setupProcess = Start-Process -FilePath '.\Setup.exe' `
    -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/LOG="C:\Temp\UserOps\setup.log"' `
    -WindowStyle Hidden -Wait -PassThru
if ($setupProcess.ExitCode -ne 0) {
    throw "Setup failed or requires attention; exit code $($setupProcess.ExitCode). Inspect C:\Temp\UserOps\setup.log."
}
```

This does not silently install SQL objects, grant SQL permissions or enable removals. Open the console and complete the wizard interactively afterward. The generated delivery is unsigned; apply the customer's software-origin policy and use build.ps1's signing option when a certificate is available.

## 4. Connect to SQL

For local SQL use its actual server/instance name, such as `SRV-GP` or `SRV-GP\GPINSTANCE`. For remote SQL, use the approved host/instance or `host,port`. Windows local administrator rights do not automatically grant SQL administrator rights.

Retain encrypted SQL connections. IT should verify the certificate, endpoint and authentication before making any security changes.

For a known fixed TCP port, IT may check connectivity without changing firewall rules:

```powershell
# Substitute the endpoint and port actually assigned by the DBA.
Test-NetConnection -ComputerName 'SRV-SQL' -Port 1433
```

Named instances may use another port. A successful TCP check is not a successful SQL login or proof of GP permissions.

## 5. Verify server operation

Run the main acceptance checklist, then additionally:

- Test the intended local/remote SQL connection and both authorized authentication methods.
- Confirm installation starts on the selected Desktop Experience host, and is rejected on Core/Nano before application files are installed.
- Check that another RDP user's connection profile is separate and contains no password.
- Close the console and sign out of RDP. Observe from another authorized computer that SQL Agent continues enforcing quotas.
- Pause automation and confirm a subsequent PAUSED execution. Pausing is global for that managed database, not just the current RDP user.
- Restart SQL/Agent in the isolated test environment, prepare the GP/Dexterity tables through the GP client and verify job recovery.
- Validate the native GP message on the actual GP client; running the console on Server is not evidence that a GP user saw a notification.

The product does not add a Windows service or a Windows Task Scheduler task. SQL Server Agent remains the engine. No interactive account needs to stay signed in to keep it running.

## 6. Upgrade or uninstall

To upgrade from GP Users Manager 3.x, close the old console and run Dynamics GP UserOps 4.0.0 Setup interactively. Setup detects the legacy AppId, explains the replacement, runs the legacy console uninstaller, and installs the new Windows product. SQL databases and SQL Server Agent jobs continue running. At first launch, UserOps copies the password-free profile to its new LocalAppData folder and retains the old copy. Select the existing manager database and job; do not create replacements.

Schema migration 4 updates branding and the test-message procedure without changing quota policies or the compatible `gpManager*` / `SP_GPUM_*` contract. Run the migration through the wizard after verifying the customer backup.

If upgrading from the original SQL-only schema, follow the full SQL upgrade wizard. Do not create a new manager database in place of upgrading the existing one.

Uninstall removes the console, not SQL databases or the job. To stop automation, pause it and verify PAUSED before the DBA disables the job and Windows uninstalls the console.

## Verification references

- [Microsoft .NET supported Windows platforms](https://learn.microsoft.com/en-us/dotnet/core/install/windows).
- [Microsoft Windows Server release/build information](https://learn.microsoft.com/en-us/windows/release-health/windows-server-release-info).
- [Microsoft Server Core and Desktop Experience differences](https://learn.microsoft.com/en-us/windows-server/get-started/install-options-server-core-desktop-experience).

Microsoft Dynamics GP is a Microsoft product. Dynamics GP UserOps is independent and is not affiliated with or endorsed by Microsoft.
