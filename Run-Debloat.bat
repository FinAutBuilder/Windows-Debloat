@echo off
:: Double-click to open Vanjix Debloat.
:: It asks for administrator rights; nothing changes until you press Apply.
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Vanjix-Debloat.ps1" %*
