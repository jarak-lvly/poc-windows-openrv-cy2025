#Requires -Version 5.1

[CmdletBinding()]
param(
    [string]$QtVersion = "6.5.3",
    [string]$QtKit = "msvc2019_64"
)

$ErrorActionPreference = "Stop"

$QtVersionDirectory = Join-Path "C:\Qt" $QtVersion
$QtSourceDirectory  = Join-Path $QtVersionDirectory $QtKit
$ArchiveName        = "qt-$QtVersion-$QtKit.zip"

function Write-Status {
    param(
        [Parameter(Mandatory)]
        [string]$Message
    )

    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
}

function Find-SharedDirectory {
    $Candidates = @(
        (Join-Path $env:USERPROFILE "Desktop\Shared"),
        (Join-Path $env:USERPROFILE "OneDrive\Desktop\Shared"),
        "C:\Users\Public\Desktop\Shared"
    )

    foreach ($Candidate in $Candidates) {
        if ($Candidate -and (Test-Path -LiteralPath $Candidate -PathType Container)) {
            return $Candidate
        }
    }

    throw @"
The Windows Shared desktop folder could not be found.

Confirm that the Compose file contains a /shared bind mount and that
the Shared folder is visible on the Windows desktop.
"@
}

try {
    Write-Status "Checking Qt installation."

    if (-not (Test-Path -LiteralPath $QtSourceDirectory -PathType Container)) {
        throw @"
The expected Qt directory does not exist:

    $QtSourceDirectory

Install Qt $QtVersion with the $QtKit component before running this script.
"@
    }

    $QMakePath = Join-Path $QtSourceDirectory "bin\qmake.exe"

    if (-not (Test-Path -LiteralPath $QMakePath -PathType Leaf)) {
        throw "qmake.exe was not found under the expected Qt kit: $QMakePath"
    }

    $SharedDirectory = Find-SharedDirectory
    $ArchivePath = Join-Path $SharedDirectory $ArchiveName

    Write-Status "Qt source: $QtSourceDirectory"
    Write-Status "ZIP output: $ArchivePath"

    if (Test-Path -LiteralPath $ArchivePath) {
        Write-Status "Removing the existing ZIP."
        Remove-Item -LiteralPath $ArchivePath -Force
    }

    Write-Status "Creating ZIP. This may take several minutes."

    # Compressing the kit directory itself means the archive contains:
    #
    #   msvc2019_64\
    #       bin\
    #       include\
    #       lib\
    #       ...
    #
    # The OpenRV build container can therefore extract the ZIP into:
    #
    #   C:\Qt\6.5.3
    #
    Compress-Archive `
        -LiteralPath $QtSourceDirectory `
        -DestinationPath $ArchivePath `
        -CompressionLevel Optimal `
        -Force

    if (-not (Test-Path -LiteralPath $ArchivePath -PathType Leaf)) {
        throw "PowerShell completed without creating the ZIP."
    }

    $Archive = Get-Item -LiteralPath $ArchivePath

    Write-Status "ZIP created successfully."
    Write-Status "Size: $([Math]::Round($Archive.Length / 1GB, 2)) GB"

    $Message = @"
Qt export completed successfully.

ZIP file:

$ArchivePath

Qt source:

$QtSourceDirectory

The ZIP should now also be visible in the Docker host directory
bind-mounted to /shared.
"@

    Write-Host ""
    Write-Host $Message

    Add-Type -AssemblyName PresentationFramework
    [System.Windows.MessageBox]::Show(
        $Message,
        "Qt Export Complete",
        "OK",
        "Information"
    ) | Out-Null
}
catch {
    $Message = $_.Exception.Message

    Write-Error $Message

    try {
        Add-Type -AssemblyName PresentationFramework
        [System.Windows.MessageBox]::Show(
            $Message,
            "Qt Export Failed",
            "OK",
            "Error"
        ) | Out-Null
    }
    catch {
        # The console error above remains available if the GUI message fails.
    }

    exit 1
}

