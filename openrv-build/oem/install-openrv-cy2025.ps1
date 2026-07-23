# =============================================================================
# Configuration
#
# Most tool versions are pinned inline near each install step to make updates
# and future OpenRV release migrations easier.
# =============================================================================

$ErrorActionPreference = "Stop"

Start-Transcript -Path "C:\OEM\openrv-cy2025-install.log" -Append

$OEM = "C:\OEM"
$Downloads = "C:\OEM\downloads"
New-Item -ItemType Directory -Force $Downloads | Out-Null

function Download-File($Url, $OutFile) {
    if (Test-Path $OutFile) {
        Write-Host "Already downloaded: $OutFile"
        return
    }

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    Write-Host "Downloading $Url"
    for ($i = 1; $i -le 3; $i++) {
        try {
            Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
            return
        } catch {
            Write-Warning "Download attempt $i failed: $($_.Exception.Message)"
            Start-Sleep -Seconds 10
        }
    }

    throw "Failed to download $Url"
}

function Add-SystemPath($PathToAdd) {
    $current = [Environment]::GetEnvironmentVariable("Path", "Machine")
    if ($current -notlike "*$PathToAdd*") {
        [Environment]::SetEnvironmentVariable("Path", "$PathToAdd;$current", "Machine")
    }
}

Write-Host "=== OpenRV CY2025 Windows dev bootstrap ==="

# 1. Visual Studio Build Tools
$vsInstaller = "$Downloads\vs_BuildTools.exe"
Download-File "https://aka.ms/vs/17/release/vs_BuildTools.exe" $vsInstaller

Start-Process $vsInstaller -Wait -ArgumentList @(
    "--quiet",
    "--wait",
    "--norestart",
    "--config", "$OEM\openrv-cy2025.vsconfig"
)

# 2. CMake 3.31.7
$cmakeMsi = "$Downloads\cmake-3.31.7-windows-x86_64.msi"
Download-File "https://github.com/Kitware/CMake/releases/download/v3.31.7/cmake-3.31.7-windows-x86_64.msi" $cmakeMsi
Start-Process msiexec.exe -Wait -ArgumentList "/i `"$cmakeMsi`" /qn ADD_CMAKE_TO_PATH=System"

# 3. Python 3.11.x
$pythonExe = "$Downloads\python-3.11.9-amd64.exe"
Download-File "https://www.python.org/ftp/python/3.11.9/python-3.11.9-amd64.exe" $pythonExe

$pythonRoot = "C:\Program Files\Python311"

if (Test-Path "$pythonRoot\python.exe") {
    Write-Host "Python already installed at $pythonRoot; skipping."
} else {
    $p = Start-Process $pythonExe -Wait -PassThru -ArgumentList @(
        "/quiet",
        "InstallAllUsers=1",
        'TargetDir="C:\Program Files\Python311"',
        "PrependPath=1",
        "Include_pip=1"
    )

    if ($p.ExitCode -ne 0) {
        throw "Python installer failed with exit code $($p.ExitCode)"
    }
}

if (!(Test-Path "$pythonRoot\python3.exe")) {
    Copy-Item "$pythonRoot\python.exe" "$pythonRoot\python3.exe"
}

# 4. Strawberry Perl
$perlMsi = "$Downloads\strawberry-perl-5.42.2.1-64bit.msi"
Download-File "https://github.com/StrawberryPerl/Perl-Dist-Strawberry/releases/download/SP_54221_64bit/strawberry-perl-5.42.2.1-64bit.msi" $perlMsi
Start-Process msiexec.exe -Wait -ArgumentList "/i `"$perlMsi`" /qn"

# 5. Rust
$rustup = "$Downloads\rustup-init.exe"
Download-File "https://win.rustup.rs/x86_64" $rustup
Start-Process $rustup -Wait -ArgumentList "-y"

# 6. Git
$gitExe = "$Downloads\Git-2.51.0-64-bit.exe"

Download-File `
    "https://github.com/git-for-windows/git/releases/download/v2.51.0.windows.1/Git-2.51.0-64-bit.exe" `
    $gitExe

Start-Process $gitExe -Wait -ArgumentList @(
    "/VERYSILENT",
    "/NORESTART"
)

# 7. MSYS2
$msys2Exe = "$Downloads\msys2-x86_64-latest.exe"
Download-File "https://github.com/msys2/msys2-installer/releases/latest/download/msys2-x86_64-latest.exe" $msys2Exe
Start-Process $msys2Exe -Wait -ArgumentList @(
    "in", "--confirm-command", "--accept-messages",
    "--root", "C:\msys64"
)

# Update MSYS2 and install package list
& C:\msys64\usr\bin\bash.exe -lc "pacman -Syuu --noconfirm || true"
& C:\msys64\usr\bin\bash.exe -lc "pacman -Syuu --noconfirm || true"

$pkgText = Get-Content "$OEM\msys2-packages.txt" | Where-Object { $_ -and $_ -notmatch '^\s*#' }
$pkgList = $pkgText -join " "
& C:\msys64\usr\bin\bash.exe -lc "pacman -S --needed --noconfirm $pkgList"

# 8. sccache
$sccacheVersion = "0.15.0"
$sccacheArchive = "$Downloads\sccache-v$sccacheVersion-x86_64-pc-windows-msvc.tar.gz"
$sccacheUrl = "https://github.com/mozilla/sccache/releases/download/v$sccacheVersion/sccache-v$sccacheVersion-x86_64-pc-windows-msvc.tar.gz"
$sccacheDestDir = "C:\msys64\mingw64\bin"
$sccacheDest = "$sccacheDestDir\sccache.exe"

if (Test-Path $sccacheDest) {
    Write-Host "sccache already installed at $sccacheDest; skipping."
} else {
    Download-File $sccacheUrl $sccacheArchive

    $sccacheTemp = "$Downloads\sccache-extract"
    Remove-Item $sccacheTemp -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force $sccacheTemp | Out-Null
    New-Item -ItemType Directory -Force $sccacheDestDir | Out-Null

    & tar.exe -xf $sccacheArchive -C $sccacheTemp

    if ($LASTEXITCODE -ne 0) {
        throw "Failed to extract sccache archive"
    }

    $sccacheExe = Get-ChildItem $sccacheTemp -Recurse -Filter sccache.exe |
        Select-Object -First 1

    if (!$sccacheExe) {
        throw "sccache.exe was not found after extraction"
    }

    Copy-Item $sccacheExe.FullName $sccacheDest -Force

    if (!(Test-Path $sccacheDest)) {
        throw "sccache copy failed: $sccacheDest was not created"
    }

    Write-Host "Installed sccache to $sccacheDest"
}

# 9. Qt 6.5.3 (aqtinstall)
#
# This replaces the separate interactive Qt prerequisite container. The module
# list matches the components selected in the original Qt Online Installer and
# explicitly includes dependencies that the GUI installer selected
# automatically for Qt Quick 3D and Qt WebEngine.
$aqtVersion = "3.3.0"
$qtVersion = "6.5.3"
$qtArch = "win64_msvc2019_64"
$qtRoot = "C:\Qt"
$qtDest = Join-Path $qtRoot "$qtVersion\msvc2019_64"

$qtModules = @(
    "qtquick3d",
    "qtshadertools",
    "qtcharts",
    "qtdatavis3d",
    "qtimageformats",
    "qtmultimedia",
    "qtnetworkauth",
    "qtpositioning",
    "qtvirtualkeyboard",
    "qtwebchannel",
    "qtwebengine",
    "qtwebsockets",
    "qtquicktimeline"
)

if (Test-Path "$qtDest\bin\qmake.exe") {
    Write-Host "Qt already installed at $qtDest; skipping."
} else {
    Write-Host "Installing aqtinstall $aqtVersion"

    & "$pythonRoot\python.exe" -m pip install --upgrade pip
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to upgrade pip"
    }

    & "$pythonRoot\python.exe" -m pip install "aqtinstall==$aqtVersion"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install aqtinstall $aqtVersion"
    }

    New-Item -ItemType Directory -Force $qtRoot | Out-Null

    $aqtArguments = @(
        "-m", "aqt",
        "install-qt",
        "windows", "desktop",
        $qtVersion,
        $qtArch,
        "-O", $qtRoot,
        "-m"
    ) + $qtModules

    Write-Host "Installing Qt $qtVersion ($qtArch) to $qtRoot"
    Write-Host "Qt modules: $($qtModules -join ', ')"

    $qtInstalled = $false
    for ($attempt = 1; $attempt -le 3; $attempt++) {
        Write-Host "aqtinstall attempt $attempt of 3"
        & "$pythonRoot\python.exe" @aqtArguments

        if (($LASTEXITCODE -eq 0) -and (Test-Path "$qtDest\bin\qmake.exe")) {
            $qtInstalled = $true
            break
        }

        Write-Warning "Qt installation attempt $attempt failed with exit code $LASTEXITCODE"
        if ($attempt -lt 3) {
            Start-Sleep -Seconds 15
        }
    }

    if (-not $qtInstalled) {
        throw "Qt installation failed. Expected: $qtDest\bin\qmake.exe"
    }

    Write-Host "Installed Qt to $qtDest"
}

# 10. jom
$jomVersion = "1_1_7"
$jomZip = "$Downloads\jom_$jomVersion.zip"
$jomUrl = "https://download.qt.io/official_releases/jom/jom_$jomVersion.zip"
$jomDest = "C:\Qt\Tools\QtCreator\bin\jom"

if (Test-Path "$jomDest\jom.exe") {
    Write-Host "jom already installed at $jomDest; skipping."
} else {
    Download-File $jomUrl $jomZip

    New-Item -ItemType Directory -Force $jomDest | Out-Null
    Expand-Archive -Path $jomZip -DestinationPath $jomDest -Force

    if (!(Test-Path "$jomDest\jom.exe")) {
        throw "jom extraction completed, but jom.exe was not found at $jomDest"
    }

    Write-Host "Installed jom to $jomDest"
}

Add-SystemPath $jomDest

# =============================================================================
# Toolchain Versions
#
# The versions below are intentionally pinned to match the validated OpenRV
# CY2025 Windows build environment. Where possible, they correspond to either:
#
#   • Versions required by the OpenRV build documentation.
#   • Versions used in the reference Windows development environment.
#   • Versions successfully validated by this Docker build.
#
# These values are not automatically updated to the latest available releases.
# Pinning them helps ensure reproducible builds and avoids unexpected changes
# caused by newer toolchain versions. Update only after verifying that OpenRV
# builds successfully with the newer versions.
# =============================================================================

# 11. Environment
Add-SystemPath "C:\Program Files\CMake\bin"
Add-SystemPath "C:\Program Files\Python311"
Add-SystemPath "C:\Users\$env:USERNAME\.cargo\bin"
Add-SystemPath "C:\msys64\mingw64\bin"
Add-SystemPath "C:\Strawberry\perl\bin"
# Add-SystemPath "C:\Strawberry\c\bin"
Add-SystemPath "C:\msys64\usr\bin"
Add-SystemPath "C:\Qt\6.5.3\msvc2019_64\bin"
Add-SystemPath "C:\Program Files\Git\cmd"

[Environment]::SetEnvironmentVariable("QT_HOME", "C:\Qt\6.5.3\msvc2019_64", "Machine")
[Environment]::SetEnvironmentVariable("CMAKE_PREFIX_PATH", "C:\Qt\6.5.3\msvc2019_64", "Machine")
[Environment]::SetEnvironmentVariable("ACLOCAL_PATH", "C:\msys64\usr\share\aclocal", "Machine")

# 12. Generate MSYS2 bash profile
$msysUser = $env:USERNAME
$msysHome = "C:\msys64\home\$msysUser"
New-Item -ItemType Directory -Force $msysHome | Out-Null

$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"

$vsInstallPath = & $vswhere `
    -latest `
    -products * `
    -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
    -property installationPath

if (!$vsInstallPath) {
    throw "Could not find Visual Studio install path with VC tools"
}

$msvcRoot = Join-Path $vsInstallPath "VC\Tools\MSVC"
Write-Host "Using VS install path: $vsInstallPath"
Write-Host "Using MSVC root: $msvcRoot"

$msvc1440 = Get-ChildItem $msvcRoot -Directory |
    Where-Object { $_.Name -like "14.40*" } |
    Sort-Object Name -Descending |
    Select-Object -First 1

if (!$msvc1440) {
    throw "Could not find MSVC 14.40 toolset under $msvcRoot"
}

function Convert-ToMsysPath($WinPath) {
    $p = $WinPath -replace '\\','/'
    $p = $p -replace '^([A-Za-z]):','/$1'
    return $p.ToLower()
}

$msysVsPath = Convert-ToMsysPath $vsInstallPath
$winSdk = "10.0.26100.0"

$profile = @"
export QT_HOME=/c/Qt/6.5.3/msvc2019_64
export CMAKE_PREFIX_PATH=/c/Qt/6.5.3/msvc2019_64
export ACLOCAL_PATH=/c/msys64/usr/share/aclocal

export PATH="/c/Program Files/CMake/bin:/c/Program Files/Python311:/c/Users/$msysUser/.cargo/bin:/c/msys64/mingw64/bin:/usr/bin:/c/Strawberry/perl/bin:`$QT_HOME/bin:`$PATH"

export PATH="$msysVsPath/VC/Tools/MSVC/$($msvc1440.Name)/bin/HostX64/x64:`$PATH"

export LIB="$msysVsPath/VC/Tools/MSVC/$($msvc1440.Name)/lib/x64:/c/Program Files (x86)/Windows Kits/10/Lib/$winSdk/ucrt/x64:/c/Program Files (x86)/Windows Kits/10/Lib/$winSdk/um/x64"

export INCLUDE="$msysVsPath/VC/Tools/MSVC/$($msvc1440.Name)/include:/c/Program Files (x86)/Windows Kits/10/Include/$winSdk/ucrt:/c/Program Files (x86)/Windows Kits/10/Include/$winSdk/um:/c/Program Files (x86)/Windows Kits/10/Include/$winSdk/shared"
"@

Set-Content -Path "$msysHome\.bash_profile" -Value $profile -Encoding ASCII
Write-Host "Wrote MSYS2 profile: $msysHome\.bash_profile"

# 13. Verify
Write-Host "=== Verification ==="
& "C:\Program Files\CMake\bin\cmake.exe" --version
& "C:\Program Files\Python311\python.exe" --version
& "C:\Strawberry\perl\bin\perl.exe" -v
& "$env:USERPROFILE\.cargo\bin\rustc.exe" --version
& C:\msys64\usr\bin\bash.exe -lc "pacman -Qeq | wc -l"
& "C:\Program Files\Git\cmd\git.exe" --version
& C:\msys64\usr\bin\bash.exe -lc "source ~/.bash_profile; which patch; patch --version | head -1"
& "C:\Qt\Tools\QtCreator\bin\jom\jom.exe" /VERSION

if (Test-Path "C:\Qt\6.5.3\msvc2019_64\bin\qmake.exe") {
    & "C:\Qt\6.5.3\msvc2019_64\bin\qmake.exe" --version
} else {
    Write-Warning "Qt not installed yet: C:\Qt\6.5.3\msvc2019_64 missing"
}

Stop-Transcript

