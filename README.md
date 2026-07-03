# Media Intake One Tool

One Windows drag-and-drop tool for preparing lecture, call, and screen-recording media.

Drop one or more media files onto `Media_Intake_One_Tool.bat`. For each input, it creates a dated output folder under `F:\Lecture` by default.

## What It Makes

- `name.mp3` - normal MP3 audio for easy playback and sharing.
- `name__16k_mono.flac` - normalized 16 kHz mono audio for transcription tools such as Whisper, Gemini, or Colab notebooks.
- `name.mp4` - clean H.264/AAC MP4 video, useful for `.ts`, `.mkv`, `.mov`, and other less convenient video files.
- `ffmpeg_run.log` - a log file for troubleshooting.

If an MP3 is larger than 199 MB, the tool also creates smaller MP3 parts in an `mp3_parts` folder.

## Requirements

Install FFmpeg and make sure `ffmpeg.exe` and `ffprobe.exe` are available in your Windows PATH.

You can also place `ffmpeg.exe` and `ffprobe.exe` in the same folder as the BAT file.

## Settings

Open the BAT file in a text editor and change the settings at the top if needed:

- `OUT_ROOT=F:\Lecture`
- `MAKE_MP3=1`
- `MAKE_TRANSCRIBER_FLAC=1`
- `MAKE_CLEAN_MP4=1`
- `SPLIT_VIDEO_CHUNKS=0`
- `CHUNK_MINUTES=15`

Set a value to `0` to turn that output off.

## Why MP3 + FLAC?

MP3 is the convenient format for listening and sharing. FLAC at 16 kHz mono is better for transcription workflows because it keeps speech clean while reducing file size.
