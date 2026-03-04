@echo off
setlocal EnableExtensions

set "TARGET_DIR=%~1"
set "SOURCE_DIR=%~2"
set "EXE_NAME=%~3"
set "SOURCE_NAME=%~nx2"
set "EXIT_CODE=1"

if "%TARGET_DIR%"=="" goto cleanup
if "%SOURCE_DIR%"=="" goto cleanup
if "%EXE_NAME%"=="" goto cleanup
if not exist "%TARGET_DIR%" goto cleanup
if not exist "%SOURCE_DIR%" goto cleanup

>nul 2>&1 timeout /t 2 /nobreak

for /d %%D in ("%TARGET_DIR%\*") do (
  if /I not "%%~nxD"=="%SOURCE_NAME%" rd /s /q "%%~fD" >nul 2>&1
)

for %%F in ("%TARGET_DIR%\*") do (
  if /I not "%%~nxF"=="%SOURCE_NAME%" del /f /q "%%~fF" >nul 2>&1
)

xcopy "%SOURCE_DIR%\*" "%TARGET_DIR%\" /E /H /I /Y >nul
if errorlevel 1 goto cleanup

rd /s /q "%SOURCE_DIR%" >nul 2>&1

start "" "%TARGET_DIR%\%EXE_NAME%"
if errorlevel 1 goto cleanup

set "EXIT_CODE=0"

:cleanup
del "%~f0" >nul 2>&1
exit /b %EXIT_CODE%
