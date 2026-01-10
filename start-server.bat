@echo off
setlocal
set SCRIPT=%~dp0tools\static-server.ps1
if not exist "%SCRIPT%" (
  echo Server script not found: %SCRIPT%
  exit /b 1
)
set PORT=8000
set ROOT=%~dp0visual-novel-out
start "Static Server" powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -Port %PORT% -RootPath "%ROOT%" -SpaFallback
rem Wait briefly for server to start
timeout /t 2 /nobreak >nul
start "" http://localhost:%PORT%/
echo Opened: http://localhost:%PORT%/
endlocal
