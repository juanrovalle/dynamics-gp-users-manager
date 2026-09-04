// Shared by production Setup and the non-installing platform test harness.
// Build families: Windows Server LTSC 2016, 2019, 2022, 2025.
// Registry InstallationType must be "Server" (Desktop Experience), not Core/Nano.
function UserOpsPlatformSupported(Major, Minor, Build, ProductType: Cardinal;
  InstallationType: String): Boolean;
begin
  Result := False;
  if (Major <> 10) or (Minor <> 0) then Exit;
  if ProductType = VER_NT_WORKSTATION then
  begin
    Result := (Build >= 22000) and (CompareText(Trim(InstallationType), 'Client') = 0);
    Exit;
  end;
  if (ProductType <> VER_NT_SERVER) and
     (ProductType <> VER_NT_DOMAIN_CONTROLLER) then Exit;
  if CompareText(Trim(InstallationType), 'Server') <> 0 then Exit;
  Result := (Build = 14393) or (Build = 17763) or
            (Build = 20348) or (Build = 26100);
end;

function UserOpsCurrentPlatformSupported(): Boolean;
var
  Version: TWindowsVersion;
  InstallationType: String;
begin
  GetWindowsVersionEx(Version);
  InstallationType := '';
  if not RegQueryStringValue(HKLM64, 'SOFTWARE\Microsoft\Windows NT\CurrentVersion',
    'InstallationType', InstallationType) then
  begin
    Log('Dynamics GP UserOps: cannot determine the Windows installation type.');
    Result := False;
    Exit;
  end;
  Log(Format('UserOps platform: %d.%d.%d; ProductType=%d; InstallationType=%s', [Version.Major, Version.Minor, Version.Build, Version.ProductType, InstallationType]));
  Result := UserOpsPlatformSupported(Version.Major, Version.Minor, Version.Build,
    Version.ProductType, InstallationType);
end;
