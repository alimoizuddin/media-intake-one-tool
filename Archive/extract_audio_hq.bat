@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ============================================================
REM  prep_for_colab_transcriber.bat
REM  Matches your Colab preprocessing:
REM    - mono (-ac 1)
REM    - 16kHz (-ar 16000)
REM    - loudnorm=I=-16:TP=-1.5:LRA=11
REM
REM  Default: FLAC (lossless, smaller upload)
REM  Optional:
REM    /wav  -> WAV 16k mono (bigger)
REM    /copy -> bit-perfect stream copy (archive, not optimized for upload)
REM
REM  Usage:
REM    Drag & drop one or more files onto this .bat
REM    OR:
REM      prep_for_colab_transcriber.bat "video.mp4"
REM      prep_for_colab_transcriber.bat /wav "video.mp4"
REM      prep_for_colab_transcriber.bat /copy "video.mp4"
REM ============================================================

where ffmpeg >nul 2>nul
if errorlevel 1 (
  echo [ERROR] ffmpeg not found. Install FFmpeg and add to PATH,
  echo         or place ffmpeg.exe next to this .bat.
  pause
  exit /b 1
)

set "MODE=FLAC"
if /I "%~1"=="/wav"  ( set "MODE=WAV"  & shift )
if /I "%~1"=="/flac" ( set "MODE=FLAC" & shift )
if /I "%~1"=="/copy" ( set "MODE=COPY" & shift )

if "%~1"=="" (
  echo Drag ^& drop media files onto this .bat
  echo OR: %~nx0 [/flac ^| /wav ^| /copy] "file1" "file2" ...
  pause
  exit /b 0
)

set "OUTDIR=%~dp0Colab_Input_Ready"
if not exist "%OUTDIR%" mkdir "%OUTDIR%"

:LOOP
if "%~1"=="" goto :DONE
call :ONE "%~1"
shift
goto :LOOP

:ONE
set "IN=%~1"
if not exist "!IN!" (
  echo [SKIP] Not found: "!IN!"
  goto :eof
)

set "BASE=%~n1"

REM ---- Default: FLAC 16k mono + loudnorm (matches Colab) ----
if /I "!MODE!"=="FLAC" (
  set "OUT=%OUTDIR%\!BASE!__16k_mono.flac"
  echo [FLAC] "!IN!" ^> "!OUT!"
  ffmpeg -hide_banner -loglevel error -y ^
    -i "!IN!" -vn -map 0:a:0 ^
    -ac 1 -ar 16000 ^
    -af "loudnorm=I=-16:TP=-1.5:LRA=11" ^
    -c:a flac -compression_level 12 ^
    "!OUT!"
  if errorlevel 1 echo [ERROR] Failed on: "!IN!"
  goto :eof
)

REM ---- WAV 16k mono + loudnorm (bigger files) ----
if /I "!MODE!"=="WAV" (
  set "OUT=%OUTDIR%\!BASE!__16k_mono.wav"
  echo [WAV ] "!IN!" ^> "!OUT!"
  ffmpeg -hide_banner -loglevel error -y ^
    -i "!IN!" -vn -map 0:a:0 ^
    -ac 1 -ar 16000 ^
    -af "loudnorm=I=-16:TP=-1.5:LRA=11" ^
    -c:a pcm_s16le ^
    "!OUT!"
  if errorlevel 1 echo [ERROR] Failed on: "!IN!"
  goto :eof
)

REM ---- COPY (archive / “true highest quality” but not optimized) ----
if /I "!MODE!"=="COPY" (
  set "OUT=%OUTDIR%\!BASE!.mka"
  echo [COPY] "!IN!" ^> "!OUT!"
  ffmpeg -hide_banner -loglevel error -y ^
    -i "!IN!" -vn -map 0:a:0 -c:a copy ^
    "!OUT!"
  if errorlevel 1 echo [ERROR] Failed on: "!IN!"
  goto :eof
)

goto :eof

:DONE
echo.
echo Done. Put these into your Google Drive folder:
echo   MyDrive/Colab/Input
echo Output folder:
echo   "%OUTDIR%"
echo.
pause
endlocal
exit /b 0
