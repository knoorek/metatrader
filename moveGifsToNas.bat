@echo off
set "WATCH_DIR=c:\Users\kpach\AppData\Roaming\MetaQuotes\Terminal\47AEB69EDDAD4D73097816C71FB25856\MQL5\Files"
set "TARGET_DIR=\\DS1525\common\public\forex"
set "NTFY_URL=http://ntfy.sh/..."
set "FILE_NAME=signals.txt"

:petla
dir /b /a-d "%WATCH_DIR%\*.gif" > %FILE_NAME%
for %%A in ("%FILE_NAME%") do (
    if %%~zA GTR 0 (
        echo [%time%] Moving files...
	move %WATCH_DIR%\*.gif %TARGET_DIR%
	curl -T %FILE_NAME% %NTFY_URL%
    ) else (
        echo No signals.
    )
)
echo Waiting 60 seconds...
timeout /t 60 /nobreak >nul
goto petla