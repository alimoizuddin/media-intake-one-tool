@echo off
setlocal enabledelayedexpansion

echo =========================================
echo        AUDIO EXTRACTOR - GOD MODE
echo =========================================

if "%~1"=="" (
    echo Drag and drop one or more video files onto this script.
    pause
    exit /b
)

:: SETTINGS
set MAXMB=199
set SAFETY_FACTOR=95

:PROCESS_LOOP
if "%~1"=="" goto END

set INPUT=%~1
set NAME=%~n1

echo.
echo =========================================
echo Processing: %NAME%
echo =========================================

:: STEP 1 — Detect codec
for /f "tokens=2 delims==" %%a in ('ffprobe -v error -select_streams a:0 -show_entries stream^=codec_name -of default^=noprint_wrappers^=1 "%INPUT%"') do (
    set CODEC=%%a
)

:: Default container
set EXT=m4a

if /i "%CODEC%"=="mp3" set EXT=mp3
if /i "%CODEC%"=="opus" set EXT=opus
if /i "%CODEC%"=="vorbis" set EXT=ogg
if /i "%CODEC%"=="flac" set EXT=flac

echo Detected codec: %CODEC%
echo Using extension: %EXT%

:: STEP 2 — Extract audio
ffmpeg -y -i "%INPUT%" -vn -c:a copy "%NAME%.%EXT%"

if not exist "%NAME%.%EXT%" (
    echo ❌ Extraction failed. Skipping...
    shift
    goto PROCESS_LOOP
)

:: STEP 3 — Get file size
for %%A in ("%NAME%.%EXT%") do set SIZE=%%~zA
set /a SIZEMB=%SIZE%/1024/1024

echo File size: %SIZEMB% MB

if %SIZEMB% LEQ %MAXMB% (
    echo ✅ No split needed.
    shift
    goto PROCESS_LOOP
)

echo ⚠️ Splitting required...

:: STEP 4 — Get bitrate
for /f "tokens=2 delims==" %%a in ('ffprobe -v error -select_streams a:0 -show_entries stream^=bit_rate -of default^=noprint_wrappers^=1 "%NAME%.%EXT%"') do (
    set BITRATE=%%a
)

if not defined BITRATE (
    echo ⚠️ Bitrate detection failed. Using fallback 128000
    set BITRATE=128000
)

echo Bitrate: %BITRATE% bps

:: STEP 5 — Calculate safe segment duration
set /a MAXBITS=%MAXMB%*1024*1024*8
set /a SAFE_BITS=%MAXBITS%*%SAFETY_FACTOR%/100
set /a SEGMENT_TIME=%SAFE_BITS% / %BITRATE%

echo Safe segment duration: %SEGMENT_TIME% sec

:: STEP 6 — Split
ffmpeg -y -i "%NAME%.%EXT%" -f segment -segment_time %SEGMENT_TIME% -c copy "%NAME%_Part_%%03d.%EXT%"

echo 🧹 Removing original large file...
del "%NAME%.%EXT%"

echo ✅ Done with %NAME%
echo.

shift
goto PROCESS_LOOP

:END
echo =========================================
echo 🎉 ALL TASKS COMPLETED
echo =========================================
pause