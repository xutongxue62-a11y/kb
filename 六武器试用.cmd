@echo off
setlocal
cd /d "%~dp0"
set "APPDATA=%~dp0runtime"
set "LOCALAPPDATA=%~dp0runtime\local"
if not exist "%APPDATA%" mkdir "%APPDATA%"
if not exist "%LOCALAPPDATA%" mkdir "%LOCALAPPDATA%"
start "" "%~dp0tools\godot\Godot_v4.7.2-stable_win64.exe" --path "%~dp0." --log-file "%~dp0logs\trial.log" -- --trial
