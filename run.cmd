@echo off
setlocal

:: Đường dẫn
set "DEST=%USERPROFILE%\Documents\mesAgentMonitor"
set "ZIP_PATH=%TEMP%\update.zip"

:: Tạo thư mục nếu chưa có
mkdir "%DEST%" >nul 2>&1

:: Tải file zip
curl -s -o "%ZIP_PATH%" http://10.30.3.50:6677/update

:: Tạo VBS giải nén và tự động ghi đè
echo Set objShell = CreateObject("Shell.Application") > %TEMP%\unzip.vbs
echo Set src = objShell.NameSpace("%ZIP_PATH%") >> %TEMP%\unzip.vbs
echo Set dest = objShell.NameSpace("%DEST%") >> %TEMP%\unzip.vbs
echo dest.CopyHere src.Items, 1044 >> %TEMP%\unzip.vbs

:: Chạy giải nén
cscript //nologo %TEMP%\unzip.vbs

:: Dọn file tạm
del /f /q %TEMP%\unzip.vbs
del /f /q "%ZIP_PATH%"

:: Chạy ứng dụng (chạy nền)
start "" /b cmd /c "cd /d %DEST% && node app.js"

:: Đợi vài giây để đảm bảo app.js đã khởi chạy (nếu cần)
ping -n 3 127.0.0.1 >nul

:: Xoá thư mục update nếu có
rd /s /q "%DEST%\update"

exit /b
