@echo off
setlocal enabledelayedexpansion

echo ========================================
echo DEBUG: Starting Environment Setup
echo ========================================

:: Check if Intel folder exists
if not exist "C:\Program Files (x86)\Intel\oneAPI\" (
    echo ERROR: Intel oneAPI directory not found!
    dir "C:\Program Files (x86)\"
    exit /b 1
)

echo DEBUG: Calling setvars-vcvarsall...
call "C:\Program Files (x86)\Intel\oneAPI\setvars-vcvarsall.bat" %VS_VER%

echo DEBUG: Searching for compiler version...
for /f "tokens=* usebackq" %%f in (`dir /b "C:\Program Files (x86)\Intel\oneAPI\compiler\" ^| findstr /V latest ^| sort`) do @set "LATEST_VERSION=%%f"

echo DEBUG: Found Version: %LATEST_VERSION%

if not exist "C:\Program Files (x86)\Intel\oneAPI\compiler\%LATEST_VERSION%\env\vars.bat" (
    echo ERROR: vars.bat not found at expected path!
    exit /b 1
)

@call "C:\Program Files (x86)\Intel\oneAPI\compiler\%LATEST_VERSION%\env\vars.bat"

echo DEBUG: Modifying Git Version script...
powershell -command "(Get-Content -Path '.\vs-build\CreateGitVersion.bat') -replace '--dirty', '' | Set-Content -Path '.\vs-build\CreateGitVersion.bat'"

:: Initialize variables
set "FailedSolutions="
set "OverallErrorLevel=0"

echo ========================================
echo DEBUG: Starting Compilation
echo ========================================

:: Helper function style block for builds
echo Building: Release^|x64
devenv vs-build/OpenFAST.sln /Build "Release|x64"
if %ERRORLEVEL% NEQ 0 (
    set "FailedSolutions=!FailedSolutions! Release"
    set "OverallErrorLevel=1"
    echo [!] Release Build Failed
)

echo Building: Debug^|x64
devenv vs-build/OpenFAST.sln /Build "Debug|x64"
if %ERRORLEVEL% NEQ 0 (
    set "FailedSolutions=!FailedSolutions! Debug"
    set "OverallErrorLevel=1"
    echo [!] Debug Build Failed
)

echo ========================================
echo DEBUG: Post-Build File Operations
echo ========================================

if not exist "build\bin" mkdir build\bin
cd /d build\bin || (echo ERROR: Could not enter build\bin && exit /b 1)

echo DEBUG: Current directory is: %CD%
echo DEBUG: Files before rename:
dir /b

:: Renaming logic
for %%F in (*_Release*) do (
    set "name=%%~nxF"
    set "newname=!name:_Release=!"
    if not "!name!"=="!newname!" ren "%%F" "!newname!"
)

echo DEBUG: Final file list:
dir

echo ========================================
if %OverallErrorLevel% EQU 0 (
    echo BUILD SUCCESSFUL
) else (
    echo BUILD FAILED in following configs: %FailedSolutions%
)
echo ========================================

exit /b %OverallErrorLevel%