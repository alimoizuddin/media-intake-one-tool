# Audio Extractor 3.0

A Windows drag and drop FFmpeg utility for turning lecture video into usable audio without uploads, subscriptions, or manual file splitting.

## What it creates

1. An MP3 for listening and NotebookLM. The default is mono at 96 kbps, so a three hour lecture is typically about 130 MB and stays below NotebookLM's 200 MB source limit.
2. A 16 kHz mono FLAC, loudness normalised for transcription workflows.
3. An optional bit perfect copy of the source audio.

The original media is read only. Every output goes into its own dated folder.

## Setup

1. Put `Audio_Extractor.bat` anywhere on your computer.
2. Install FFmpeg and make sure both `ffmpeg.exe` and `ffprobe.exe` are on `PATH`, or place both files beside the batch script.
3. Drag one or more video or audio files onto `Audio_Extractor.bat`.

Run `Audio_Extractor.bat /?` from a command prompt for optional settings.

## Why it exists

A paid cloud converter added about 75 minutes of turnaround to a three hour lecture through upload, conversion, download, and manual splitting. Audio Extractor performs the work locally in about 40 seconds for the documented lecture size. It also keeps source material on the machine.

At the documented volume of 30 lectures a month, that removes an estimated 460 hours of annual pipeline turnaround. This is turnaround time, not active labour.

## Project files

`Audio_Extractor.bat` is the current tool.

`Audio_Extractor_Guide.pdf` is the beginner guide.

`Audio_Extractor_STAR_PAR.txt` records the measured project account.

`Archive` contains the earlier Media Intake versions and supporting material.
