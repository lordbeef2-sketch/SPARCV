@echo off
setlocal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install-SparcLeon-VxWorks6.9.ps1"
exit /b %errorlevel%
