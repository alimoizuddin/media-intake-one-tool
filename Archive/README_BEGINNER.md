# Media Intake — Simple Guide

Drop a video on this tool. Get back an MP3 you can share, an audio file made for
transcription, and a clean MP4 that plays anywhere.

No commands to type. No settings to learn. Drag, drop, wait.

---

## Part 1 — One-time setup (about 5 minutes)

You only ever do this once.

### Step 1: Install FFmpeg

Media Intake is the remote control. FFmpeg is the engine that does the actual work.
Without it, nothing happens.

**The easy way (Windows 10 or 11):**

1. Click Start, type `Terminal`, right-click it, choose **Run as administrator**.
2. Copy this line, paste it in, press Enter:

   ```
   winget install Gyan.FFmpeg
   ```

3. Wait for it to finish. **Close the window completely and open a new one.**
4. Check that it worked. Type this and press Enter:

   ```
   ffmpeg -version
   ```

   If you see a few lines of text starting with `ffmpeg version`, you're done.
   If you see "not recognized", try the manual way below.

**The manual way (if the above didn't work):**

1. Go to https://www.gyan.dev/ffmpeg/builds/ and download **ffmpeg-release-essentials.zip**.
2. Right-click the downloaded zip, choose **Extract All**.
3. Open the extracted folder, then open the `bin` folder inside it.
4. You will see `ffmpeg.exe` and `ffprobe.exe`. You need **both**.
5. Copy both of those files and paste them into the same folder where you keep
   `Media_Intake.bat`.

That's it. Media Intake looks for them next to itself, so this works without any
PATH setup.

### Step 2: Choose where your finished files go

By default everything is saved to `F:\Lecture`.

**If you have an F: drive and that's fine, skip this step.**

If not, or if you want them somewhere else:

1. Right-click `Media_Intake.bat` and choose **Edit** (or **Open with → Notepad**).
2. Near the top, find this line:

   ```
   set "OUT_ROOT=F:\Lecture"
   ```

3. Change the path to whatever you want, for example:

   ```
   set "OUT_ROOT=D:\My Lectures"
   ```

4. Save the file and close Notepad.

Don't worry about breaking it. If the folder you pick doesn't exist or can't be
written to, the tool notices, tells you, and saves next to itself in a folder called
`Media_Intake_Output` instead.

---

## Part 2 — Using it

1. Find your video or audio file.
2. Drag it on top of `Media_Intake.bat` and let go.
3. A black window opens and starts working. Leave it alone.
4. When it says **Finished**, press any key to close it.

**You can drop several files at once.** Select them all, drag the whole group onto
the BAT, and it works through them one at a time.

### How long does it take?

The MP3 and transcription audio are quick — usually a minute or two per hour of
recording. The clean MP4 takes much longer because the video is being re-encoded.
For a long lecture, expect it to run for a while. The moving numbers in the window
mean it's working, not stuck.

### Is my original file safe?

Yes. Media Intake only reads your original. It never moves, changes, or deletes it.
Everything new goes in a separate folder.

---

## Part 3 — What you get

Say you dropped `Lecture 4.mp4`. You'll find a folder like this:

```
D:\My Lectures\2026-08-23\Lecture 4\
```

The date is the day you ran it, so runs never overwrite each other.

Inside:

| File | What it's for |
|---|---|
| `Lecture 4.mp3` | Normal audio. Share it, put it on your phone, listen in any player. |
| `Lecture 4__16k_mono.flac` | For transcription. Upload this to Whisper, Colab, or Gemini. |
| `Lecture 4.mp4` | Clean video that plays on any device and uploads without complaints. |
| `ffmpeg_run.log` | A record of what happened. Only needed if something went wrong. |

**Which one do I use?**

- Want to *listen*? → the **MP3**
- Want a *text transcript*? → the **FLAC**
- Want to *watch or upload the video*? → the **MP4**

The FLAC sounds quiet and flat if you play it. That's intentional — it's tuned for
transcription software, not for your ears. Use the MP3 for listening.

### Extra folders you might see

- **`mp3_parts`** — appears only when the MP3 came out bigger than 199 MB. Some sites
  and chat apps refuse large uploads, so the tool also saves the same audio cut into
  smaller pieces. The full MP3 is still there too; use whichever you need.
- **`mp4_parts`** — only appears if you asked for video splitting (see Part 5).

---

## Part 4 — When something goes wrong

The window tells you what happened. Here's what the messages mean.

| Message | What to do |
|---|---|
| `[ERROR] ffmpeg was not found` | Part 1 Step 1 didn't finish. Reopen your terminal and try `ffmpeg -version` again, or use the manual method. |
| `[ERROR] ffprobe was not found` | You copied only `ffmpeg.exe`. Go back and copy `ffprobe.exe` too — both are needed. |
| `[WARN] Cannot write to "F:\Lecture"` | That drive isn't there. Nothing is lost — your files were saved next to the BAT in `Media_Intake_Output`. Set your own folder using Part 1 Step 2. |
| `[SKIP] File not found` | The file moved or was renamed after you dragged it. Try again. |
| `[SKIP] That is a folder` | You dropped a folder. Open it and drop the actual files. |
| `[INFO] No video stream` | Normal for audio files like MP3 or M4A. It just skips the video step. |
| `[FAIL] ... See the messages above` | Scroll up in the black window. FFmpeg prints the reason there. A damaged or partly-downloaded source file is the usual cause. |
| The window flashes and vanishes | FFmpeg is missing, or the BAT was blocked by Windows. Right-click the BAT → **Properties** → tick **Unblock** if you see it → OK. |

At the end of every run you get a one-line summary:

```
Finished.  files: 3   ok: 3   failed: 0   skipped: 0
```

If `failed` and `skipped` are both `0`, everything worked.

---

## Part 5 — Optional extras

**You can safely ignore this entire section.** The defaults are good for most people.

If you ever want to change what gets made for a single run, open the folder containing
`Media_Intake.bat`, type `cmd` in the address bar, press Enter, and use lines like these:

```
Media_Intake.bat /audioonly "lecture.mp4"
```

| Add this | And it will |
|---|---|
| `/audioonly` | skip the video, make audio only (much faster) |
| `/nomp3` | skip the MP3 |
| `/notext` | skip the transcription file |
| `/wav` | make a WAV instead of a FLAC for transcription |
| `/copy` | also save an untouched copy of the original audio |
| `/chunk 15` | also cut the video into 15-minute pieces |
| `/out "D:\Somewhere"` | save this run somewhere else, just this once |
| `/?` | show the full list on screen |

To see them all any time, open that same `cmd` window and run:

```
Media_Intake.bat /?
```

---

## Quick reference

- **Setup:** install FFmpeg, then pick your output folder. Once, forever.
- **Use:** drag file onto the BAT. Wait. Done.
- **Listen** → MP3 · **Transcribe** → FLAC · **Watch** → MP4
- **Originals are never touched.**
- **Something broke?** Read the black window. It says what went wrong.
