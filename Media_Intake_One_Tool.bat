@echo off
setlocal EnableExtensions EnableDelayedExpansion

title Media Intake One Tool

REM ============================================================
REM  Media Intake One Tool
REM  Drag and drop one or more video/audio files onto this BAT.
REM
REM  Default outputs per input:
REM    - MP3 audio for easy sharing/playback
REM    - 16k mono FLAC audio for transcription/Colab/Whisper/Gemini
REM    - Clean MP4 video for TS/MKV/MOV/odd video sources
REM
REM  Requirements:
REM    - ffmpeg.exe and ffprobe.exe available in PATH
REM      OR placed in the same folder as this BAT file.
REM ============================================================

REM ---------------- USER SETTINGS ----------------
set "OUT_ROOT=F:\Lecture"
set "MAKE_MP3=1"
set "MAKE_TRANSCRIBER_FLAC=1"
set "MAKE_CLEAN_MP4=1"

REM Set to 1 if you also want a bit-perfect audio archive (.mka).
set "MAKE_AUDIO_COPY=0"

REM Set to 1 if you want the clean MP4 split into chunks too.
set "SPLIT_VIDEO_CHUNKS=0"
set "CHUNK_MINUTES=15"

REM MP3 output. 192k is a good balance for speech and compatibility.
set "MP3_BITRATE=192k"
set "MP3_BITRATE_BPS=192000"

REM If MP3 is larger than this, the script also makes split MP3 parts.
set "MAX_MP3_MB=199"
set "SPLIT_SAFETY_PERCENT=95"

REM Transcription audio settings.
set "TRANSCRIBER_SAMPLE_RATE=16000"
set "LOUDNORM=loudnorm=I=-16:TP=-1.5:LRA=11"

REM Clean MP4 settings.
set "VIDEO_CRF=22"
set "VIDEO_PRESET=veryfast"
set "AAC_BITRATE=160k"
REM ------------------------------------------------

call :UseBundledToolsIfPresent
call :CheckTools || goto :END
call :PrepareOutputRoot || goto :END

for /f %%D in ('powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd"') do set "TODAY=%%D"

if "%~1"=="" (
  echo.
  echo Drag and drop one or more media files onto this BAT file.
  echo.
  echo Or paste one full file path below.
  echo.
  set /p "ONE_FILE=File path: "
  set "ONE_FILE=!ONE_FILE:"=!"
  if "!ONE_FILE!"=="" goto :END
  call :ProcessOne "!ONE_FILE!"
  goto :DONE
)

:ARG_LOOP
if "%~1"=="" goto :DONE
call :ProcessOne "%~1"
shift
goto :ARG_LOOP

:ProcessOne
set "INFILE=%~1"
set "INFILE=!INFILE:"=!"

if not exist "!INFILE!" (
  echo.
  echo [SKIP] File not found:
  echo   "!INFILE!"
  exit /b 0
)

for %%F in ("!INFILE!") do (
  set "FULLPATH=%%~fF"
  set "BASE=%%~nF"
)

set "OUT_DIR=!OUT_ROOT!\!TODAY!\!BASE!"
if not exist "!OUT_DIR!" mkdir "!OUT_DIR!" >nul 2>nul

set "LOG=!OUT_DIR!\ffmpeg_run.log"
> "!LOG!" (
  echo Media Intake One Tool
  echo Run: %DATE% %TIME%
  echo Input: "!FULLPATH!"
  echo Output: "!OUT_DIR!"
  echo.
)

set "HAS_AUDIO=0"
for /f "usebackq delims=" %%A in (`ffprobe -v error -select_streams a:0 -show_entries stream^=index -of csv^=p^=0 "!FULLPATH!" 2^>nul`) do set "HAS_AUDIO=1"

set "HAS_VIDEO=0"
for /f "usebackq delims=" %%V in (`ffprobe -v error -select_streams v:0 -show_entries stream^=index -of csv^=p^=0 "!FULLPATH!" 2^>nul`) do set "HAS_VIDEO=1"

echo.
echo ============================================================
echo Input:
echo   "!FULLPATH!"
echo Output folder:
echo   "!OUT_DIR!"
echo ============================================================

if "!HAS_AUDIO!"=="0" (
  echo [WARN] No audio stream found. Audio outputs will be skipped.
) else (
  if "%MAKE_MP3%"=="1" call :MakeMP3
  if "%MAKE_TRANSCRIBER_FLAC%"=="1" call :MakeTranscriberFLAC
  if "%MAKE_AUDIO_COPY%"=="1" call :MakeAudioCopy
)

if "!HAS_VIDEO!"=="0" (
  echo [INFO] No video stream found. MP4 conversion will be skipped.
) else (
  if "%MAKE_CLEAN_MP4%"=="1" call :MakeCleanMP4
)

echo.
echo [DONE] Finished:
echo   "!BASE!"
echo.
exit /b 0

:MakeMP3
set "MP3_OUT=!OUT_DIR!\!BASE!.mp3"
echo.
echo [1] Creating MP3 audio...
>> "!LOG!" echo [mp3] "!MP3_OUT!"

ffmpeg -hide_banner -loglevel warning -stats -y -i "!FULLPATH!" ^
  -map 0:a:0 -vn -sn -dn ^
  -ac 2 -ar 44100 -c:a libmp3lame -b:a %MP3_BITRATE% ^
  "!MP3_OUT!" >> "!LOG!" 2>&1

if errorlevel 1 (
  echo [WARN] MP3 creation failed. See log.
  >> "!LOG!" echo ExitCode_mp3=!ERRORLEVEL!
  exit /b 0
)

echo [OK] MP3 saved.
call :SplitMP3IfNeeded "!MP3_OUT!"
exit /b 0

:MakeTranscriberFLAC
set "FLAC_OUT=!OUT_DIR!\!BASE!__16k_mono.flac"
echo.
echo [2] Creating transcription-ready FLAC...
>> "!LOG!" echo [transcriber_flac] "!FLAC_OUT!"

ffmpeg -hide_banner -loglevel warning -stats -y -i "!FULLPATH!" ^
  -map 0:a:0 -vn -sn -dn ^
  -ac 1 -ar %TRANSCRIBER_SAMPLE_RATE% -af "%LOUDNORM%" ^
  -c:a flac -compression_level 12 ^
  "!FLAC_OUT!" >> "!LOG!" 2>&1

if errorlevel 1 (
  echo [WARN] FLAC creation failed. See log.
  >> "!LOG!" echo ExitCode_transcriber_flac=!ERRORLEVEL!
  exit /b 0
)

echo [OK] Transcription FLAC saved.
exit /b 0

:MakeAudioCopy
set "COPY_OUT=!OUT_DIR!\!BASE!__audio_copy.mka"
echo.
echo [3] Creating bit-perfect audio copy...
>> "!LOG!" echo [audio_copy] "!COPY_OUT!"

ffmpeg -hide_banner -loglevel warning -stats -y -i "!FULLPATH!" ^
  -map 0:a:0 -vn -sn -dn -c:a copy ^
  "!COPY_OUT!" >> "!LOG!" 2>&1

if errorlevel 1 (
  echo [WARN] Audio copy failed. See log.
  >> "!LOG!" echo ExitCode_audio_copy=!ERRORLEVEL!
  exit /b 0
)

echo [OK] Audio copy saved.
exit /b 0

:MakeCleanMP4
set "MP4_OUT=!OUT_DIR!\!BASE!.mp4"
echo.
echo [4] Creating clean MP4 video...
>> "!LOG!" echo [clean_mp4] "!MP4_OUT!"

if "!HAS_AUDIO!"=="1" (
  ffmpeg -hide_banner -loglevel warning -stats -y -i "!FULLPATH!" ^
    -map 0:v:0 -map 0:a:0 -sn -dn ^
    -c:v libx264 -preset %VIDEO_PRESET% -crf %VIDEO_CRF% -pix_fmt yuv420p ^
    -c:a aac -b:a %AAC_BITRATE% ^
    -movflags +faststart ^
    "!MP4_OUT!" >> "!LOG!" 2>&1
) else (
  ffmpeg -hide_banner -loglevel warning -stats -y -i "!FULLPATH!" ^
    -map 0:v:0 -sn -dn ^
    -c:v libx264 -preset %VIDEO_PRESET% -crf %VIDEO_CRF% -pix_fmt yuv420p ^
    -movflags +faststart ^
    "!MP4_OUT!" >> "!LOG!" 2>&1
)

if errorlevel 1 (
  echo [WARN] Clean MP4 conversion failed. See log.
  >> "!LOG!" echo ExitCode_clean_mp4=!ERRORLEVEL!
  exit /b 0
)

echo [OK] Clean MP4 saved.

if "%SPLIT_VIDEO_CHUNKS%"=="1" call :SplitCleanMP4 "!MP4_OUT!"
exit /b 0

:SplitMP3IfNeeded
set "MP3_FILE=%~1"
for %%A in ("!MP3_FILE!") do set "MP3_SIZE=%%~zA"
if not defined MP3_SIZE set "MP3_SIZE=0"
set /a "MAX_BYTES=MAX_MP3_MB*1024*1024"
set "MP3_TOO_BIG=0"
if !MP3_SIZE! GTR !MAX_BYTES! set "MP3_TOO_BIG=1"

if "!MP3_TOO_BIG!"=="0" (
  echo [OK] MP3 is under %MAX_MP3_MB% MB. No MP3 split needed.
  exit /b 0
)

set /a "MAX_BITS=MAX_MP3_MB*1024*1024*8"
set /a "SAFE_BITS=MAX_BITS*SPLIT_SAFETY_PERCENT/100"
set /a "SEGMENT_SECONDS=SAFE_BITS/MP3_BITRATE_BPS"
if !SEGMENT_SECONDS! LSS 60 set "SEGMENT_SECONDS=60"

set "MP3_PARTS_DIR=!OUT_DIR!\mp3_parts"
if not exist "!MP3_PARTS_DIR!" mkdir "!MP3_PARTS_DIR!" >nul 2>nul

echo [INFO] MP3 is over %MAX_MP3_MB% MB. Creating smaller MP3 parts...
>> "!LOG!" echo [mp3_split] segment_seconds=!SEGMENT_SECONDS!

ffmpeg -hide_banner -loglevel warning -stats -y -i "!MP3_FILE!" ^
  -f segment -segment_time !SEGMENT_SECONDS! -c copy ^
  "!MP3_PARTS_DIR!\!BASE!_mp3_part_%%03d.mp3" >> "!LOG!" 2>&1

if errorlevel 1 (
  echo [WARN] MP3 split failed. The full MP3 was kept.
  >> "!LOG!" echo ExitCode_mp3_split=!ERRORLEVEL!
) else (
  echo [OK] MP3 parts saved.
)

exit /b 0

:SplitCleanMP4
set "MP4_FILE=%~1"
set /a "CHUNK_SECONDS=%CHUNK_MINUTES%*60"
set "CHUNK_DIR=!OUT_DIR!\mp4_parts"
if not exist "!CHUNK_DIR!" mkdir "!CHUNK_DIR!" >nul 2>nul

echo [INFO] Splitting clean MP4 into %CHUNK_MINUTES%-minute parts...
>> "!LOG!" echo [mp4_split] chunk_seconds=!CHUNK_SECONDS!

ffmpeg -hide_banner -loglevel warning -stats -y -i "!MP4_FILE!" ^
  -c copy -f segment -segment_time !CHUNK_SECONDS! -reset_timestamps 1 ^
  "!CHUNK_DIR!\!BASE!_part_%%03d.mp4" >> "!LOG!" 2>&1

if errorlevel 1 (
  echo [WARN] MP4 split failed. The full MP4 was kept.
  >> "!LOG!" echo ExitCode_mp4_split=!ERRORLEVEL!
) else (
  echo [OK] MP4 parts saved.
)

exit /b 0

:UseBundledToolsIfPresent
set "SCRIPT_DIR=%~dp0"
if exist "%SCRIPT_DIR%ffmpeg.exe" set "PATH=%SCRIPT_DIR%;%PATH%"
exit /b 0

:CheckTools
where ffmpeg >nul 2>nul
if errorlevel 1 (
  echo [ERROR] ffmpeg was not found.
  echo Install FFmpeg and add it to PATH, or place ffmpeg.exe next to this BAT.
  exit /b 1
)

where ffprobe >nul 2>nul
if errorlevel 1 (
  echo [ERROR] ffprobe was not found.
  echo Install FFmpeg and add it to PATH, or place ffprobe.exe next to this BAT.
  exit /b 1
)

exit /b 0

:PrepareOutputRoot
if not exist "%OUT_ROOT%\" mkdir "%OUT_ROOT%" >nul 2>nul

set "WRITE_TEST=%OUT_ROOT%\__write_test_%RANDOM%.tmp"
> "%WRITE_TEST%" echo ok

if exist "%WRITE_TEST%" (
  del "%WRITE_TEST%" >nul 2>nul
  exit /b 0
)

echo [WARN] Cannot write to "%OUT_ROOT%".
echo [WARN] Using a folder next to this BAT file instead.
set "OUT_ROOT=%~dp0Lecture_Output"
if not exist "%OUT_ROOT%\" mkdir "%OUT_ROOT%" >nul 2>nul

set "WRITE_TEST=%OUT_ROOT%\__write_test_%RANDOM%.tmp"
> "%WRITE_TEST%" echo ok
if exist "%WRITE_TEST%" (
  del "%WRITE_TEST%" >nul 2>nul
  exit /b 0
)

echo [ERROR] Could not create an output folder.
exit /b 1

:DONE
echo.
echo ============================================================
echo All tasks completed.
echo Output root:
echo   "%OUT_ROOT%"
echo ============================================================

:END
echo.
pause
endlocal
