@echo off
set "TARGET_DIR=\\DS1525\common\public\forex"

:petla
move ping %TARGET_DIR%
echo Waiting 60 seconds...
timeout /t 60 /nobreak >nul
goto petla