---
name: transcribe
description: Transcribe an audio or video file to text locally with voxtype, splitting anything long enough to break the model. Use when asked to transcribe, get the text of, or read out a recording, meeting, video, voice message, or podcast file.
---

# Transcribe

voxtype is a push-to-talk dictation daemon, but `voxtype transcribe <file>` runs the same
model over a file. Everything is local, so no upload and no API key. Two things stand
between a media file and a transcript: the input format, and a length limit that reports
itself as something else entirely.

## The whole pipeline

```bash
out=$(mktemp -d)
python3 ~/.claude/skills/transcribe/chunk.py recording.mp4 "$out" | while read -r f; do
  voxtype transcribe "$f" 2>/dev/null
done | sed 's/\x1b\[[0-9;]*m//g' \
     | grep -vE '^(Loading audio file|Audio format|Processing |[0-9]{4}-[0-9]{2}-[0-9]{2}T)' \
     | grep -vE '^\s*$' > transcript.txt
```

`chunk.py` extracts the audio, splits it if it has to, and prints one WAV path per line -
so the loop is the same whether it printed one path or twenty. Write the transcript next to
the source file unless the user said otherwise, and tell them where it landed.

Reckon on roughly a minute of CPU per four minutes of audio with the default int8 model.
Say so before starting on anything long, rather than going quiet for ten minutes.

## Why the input has to be converted

`voxtype transcribe` accepts 16 kHz mono WAV and nothing else. A phone recording, a screen
capture, a voice message - all of them arrive as something else, usually 48 kHz stereo:

```bash
ffmpeg -i input.mp4 -vn -ar 16000 -ac 1 -c:a pcm_s16le out.wav
```

`-vn` drops the video stream, which is why a `.mp4` needs no separate step.

## Why it has to be split

The default engine, parakeet, has a fixed attention window of 7003 encoder frames - about
560 seconds. Past that it fails with an ONNX Runtime error naming a tensor node:

```
Parakeet TDT inference failed: ONNX Runtime error: Non-zero status code returned
while running Add node. Name:'/layers.0/self_attn/Add_2' ... Attempting to broadcast
an axis by a dimension other than 1. 7003 by 12003
```

Nothing there says "your audio is too long", but that is the entire problem: the second
number is the frame count of the input, at 80 ms per frame. Do not go looking for a
corrupt WAV or a bad model download - split the audio and it goes away.

`chunk.py` splits above nine minutes into four-minute pieces, cutting at silences found by
`ffmpeg -af silencedetect` so no word is severed at a boundary. Adjust with `--target` and
`--limit` if a different engine has a different ceiling.

Whisper does its own internal chunking and has no such limit, so `--engine whisper` is the
alternative to splitting - slower, and it downloads a model on first use.

## The log is on stdout

voxtype writes its tracing lines to stdout along with the transcript, in color, and one of
those lines quotes the transcript back in full. Unfiltered, the text lands in the file
twice with ANSI escapes wrapped around it. The `sed` and `grep` chain above is not
cosmetic - it is what makes the file a transcript.

## Where this does not help

`voxtype meeting` chunks internally and attributes speakers, which sounds like exactly this
job, but it only records live from the microphone. It has no file input. Use it for a
meeting happening now, not a file already on disk.

For a language other than the audio's own, add `--translate` (to English) or `--language`.
Both are global flags, so they go before the subcommand: `voxtype --language ru transcribe
f.wav`. Only `--engine` is accepted after it.
