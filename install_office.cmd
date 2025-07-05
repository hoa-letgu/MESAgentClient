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

:: Gửi thông tin lên server
curl -s -X POST http://10.30.3.50:6677/addLines2 ^
  -H "Content-Type: application/json" ^
  -d "{\"plant_id\":\"%FACTORY%\",\"line\":\"%LINE%\",\"ip\":\"%IP%\"}" > "%TEMP%\response.json"

:: Kiểm tra phản hồi
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

:: === DOWNLOAD & EXTRACT ZIP FILE ===

set "DEST=%USERPROFILE%\Documents\mesAgentMonitor"
set "ZIP_PATH=%TEMP%\update_src.zip"
set "UNZIP_VBS=%TEMP%\unzip.vbs"

echo.
echo ==== Downloading and extracting files ====

:: Tạo thư mục nếu chưa có
mkdir "%DEST%" >nul 2>&1

:: Tải file ZIP từ server
curl -s -o "%ZIP_PATH%" http://10.30.3.50:6677/update_src

:: Tạo file VBS để giải nén
echo Set objShell = CreateObject("Shell.Application") > "%UNZIP_VBS%"
echo Set src = objShell.NameSpace("%ZIP_PATH%") >> "%UNZIP_VBS%"
echo Set dest = objShell.NameSpace("%DEST%") >> "%UNZIP_VBS%"
echo If Not src Is Nothing And Not dest Is Nothing Then >> "%UNZIP_VBS%"
echo     dest.CopyHere src.Items, 1044 >> "%UNZIP_VBS%"
echo End If >> "%UNZIP_VBS%"

:: === GIẢI NÉN ===
cscript //nologo "%UNZIP_VBS%"

:: Xoá file tạm
del /f /q "%UNZIP_VBS%"
del /f /q "%ZIP_PATH%"

:: === CHỜ FILE GIẢI NÉN XUẤT HIỆN (TỐI ĐA ~10 GIÂY) ===
set WAIT_COUNT=0
:WAIT_EXTRACT
if exist "%DEST%\app.js" if exist "%DEST%\run.vbs" (
    goto :CONTINUE_INSTALL
)
set /a WAIT_COUNT+=1
if !WAIT_COUNT! GEQ 10 (
    echo ❌ Timeout: Files not found after extraction.
    echo Please check the downloaded ZIP contents.
    pause
    exit /b 1
)
timeout /t 1 >nul
goto :WAIT_EXTRACT

:CONTINUE_INSTALL
echo ✅ Extraction successful.

echo Adding to Startup...
copy /Y "%DEST%\run.vbs" "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\run.vbs" >nul

echo Starting application...
start "" "wscript.exe" "%DEST%\run.vbs"

echo.
echo ✅ Installation complete. This window will close in 3 seconds...
timeout /t 3 /nobreak >nul
exit /b
