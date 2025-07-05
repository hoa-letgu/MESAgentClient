@echo off
setlocal enabledelayedexpansion

:: === INPUT DATA ===
:RETRY
set /p FACTORY=Enter factory name: 
set /p LINE=Enter line name: 

:: Get local IP address
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4 Address"') do (
    set "IP=%%a"
    goto :breakIP
)
:breakIP
set "IP=%IP: =%"

:: Send to server
curl -s -X POST http://10.30.3.50:6677/addLines ^
  -H "Content-Type: application/json" ^
  -d "{\"plant_id\":\"%FACTORY%\",\"line\":\"%LINE%\",\"ip\":\"%IP%\"}" > "%TEMP%\response.json"

:: Check response
findstr /C:"OK" "%TEMP%\response.json" >nul
if %errorlevel%==0 (
    echo Successfully added!
    del "%TEMP%\response.json" >nul 2>&1
) else (
    echo Failed to add or already exists.
    type "%TEMP%\response.json"
    del "%TEMP%\response.json" >nul 2>&1
    goto RETRY
)

:: === COPY FILES AFTER SUCCESSFUL ADDITION ===

set "DEST=%USERPROFILE%\Documents\mesAgentMonitor"

echo.
echo ==== Proceeding with copy after successful addition ====
if not exist "%DEST%" (
    mkdir "%DEST%"
    echo Created folder: %DEST%
) else (
    echo Folder already exists: %DEST%
)

echo Copying files...
xcopy /E /I /Y "node_modules" "%DEST%\node_modules" >nul
copy /Y "app.js" "%DEST%\" >nul
copy /Y "delete.cmd" "%DEST%\" >nul
copy /Y "package.json" "%DEST%\" >nul
copy /Y "run.cmd" "%DEST%\" >nul
copy /Y "run.vbs" "%DEST%\" >nul
copy /Y "install.cmd" "%DEST%\" >nul

echo Adding to Startup folder...
copy /Y "run.vbs" "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\run.vbs" >nul

if exist "%DEST%\app.js" if exist "%DEST%\run.vbs" (
    echo Copy successful, running run.vbs...
    start "" "%DEST%\run.vbs"
) else (
    echo Error copying files. run.vbs not executed.
)

echo.
echo Installation complete. This window will close in 3 seconds...
timeout /t 3 /nobreak >nul
exit /b
