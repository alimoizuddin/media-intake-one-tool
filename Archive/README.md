# Media Intake 2.0

One drag-and-drop tool that replaces `audio extractor.bat`, `extract_audio_hq.bat`, and
`Media_Intake_One_Tool.bat`. Everything those three did is here, plus fixes for the bugs
they shared.

## Install

1. Put `Media_Intake.bat` anywhere you like.
2. Make sure `ffmpeg.exe` **and** `ffprobe.exe` are on PATH, or drop both next to the BAT
   (the script puts its own folder on PATH first when it finds `ffmpeg.exe` there).
3. Open the BAT in a text editor and check `OUT_ROOT` near the top. It is `F:\Lecture`,
   same as before. If that drive is missing or read-only, the script falls back to
   `Media_Intake_Output` beside the BAT and tells you so.

## Use

Drag one or more video/audio files onto the BAT. Or from a console:

```
Media_Intake.bat "lecture1.mp4" "lecture2.mkv"
Media_Intake.bat /audioonly /wav "podcast.ts"
Media_Intake.bat /out "D:\Archive" /copy /chunk 10 "seminar.mov"
```

Running it with no arguments prompts for one pasted path.

## Output layout

```
OUT_ROOT\2026-08-22\lecture1\
    lecture1.mp3                 shareable audio, 192 kbps
    lecture1__16k_mono.flac      mono 16 kHz + loudnorm, for Whisper/Colab/Gemini
    lecture1.mp4                 clean H.264 + AAC, faststart
    ffmpeg_run.log               what ran, and the exit code of each step
    mp3_parts\                   only if the MP3 exceeded the size cap
    mp4_parts\                   only with /split
```

## Options

| Switch | Effect |
|---|---|
| `/out "D:\Path"` | output root for this run |
| `/nomp3` | skip the MP3 |
| `/flac` `/wav` | transcription format (default `flac`) |
| `/notext` | skip the transcription audio |
| `/nomp4` `/audioonly` | skip the clean MP4 |
| `/copy` | also write a bit-perfect audio archive |
| `/split` | split the clean MP4 into chunks |
| `/chunk N` | chunk length in minutes (implies `/split`) |
| `/maxmb N` | MP3 size cap before parts are made (default 199, max 900) |
| `/nopause` | do not wait for a keypress — use this when calling from another script |
| `/?` | help |

Exit codes: `0` everything succeeded, `1` something failed or was skipped, `2` bad setup
or bad switches. Combined with `/nopause`, this is safe to call from Task Scheduler or a
wrapper script.

## What was fixed from the originals

1. **Split duration was computed wrong.** `SAFE_BITS=MAX_BITS*95/100` overflows cmd's
   32-bit `set /a`: for a 199 MB cap it returns **-3,271,558**, so `-segment_time` got a
   negative value. Present in both `audio extractor.bat` and `Media_Intake_One_Tool.bat`.
   Now the division happens first, and every intermediate stays in range for any allowed
   `/maxmb` and bitrate.
2. **No `-nostdin`.** ffmpeg consumed the console's stdin, so when several files were
   dropped at once later ones could stall or be skipped. All ffmpeg calls now pass it.
3. **`ExitCode=!ERRORLEVEL!` always logged 0** — the `echo` on the preceding line had
   already reset it. Errorlevel is now captured immediately after each ffmpeg call.
4. **Fixed `.m4a` for stream copy.** Only AAC/ALAC actually fit there. The archive output
   now probes the source codec, picks a matching container (`m4a`, `mp3`, `opus`, `ogg`,
   `flac`, `ac3`), and retries into `.mka` if the first container rejects the stream.
5. **`audio extractor.bat` wrote to the current directory**, which for drag-and-drop is
   usually `C:\Windows\System32`, and it deleted the source-derived file after splitting.
   Everything now goes to a per-file output folder, and nothing is deleted.
6. **Emoji in the console.** They render as garbage under cp437. Output is plain ASCII.
7. **File names containing `!`** were corrupted by delayed expansion. Arguments are now
   read with delayed expansion off.
8. **Unvalidated numeric settings.** `/chunk 08` would crash `set /a` (leading zero is
   parsed as octal). Numeric switches are validated before anything runs.
9. **Write test could print "Access is denied"** past its own `2>nul`. The redirect is now
   wrapped so the probe is silent.
10. **Per-file result tracking.** The run ends with a count of ok / failed / skipped, and
    one bad file no longer looks like a successful run.

## Deliberate behaviour choices

- **ffmpeg output goes to the console, not the log.** The originals redirected everything
  into `ffmpeg_run.log`, which meant a two-hour encode showed no progress at all. Progress
  and warnings are now visible live; the log records the commands, settings, and exit code
  of each step. If you would rather have ffmpeg's full text captured, append
  `>> "!LOG!" 2>&1` to the ffmpeg lines — you lose the progress display.
- **MP3 stays `-ac 2 -ar 44100`**, as in your original, for maximum player compatibility.
  If your sources are mono lectures, setting `MP3_CHANNELS=1` halves the file size with no
  audible loss.
- **The oversized MP3 is kept** alongside its parts, rather than deleted as
  `audio extractor.bat` did.
- **Only the MP3 is size-split.** FLAC and MP4 splitting are time-based and opt-in, same
  as before. A long lecture's 16 kHz FLAC can still exceed 199 MB; if your upload target
  caps out, use `/wav` plus an external split, or say so and I'll add a FLAC splitter.

## Known limits

- `set /a` is 32-bit, so `/maxmb` is capped at 900. The default 199 is far below that.
- The dated folder name uses PowerShell for `yyyy-mm-dd`. Without PowerShell it falls back
  to the locale's `%DATE%`, which still works but may not sort chronologically.
- `-c copy` splits cut on the nearest keyframe, so MP4 chunk lengths are approximate.
- Dropping a *folder* is rejected with a clear message. Files only.
