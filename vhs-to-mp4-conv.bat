@echo off
setlocal enabledelayedexpansion


:: ============================================
:: CONFIG
:: ============================================
set "SRC=C:\Tapes"
set "DEST=C:\Converted_Tapes"




echo.
echo === AVI -^> MP4 Conversion (HW Acc) ===
echo SRC:     %SRC%
echo DEST: %DEST%
echo.

if not exist "%DEST%" mkdir "%DEST%"

set count=0
set errors=0

for /r "%SRC%" %%F in (*.avi) do (
    set "fullpath=%%F"
    set "relpath=!fullpath:%SRC%=!"
    set "outpath=%DEST%!relpath!"
    set "outpath=!outpath:.avi=.mp4!"
    set "outdir=!outpath!"

    for %%D in ("!outpath!") do set "outdir=%%~dpD"
    if not exist "!outdir!" mkdir "!outdir!" >nul 2>&1

    if exist "!outpath!" (
        echo [SKIPPED - already exists] %%~nxF
    ) else (
        echo [CONVERT] %%~nxF
        ffmpeg -y -i "%%F" -vf "yadif=0:-1:0" -c:v h264_amf -quality quality -rc cqp -qp_i 20 -qp_p 22 -c:a aac -b:a 160k -movflags +faststart -pix_fmt yuv420p "!outpath!" -loglevel fatal -stats 2>"!outpath!.log"
        if !errorlevel! neq 0 (
            echo    ERROR converting %%~nxF - see "!outpath!.log"
            set /a errors+=1
        ) else (
            del "!outpath!.log" >nul 2>&1
            set /a count+=1
        )
    )
)

echo.
echo === Done ===
echo Converted files: !count!
echo Errors: !errors!
echo.
pause
