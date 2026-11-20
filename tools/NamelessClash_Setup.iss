[Setup]
AppId={{8F4C2A1E-7D3B-4B9E-9A51-3E7C6B2D4F10}
AppName=Nameless Clash
AppVersion=1.0.0
AppPublisher=Nameless Clash
DefaultDirName={autopf}\Nameless Clash
DefaultGroupName=Nameless Clash
AllowNoIcons=yes
OutputDir=..\builds
OutputBaseFilename=NamelessClash_Setup
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\builds\NamelessClash.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\builds\NamelessClash.pck"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{group}\Nameless Clash"; Filename: "{app}\NamelessClash.exe"
Name: "{group}\Nameless Clash (LAN 2nd Window)"; Filename: "{app}\NamelessClash.exe"; Parameters: "-w --resolution 900x520 -- --profile=p2"
Name: "{group}\{cm:UninstallProgram,Nameless Clash}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Nameless Clash"; Filename: "{app}\NamelessClash.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\NamelessClash.exe"; Description: "{cm:LaunchProgram,Nameless Clash}"; Flags: nowait postinstall skipifsilent
