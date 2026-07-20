#Requires -Version 5.1

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$QtInstallerUrl = `
    "https://download.qt.io/official_releases/online_installers/qt-online-installer-windows-x64-online.exe"

$DownloadDirectory = "C:\OEM\downloads"
$InstallerPath     = Join-Path $DownloadDirectory "qt-online-installer-windows-x64-online.exe"
$PublicDesktop     = [Environment]::GetFolderPath("CommonDesktopDirectory")

function Write-Status {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
}

function New-DesktopShortcut {
    param(
        [Parameter(Mandatory)]
        [string]$ShortcutPath,

        [Parameter(Mandatory)]
        [string]$TargetPath,

        [string]$Arguments = "",

        [string]$WorkingDirectory = "",

        [string]$Description = ""
    )

    $Shell = New-Object -ComObject WScript.Shell
    $Shortcut = $Shell.CreateShortcut($ShortcutPath)

    $Shortcut.TargetPath = $TargetPath
    $Shortcut.Arguments = $Arguments

    if ($WorkingDirectory) {
        $Shortcut.WorkingDirectory = $WorkingDirectory
    }

    if ($Description) {
        $Shortcut.Description = $Description
    }

    $Shortcut.Save()
}

try {
    Write-Status "Preparing Qt installer download."

    New-Item `
        -ItemType Directory `
        -Path $DownloadDirectory `
        -Force | Out-Null

    # Windows PowerShell 5.1 can otherwise attempt older TLS versions.
    [Net.ServicePointManager]::SecurityProtocol = `
        [Net.ServicePointManager]::SecurityProtocol -bor `
        [Net.SecurityProtocolType]::Tls12

    if (Test-Path -LiteralPath $InstallerPath) {
        Write-Status "Removing an existing Qt installer download."
        Remove-Item -LiteralPath $InstallerPath -Force
    }

    Write-Status "Downloading the official Qt online installer."
    Write-Status "Source: $QtInstallerUrl"

    Invoke-WebRequest `
        -Uri $QtInstallerUrl `
        -OutFile $InstallerPath `
        -UseBasicParsing

    if (-not (Test-Path -LiteralPath $InstallerPath)) {
        throw "The Qt installer was not downloaded."
    }

    $InstallerFile = Get-Item -LiteralPath $InstallerPath

    if ($InstallerFile.Length -lt 10MB) {
        throw "The downloaded installer is unexpectedly small: $($InstallerFile.Length) bytes."
    }

    Write-Status "Downloaded $([Math]::Round($InstallerFile.Length / 1MB, 1)) MB."

    Unblock-File -LiteralPath $InstallerPath

    $InstallerShortcut = Join-Path $PublicDesktop "Install Qt.lnk"

    New-DesktopShortcut `
        -ShortcutPath $InstallerShortcut `
        -TargetPath $InstallerPath `
        -WorkingDirectory $DownloadDirectory `
        -Description "Run the official Qt online installer"

    Write-Status "Created desktop shortcut: $InstallerShortcut"

    $ExportScript = "C:\OEM\export-qt.ps1"

    if (-not (Test-Path -LiteralPath $ExportScript)) {
        throw "The export script was not found: $ExportScript"
    }

    $ExportShortcut = Join-Path $PublicDesktop "Export Qt to Shared Folder.lnk"

    New-DesktopShortcut `
        -ShortcutPath $ExportShortcut `
        -TargetPath "powershell.exe" `
        -Arguments "-NoLogo -NoProfile -ExecutionPolicy Bypass -File `"$ExportScript`"" `
        -WorkingDirectory "C:\OEM" `
        -Description "Create the Qt ZIP in the Windows Shared desktop folder"

    Write-Status "Created desktop shortcut: $ExportShortcut"

    $Instructions = @"
QT PREREQUISITE CONTAINER

1. Double-click "Install Qt" on the desktop.

2. Sign in using your Qt account and accept the applicable terms.

3. Install:

   Qt 6.5.3
     MSVC 2019 64-bit
     Qt Multimedia
     Qt WebEngine
     Qt WebSockets

   Allow the installer to automatically select any additional required dependencies (e.g., Qt Positioning and Qt WebChannel).

4. Keep the installation root set to:

   C:\Qt

5. After installation, double-click:

   Export Qt to Shared Folder

The resulting file should be:

   Desktop\Shared\qt-6.5.3-msvc2019_64.zip

That file will also appear in the Docker host directory bind-mounted
to /shared.
"@

    $InstructionsPath = Join-Path $PublicDesktop "Qt Installation Instructions.txt"

    Set-Content `
        -LiteralPath $InstructionsPath `
        -Value $Instructions `
        -Encoding UTF8

    Write-Status "Created installation instructions."
    Write-Status "Qt prerequisite preparation completed successfully."
}
catch {
    Write-Error $_
    exit 1
}

