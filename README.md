## Quickstart (Windows, No Install)

- Open the folder and double-click `start-server.bat`.
- It opens a PowerShell window serving `visual-novel-out` at `http://localhost:8000/`.
- Stop by closing the PowerShell window or pressing `Ctrl + C` in that window.

### Alternative: Run in terminal

```powershell
cd C:\Users\USER\Documents\GitHub\baegyeleul_build
./start-server.bat
# then open http://localhost:8000/
```

### Notes
- Uses a lightweight PowerShell server (`tools/static-server.ps1`), no extra installs.
- Supports SPA fallback for client-side routes.
- Change port by editing `start-server.bat` (`set PORT=8000`).
