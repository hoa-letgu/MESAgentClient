@echo off
echo -------------------------------
echo Checking and deleting run.vbs...
echo -------------------------------

set "STARTUP=%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup"
set "RUNVBS=%STARTUP%\run.vbs"

if exist "%RUNVBS%" (
    del "%RUNVBS%"
    echo Deleted: %RUNVBS%
) else (
    echo Not found: %RUNVBS%
)

echo.
echo -------------------------------
echo Finding and stopping related node.js processes...
echo -------------------------------

:: Stop all node processes related to app.js
for /f "tokens=2 delims=," %%i in ('tasklist /FI "IMAGENAME eq node.exe" /FO CSV /NH') do (
    for /f "tokens=*" %%j in ('wmic process where "ProcessId=%%i AND CommandLine like '%%app.js%%'" get ProcessId /value 2^>nul') do (
        echo Killing PID: %%i
        taskkill /F /PID %%i >nul 2>&1
    )
)

echo -------------------------------
echo Deleting mesAgentMonitor folder...
echo -------------------------------

set "SYSAPP=%USERPROFILE%\Documents\mesAgentMonitor"

if exist "%SYSAPP%" (
    rd /S /Q "%SYSAPP%"
    echo Deleted folder: %SYSAPP%
) else (
    echo Directory not found: %SYSAPP%
)



echo Done checking and stopping node processes related to app.js
echo.
echo This window will close automatically in 3 seconds...
timeout /t 3 /nobreak >nul
exit
