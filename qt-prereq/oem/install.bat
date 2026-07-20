@echo off
setlocal

set "LOG=C:\OEM\install-qt.log"

echo ================================================== >> "%LOG%"
echo Qt prerequisite setup started: %DATE% %TIME% >> "%LOG%"
echo ================================================== >> "%LOG%"

powershell.exe ^
  -NoLogo ^
  -NoProfile ^
  -ExecutionPolicy Bypass ^
  -File "C:\OEM\install-qt.ps1" >> "%LOG%" 2>&1

set "RESULT=%ERRORLEVEL%"

if not "%RESULT%"=="0" (
    echo ERROR: install-qt.ps1 returned exit code %RESULT%. >> "%LOG%"
    exit /b %RESULT%
)

echo Qt prerequisite setup completed: %DATE% %TIME% >> "%LOG%"
exit /b 0

