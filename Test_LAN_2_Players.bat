@echo off
setlocal
set "GODOT_EXE=D:\Softwares\Godot_v4.7.2-GD\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT_EXE%" (
    echo Godot executable not found at "%GODOT_EXE%"
    pause
    exit /b 1
)
start "Player 1 (Host)" "%GODOT_EXE%" --path "%~dp0." -w --resolution 900x520 --position 20,60
timeout /t 1 /nobreak >nul
start "Player 2 (Client)" "%GODOT_EXE%" --path "%~dp0." -w --resolution 900x520 --position 950,60 -- --profile=p2
