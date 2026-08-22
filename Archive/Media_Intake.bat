@echo off
setlocal EnableExtensions EnableDelayedExpansion

title Media Intake

REM ============================================================
REM  Media Intake  v2.0
REM  Replaces: audio extractor.bat, extract_audio_hq.bat,
REM            Media_Intake_One_Tool.bat
REM
REM  Usage:
REM    Drag and drop one or more media files onto this BAT.
REM    Or from a console:
REM      Media_Intake.bat [options] "file1" "file2" ...
REM    Run  Media_Intake.bat /?  for the option list.
REM
REM  Requires ffmpeg.exe and ffprobe.exe in PATH, or sitting in
REM  the same folder as this BAT file.
REM ============================================================

set "TOOL_NAME=Media Intake"
set "TOOL_VERSION=2.0"
set "EXITCODE=0"

REM ---------------- USER SETTINGS (defaults) ----------------
REM Anything here can be overridden per run by a switch. See /?.

REM Where finished files go. Falls back to a folder next to this
REM BAT if the drive is missing or not writable.
set "OUT_ROOT=F:\Lecture"

REM Which outputs to produce for each input file.
set "MAKE_MP3=1"
set "MAKE_TRANSCRIBE=1"
set "MAKE_CLEAN_MP4=1"
set "MAKE_AUDIO_ARCHIVE=0"

REM Transcription audio: flac (lossless, smaller) or wav (bigger).
set "TRANSCRIBE_FORMAT=flac"
set "TRANSCRIBE_RATE=16000"
set "LOUDNORM=loudnorm=I=-16:TP=-1.5:LRA=11"

REM Shareable MP3.
set "MP3_BITRATE_K=192"
set "MP3_CHANNELS=2"
set "MP3_RATE=44100"

REM If the MP3 goes over MAX_PART_MB, split copies are also written
REM into an mp3_parts subfolder. The full MP3 is always kept.
set "MAX_PART_MB=199"
set "SPLIT_SAFETY_PERCENT=95"

REM Clean MP4 re-encode.
set "VIDEO_CRF=22"
set "VIDEO_PRESET=veryfast"
set "AAC_BITRATE=160k"

REM Optional time based split of the clean MP4.
set "SPLIT_VIDEO=0"
set "CHUNK_MINUTES=15"

REM Keep the window open at the end. Drag and drop needs this.
set "DO_PAUSE=1"
REM ------------------------------------------------

REM ---------------- Command line ----------------
:PARSE
if "%~1"=="" goto :PARSED
if /I "%~1"=="/?"         goto :HELP
if /I "%~1"=="/h"         goto :HELP
if /I "%~1"=="/help"      goto :HELP
if /I "%~1"=="/out"       ( set "OUT_ROOT=%~2" & shift & shift & goto :PARSE )
if /I "%~1"=="/mp3"       ( set "MAKE_MP3=1" & shift & goto :PARSE )
if /I "%~1"=="/nomp3"     ( set "MAKE_MP3=0" & shift & goto :PARSE )
if /I "%~1"=="/flac"      ( set "MAKE_TRANSCRIBE=1" & set "TRANSCRIBE_FORMAT=flac" & shift & goto :PARSE )
if /I "%~1"=="/wav"       ( set "MAKE_TRANSCRIBE=1" & set "TRANSCRIBE_FORMAT=wav" & shift & goto :PARSE )
if /I "%~1"=="/notext"    ( set "MAKE_TRANSCRIBE=0" & shift & goto :PARSE )
if /I "%~1"=="/mp4"       ( set "MAKE_CLEAN_MP4=1" & shift & goto :PARSE )
if /I "%~1"=="/nomp4"     ( set "MAKE_CLEAN_MP4=0" & shift & goto :PARSE )
if /I "%~1"=="/audioonly" ( set "MAKE_CLEAN_MP4=0" & shift & goto :PARSE )
if /I "%~1"=="/copy"      ( set "MAKE_AUDIO_ARCHIVE=1" & shift & goto :PARSE )
if /I "%~1"=="/split"     ( set "SPLIT_VIDEO=1" & shift & goto :PARSE )
if /I "%~1"=="/chunk"     ( set "CHUNK_MINUTES=%~2" & set "SPLIT_VIDEO=1" & shift & shift & goto :PARSE )
if /I "%~1"=="/maxmb"     ( set "MAX_PART_MB=%~2" & shift & shift & goto :PARSE )
if /I "%~1"=="/nopause"   ( set "DO_PAUSE=0" & shift & goto :PARSE )
set "ARG=%~1"
if "!ARG:~0,1!"=="/" goto :BADOPT
goto :PARSED

:BADOPT
echo.
echo [ERROR] Unknown option: %~1
echo         Run "%~nx0 /?" for the option list.
set "EXITCODE=2"
goto :END

:HELP
echo.
echo %TOOL_NAME% %TOOL_VERSION%
echo.
echo   %~nx0 [options] "file1" "file2" ...
echo   Or drag and drop media files onto the BAT.
echo.
echo Per input file, into OUT_ROOT\yyyy-mm-dd\filename\ :
echo   name.mp3                shareable audio          (on)
echo   name__16k_mono.flac     transcription audio      (on)
echo   name.mp4                clean re-encoded video   (on)
echo   name__audio_copy.EXT    bit-perfect audio        (off)
echo   ffmpeg_run.log          what ran, and exit codes
echo.
echo Options:
echo   /out "D:\Path"      output root for this run
echo   /nomp3              skip the MP3
echo   /flac  /wav         transcription format, default flac
echo   /notext             skip the transcription audio
echo   /nomp4  /audioonly  skip the clean MP4
echo   /copy               also write a bit-perfect audio archive
echo   /split              split the clean MP4 into chunks
echo   /chunk N            chunk length in minutes, implies /split
echo   /maxmb N            MP3 size limit before parts are made
echo   /nopause            do not wait for a keypress at the end
echo   /?                  this help
echo.
echo Exit codes: 0 all good, 1 something failed or was skipped,
echo             2 bad setup or bad options.
echo.
goto :END

:PARSED
call :ValidateSettings
if errorlevel 1 ( set "EXITCODE=2" & goto :END )

call :UseBundledToolsIfPresent
call :CheckTools
if errorlevel 1 ( set "EXITCODE=2" & goto :END )

call :ResolveToday

call :PrepareOutputRoot
if errorlevel 1 ( set "EXITCODE=2" & goto :END )

REM ---- Derived values ----
set "MP3_BITRATE=%MP3_BITRATE_K%k"
set /a "MP3_BPS=MP3_BITRATE_K*1000"
set /a "MAX_PART_BYTES=MAX_PART_MB*1024*1024"
REM Divide first. bytes*8*95 overflows the 32-bit range of set /a and
REM silently returns a junk duration, which is what made the original
REM splitter produce wrong sized parts.
set /a "SEGMENT_SECONDS=MAX_PART_BYTES/MP3_BPS*8*SPLIT_SAFETY_PERCENT/100"
if %SEGMENT_SECONDS% LSS 60 set "SEGMENT_SECONDS=60"

set /a "TOTAL=0, OK_COUNT=0, FAIL_COUNT=0, SKIP_COUNT=0"

echo.
echo ============================================================
echo %TOOL_NAME% %TOOL_VERSION%
echo Output root: "%OUT_ROOT%"
echo ============================================================

if not "%~1"=="" goto :ARG_LOOP

REM No files supplied. Accept one pasted path.
echo.
echo Drag and drop one or more media files onto this BAT file,
echo or paste one full file path below.
echo.
set "ONE_FILE="
set /p "ONE_FILE=File path: "
if not defined ONE_FILE goto :SUMMARY
set "ONE_FILE=%ONE_FILE:"=%"
set /a "TOTAL+=1"
call :ProcessOne "%ONE_FILE%"
call :Tally %ERRORLEVEL%
goto :SUMMARY

:ARG_LOOP
if "%~1"=="" goto :SUMMARY
set /a "TOTAL+=1"
call :ProcessOne "%~1"
call :Tally %ERRORLEVEL%
shift
goto :ARG_LOOP

:Tally
if "%~1"=="0" ( set /a "OK_COUNT+=1" & exit /b 0 )
if "%~1"=="2" ( set /a "SKIP_COUNT+=1" & exit /b 0 )
set /a "FAIL_COUNT+=1"
exit /b 0

REM ============================================================
REM  Per file processing
REM  Returns 0 = every requested output made
REM          1 = at least one output failed
REM          2 = input skipped
REM ============================================================
:ProcessOne
REM Delayed expansion is off while the argument is read so that
REM file names containing "!" survive intact.
setlocal DisableDelayedExpansion
set "FULLPATH=%~f1"
set "BASE=%~n1"
setlocal EnableDelayedExpansion

if exist "!FULLPATH!\" (
  echo.
  echo [SKIP] That is a folder, not a media file:
  echo        "!FULLPATH!"
  exit /b 2
)

if not exist "!FULLPATH!" (
  echo.
  echo [SKIP] File not found:
  echo        "!FULLPATH!"
  exit /b 2
)

echo.
echo ============================================================
echo Input:  "!FULLPATH!"

set "OUT_DIR=!OUT_ROOT!\!TODAY!\!BASE!"
if not exist "!OUT_DIR!\" mkdir "!OUT_DIR!" >nul 2>nul
if not exist "!OUT_DIR!\" (
  echo [FAIL] Could not create the output folder:
  echo        "!OUT_DIR!"
  exit /b 1
)
echo Output: "!OUT_DIR!"
echo ============================================================

set "LOG=!OUT_DIR!\ffmpeg_run.log"
> "!LOG!" (
  echo %TOOL_NAME% %TOOL_VERSION%
  echo Run:    %DATE% %TIME%
  echo Input:  "!FULLPATH!"
  echo Output: "!OUT_DIR!"
  echo.
)

set "FILE_ERRORS=0"

set "HAS_AUDIO=0"
for /f "usebackq delims=" %%A in (`ffprobe -v error -select_streams a:0 -show_entries stream^=index -of csv^=p^=0 "!FULLPATH!" 2^>nul`) do set "HAS_AUDIO=1"

set "HAS_VIDEO=0"
for /f "usebackq delims=" %%V in (`ffprobe -v error -select_streams v:0 -show_entries stream^=index -of csv^=p^=0 "!FULLPATH!" 2^>nul`) do set "HAS_VIDEO=1"

>> "!LOG!" echo has_audio=!HAS_AUDIO! has_video=!HAS_VIDEO!

if "!HAS_AUDIO!!HAS_VIDEO!"=="00" (
  echo [FAIL] No audio or video stream found. Unsupported file?
  >> "!LOG!" echo No decodable streams found.
  exit /b 1
)

if "!HAS_AUDIO!"=="0" echo [INFO] No audio stream. Audio outputs skipped.
if "!HAS_AUDIO!"=="1" if "!MAKE_MP3!"=="1"           call :MakeMP3
if "!HAS_AUDIO!"=="1" if "!MAKE_TRANSCRIBE!"=="1"    call :MakeTranscribeAudio
if "!HAS_AUDIO!"=="1" if "!MAKE_AUDIO_ARCHIVE!"=="1" call :MakeAudioArchive

if "!HAS_VIDEO!"=="0" echo [INFO] No video stream. MP4 conversion skipped.
if "!HAS_VIDEO!"=="1" if "!MAKE_CLEAN_MP4!"=="1"     call :MakeCleanMP4

echo.
if "!FILE_ERRORS!"=="0" (
  echo [DONE] !BASE!
  exit /b 0
)
echo [DONE WITH ERRORS] !BASE!
exit /b 1

REM ---------------- Output builders ----------------

:MakeMP3
set "MP3_OUT=!OUT_DIR!\!BASE!.mp3"
echo.
echo [1] MP3 audio...
>> "!LOG!" echo [mp3] "!MP3_OUT!" bitrate=%MP3_BITRATE%

ffmpeg -hide_banner -nostdin -loglevel warning -stats -y -i "!FULLPATH!" ^
  -map 0:a:0 -vn -sn -dn ^
  -ac %MP3_CHANNELS% -ar %MP3_RATE% ^
  -c:a libmp3lame -b:a %MP3_BITRATE% -id3v2_version 3 ^
  "!MP3_OUT!"
set "RC=!ERRORLEVEL!"
>> "!LOG!" echo exit_mp3=!RC!

if not "!RC!"=="0" (
  echo     [FAIL] MP3 creation failed. See the messages above.
  set "FILE_ERRORS=1"
  exit /b 0
)

echo     [OK] !BASE!.mp3
call :SplitMP3IfNeeded "!MP3_OUT!"
exit /b 0

:MakeTranscribeAudio
set "TR_OUT=!OUT_DIR!\!BASE!__16k_mono.flac"
set "TR_CODEC=-c:a flac -compression_level 12"
if /I "!TRANSCRIBE_FORMAT!"=="wav" set "TR_OUT=!OUT_DIR!\!BASE!__16k_mono.wav"
if /I "!TRANSCRIBE_FORMAT!"=="wav" set "TR_CODEC=-c:a pcm_s16le"

echo.
echo [2] Transcription audio: mono, %TRANSCRIBE_RATE% Hz, loudness normalised...
>> "!LOG!" echo [transcribe] "!TR_OUT!"

ffmpeg -hide_banner -nostdin -loglevel warning -stats -y -i "!FULLPATH!" ^
  -map 0:a:0 -vn -sn -dn ^
  -ac 1 -ar %TRANSCRIBE_RATE% -af "%LOUDNORM%" ^
  !TR_CODEC! ^
  "!TR_OUT!"
set "RC=!ERRORLEVEL!"
>> "!LOG!" echo exit_transcribe=!RC!

if not "!RC!"=="0" (
  echo     [FAIL] Transcription audio failed. See the messages above.
  set "FILE_ERRORS=1"
  exit /b 0
)

for %%F in ("!TR_OUT!") do echo     [OK] %%~nxF
exit /b 0

:MakeAudioArchive
REM Stream copy into a container that can actually hold the codec.
set "SRC_CODEC="
for /f "usebackq tokens=2 delims==" %%C in (`ffprobe -v error -select_streams a:0 -show_entries stream^=codec_name -of default^=noprint_wrappers^=1 "!FULLPATH!" 2^>nul`) do set "SRC_CODEC=%%C"
if not defined SRC_CODEC set "SRC_CODEC=unknown"

set "ARC_EXT=mka"
if /I "!SRC_CODEC!"=="aac"    set "ARC_EXT=m4a"
if /I "!SRC_CODEC!"=="alac"   set "ARC_EXT=m4a"
if /I "!SRC_CODEC!"=="mp3"    set "ARC_EXT=mp3"
if /I "!SRC_CODEC!"=="opus"   set "ARC_EXT=opus"
if /I "!SRC_CODEC!"=="vorbis" set "ARC_EXT=ogg"
if /I "!SRC_CODEC!"=="flac"   set "ARC_EXT=flac"
if /I "!SRC_CODEC!"=="ac3"    set "ARC_EXT=ac3"

echo.
echo [3] Bit-perfect audio copy, source codec !SRC_CODEC!...
>> "!LOG!" echo [audio_copy] codec=!SRC_CODEC! ext=!ARC_EXT!

set "ARC_OUT=!OUT_DIR!\!BASE!__audio_copy.!ARC_EXT!"
call :RunAudioCopy
if "!RC!"=="0" goto :ArchiveOK
if /I "!ARC_EXT!"=="mka" goto :ArchiveFail

echo     [INFO] .!ARC_EXT! could not hold that stream. Retrying as .mka...
set "ARC_OUT=!OUT_DIR!\!BASE!__audio_copy.mka"
call :RunAudioCopy
if "!RC!"=="0" goto :ArchiveOK

:ArchiveFail
echo     [FAIL] Audio copy failed. See the messages above.
set "FILE_ERRORS=1"
exit /b 0

:ArchiveOK
for %%F in ("!ARC_OUT!") do echo     [OK] %%~nxF
exit /b 0

:RunAudioCopy
ffmpeg -hide_banner -nostdin -loglevel warning -stats -y -i "!FULLPATH!" ^
  -map 0:a:0 -vn -sn -dn -c:a copy ^
  "!ARC_OUT!"
set "RC=!ERRORLEVEL!"
>> "!LOG!" echo exit_audio_copy=!RC! file="!ARC_OUT!"
exit /b 0

:MakeCleanMP4
set "MP4_OUT=!OUT_DIR!\!BASE!.mp4"
set "MP4_AUDIO=-map 0:a:0 -c:a aac -b:a %AAC_BITRATE%"
if "!HAS_AUDIO!"=="0" set "MP4_AUDIO="

echo.
echo [4] Clean MP4 video...
>> "!LOG!" echo [clean_mp4] "!MP4_OUT!" crf=%VIDEO_CRF% preset=%VIDEO_PRESET%

ffmpeg -hide_banner -nostdin -loglevel warning -stats -y -i "!FULLPATH!" ^
  -map 0:v:0 !MP4_AUDIO! -sn -dn ^
  -c:v libx264 -preset %VIDEO_PRESET% -crf %VIDEO_CRF% -pix_fmt yuv420p ^
  -movflags +faststart ^
  "!MP4_OUT!"
set "RC=!ERRORLEVEL!"
>> "!LOG!" echo exit_clean_mp4=!RC!

if not "!RC!"=="0" (
  echo     [FAIL] Clean MP4 conversion failed. See the messages above.
  set "FILE_ERRORS=1"
  exit /b 0
)

echo     [OK] !BASE!.mp4
if "!SPLIT_VIDEO!"=="1" call :SplitCleanMP4 "!MP4_OUT!"
exit /b 0

REM ---------------- Splitting ----------------

:SplitMP3IfNeeded
set "MP3_FILE=%~1"
set "MP3_SIZE=0"
for %%A in ("!MP3_FILE!") do set "MP3_SIZE=%%~zA"

REM A 10 digit byte count is at least 1 GB, which is past the range
REM where cmd's numeric IF can be trusted. Treat it as oversized.
set "MP3_TOO_BIG=0"
if not "!MP3_SIZE:~9,1!"=="" set "MP3_TOO_BIG=1"
if "!MP3_TOO_BIG!"=="0" if !MP3_SIZE! GTR !MAX_PART_BYTES! set "MP3_TOO_BIG=1"

if "!MP3_TOO_BIG!"=="0" (
  echo     [OK] MP3 is under !MAX_PART_MB! MB. No split needed.
  exit /b 0
)

set "MP3_PARTS_DIR=!OUT_DIR!\mp3_parts"
if not exist "!MP3_PARTS_DIR!\" mkdir "!MP3_PARTS_DIR!" >nul 2>nul

echo     [INFO] MP3 is over !MAX_PART_MB! MB. Writing parts of !SEGMENT_SECONDS! sec...
>> "!LOG!" echo [mp3_split] size=!MP3_SIZE! segment_seconds=!SEGMENT_SECONDS!

ffmpeg -hide_banner -nostdin -loglevel warning -stats -y -i "!MP3_FILE!" ^
  -f segment -segment_time !SEGMENT_SECONDS! -reset_timestamps 1 -c copy ^
  "!MP3_PARTS_DIR!\!BASE!_part_%%03d.mp3"
set "RC=!ERRORLEVEL!"
>> "!LOG!" echo exit_mp3_split=!RC!

if not "!RC!"=="0" (
  echo     [WARN] MP3 split failed. The full MP3 was kept.
  exit /b 0
)

echo     [OK] MP3 parts in mp3_parts
exit /b 0

:SplitCleanMP4
set "MP4_FILE=%~1"
set /a "CHUNK_SECONDS=CHUNK_MINUTES*60"
set "CHUNK_DIR=!OUT_DIR!\mp4_parts"
if not exist "!CHUNK_DIR!\" mkdir "!CHUNK_DIR!" >nul 2>nul

echo     [INFO] Splitting the MP4 into !CHUNK_MINUTES! minute parts...
>> "!LOG!" echo [mp4_split] chunk_seconds=!CHUNK_SECONDS!

ffmpeg -hide_banner -nostdin -loglevel warning -stats -y -i "!MP4_FILE!" ^
  -c copy -f segment -segment_time !CHUNK_SECONDS! -reset_timestamps 1 ^
  "!CHUNK_DIR!\!BASE!_part_%%03d.mp4"
set "RC=!ERRORLEVEL!"
>> "!LOG!" echo exit_mp4_split=!RC!

if not "!RC!"=="0" (
  echo     [WARN] MP4 split failed. The full MP4 was kept.
  exit /b 0
)

echo     [OK] MP4 parts in mp4_parts
exit /b 0

REM ---------------- Setup helpers ----------------

:ValidateSettings
if not defined OUT_ROOT (
  echo [ERROR] /out was given without a path.
  exit /b 1
)
call :IsPlainNumber "%CHUNK_MINUTES%"
if errorlevel 1 (
  echo [ERROR] /chunk needs a whole number of minutes, no leading zeros.
  exit /b 1
)
call :IsPlainNumber "%MAX_PART_MB%"
if errorlevel 1 (
  echo [ERROR] /maxmb needs a whole number of megabytes, no leading zeros.
  exit /b 1
)
if %CHUNK_MINUTES% LSS 1 (
  echo [ERROR] /chunk must be 1 or more.
  exit /b 1
)
if %MAX_PART_MB% LSS 1 (
  echo [ERROR] /maxmb must be 1 or more.
  exit /b 1
)
if %MAX_PART_MB% GTR 900 (
  echo [ERROR] /maxmb must be 900 or less.
  exit /b 1
)
exit /b 0

:IsPlainNumber
REM Digits only, and no leading zero, because set /a reads 08 as octal.
set "N=%~1"
if not defined N exit /b 1
for /f "delims=0123456789" %%X in ("!N!") do exit /b 1
if "!N!"=="0" exit /b 0
if "!N:~0,1!"=="0" exit /b 1
exit /b 0

:UseBundledToolsIfPresent
if exist "%~dp0ffmpeg.exe" set "PATH=%~dp0;%PATH%"
exit /b 0

:CheckTools
where ffmpeg >nul 2>nul
if errorlevel 1 (
  echo [ERROR] ffmpeg was not found.
  echo         Install FFmpeg and add it to PATH, or put ffmpeg.exe
  echo         next to this BAT file.
  exit /b 1
)
where ffprobe >nul 2>nul
if errorlevel 1 (
  echo [ERROR] ffprobe was not found.
  echo         It ships with FFmpeg. Put ffprobe.exe beside ffmpeg.exe.
  exit /b 1
)
exit /b 0

:ResolveToday
set "TODAY="
for /f "usebackq delims=" %%D in (`powershell -NoProfile -Command "Get-Date -Format yyyy-MM-dd" 2^>nul`) do set "TODAY=%%D"
if defined TODAY exit /b 0
REM Fallback when PowerShell is unavailable. Folder name then follows
REM the machine locale instead of yyyy-mm-dd.
set "TODAY=%DATE%"
set "TODAY=!TODAY:/=-!"
set "TODAY=!TODAY:\=-!"
set "TODAY=!TODAY::=-!"
set "TODAY=!TODAY: =_!"
if not defined TODAY set "TODAY=undated"
exit /b 0

:PrepareOutputRoot
call :TryOutputRoot "%OUT_ROOT%"
if not errorlevel 1 exit /b 0

echo [WARN] Cannot write to "%OUT_ROOT%".
echo [WARN] Using a folder next to this BAT file instead.
set "OUT_ROOT=%~dp0Media_Intake_Output"
call :TryOutputRoot "%OUT_ROOT%"
if not errorlevel 1 exit /b 0

echo [ERROR] Could not create a writable output folder.
exit /b 1

:TryOutputRoot
set "CANDIDATE=%~1"
if not exist "!CANDIDATE!\" mkdir "!CANDIDATE!" >nul 2>nul
if not exist "!CANDIDATE!\" exit /b 1
set "WRITE_TEST=!CANDIDATE!\__write_test_%RANDOM%.tmp"
( > "!WRITE_TEST!" echo ok ) 2>nul
if not exist "!WRITE_TEST!" exit /b 1
del "!WRITE_TEST!" >nul 2>nul
exit /b 0

REM ---------------- Wrap up ----------------

:SUMMARY
echo.
echo ============================================================
echo Finished.  files: !TOTAL!   ok: !OK_COUNT!   failed: !FAIL_COUNT!   skipped: !SKIP_COUNT!
echo Output root:
echo   "%OUT_ROOT%"
echo ============================================================

if not "!FAIL_COUNT!"=="0" set "EXITCODE=1"
if not "!SKIP_COUNT!"=="0" set "EXITCODE=1"

:END
if "%DO_PAUSE%"=="1" (
  echo.
  pause
)
endlocal & exit /b %EXITCODE%
