@echo off
rem Double-click to play the first toy. WASD or arrows walk, Shift runs, E uses, mouse wheel zooms.
set "GODOT_EXE=%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64.exe"
if defined GODOT set "GODOT_EXE=%GODOT%"
if exist "%GODOT_EXE%" goto run
echo Godot 4.7.2 was not found at:
echo   %GODOT_EXE%
echo Install it with:  winget install GodotEngine.GodotEngine
echo (or set the GODOT environment variable to your Godot .exe)
pause
exit /b 1
:run
rem The "." after %~dp0 stops the folder's last backslash from swallowing the closing quote.
start "" "%GODOT_EXE%" --path "%~dp0."
