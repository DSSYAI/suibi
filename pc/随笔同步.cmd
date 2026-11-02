@echo off
chcp 65001 >nul
cd /d "%~dp0"
where python >nul 2>nul
if errorlevel 1 (
  echo Python not found.
  pause
  exit /b 1
)
python -X utf8 sync_server.py %*
if errorlevel 1 pause
