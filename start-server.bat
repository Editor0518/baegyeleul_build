@echo off
setlocal

set "SCRIPT=%~dp0tools\static-server.ps1"
if not exist "%SCRIPT%" (
  echo Server script not found: %SCRIPT%
  exit /b 1
)

set "PORT=8000"

rem Prefer Next.js export folder
set "ROOT=%~dp0visual-novel\out"
if not exist "%ROOT%" (
  rem Fallbacks
  set "ROOT=%~dp0out"
)
if not exist "%ROOT%" (
  set "ROOT=%~dp0visual-novel-out"
)

if not exist "%ROOT%" (
  echo Build output not found.
  echo Tried: 
  echo   %~dp0visual-novel\out
  echo   %~dp0out
  echo   %~dp0visual-novel-out
  echo Please run: npm run build  (or npm run build:package)
  exit /b 1
)

echo Serving root: %ROOT%
start "Static Server" powershell -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%" -Port %PORT% -RootPath "%ROOT%" -SpaFallback

rem Wait briefly for server to start
timeout /t 2 /nobreak >nul
start "" http://localhost:%PORT%/
echo Opened: http://localhost:%PORT%/

endlocal
