@echo off
setlocal
set "GODOT_EXE=D:\Softwares\Godot_v4.7.2-GD\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT_EXE%" (
    echo Godot executable not found at "%GODOT_EXE%"
    pause
    exit /b 1
)
start "" "%GODOT_EXE%" --path "%~dp0." -w --resolution 1280x720
