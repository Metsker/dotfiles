#!/usr/bin/env python3
"""Turn any media file into voxtype-ready WAV chunks and print their paths.

Usage: chunk.py INPUT OUTDIR [--target SECONDS] [--limit SECONDS]
"""

import argparse
import os
import re
import subprocess
import sys


def ffmpeg(*args):
    return subprocess.run(["ffmpeg", "-hide_banner", *args], capture_output=True, text=True)


def die(message):
    sys.exit(f"chunk.py: {message}")


def extract(source, wav):
    result = ffmpeg("-v", "error", "-y", "-i", source, "-vn",
                    "-ar", "16000", "-ac", "1", "-c:a", "pcm_s16le", wav)
    if result.returncode != 0:
        die(f"could not extract audio from {source}\n{result.stderr.strip()}")


def duration(path):
    result = subprocess.run(
        ["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path],
        capture_output=True, text=True)
    return float(result.stdout.strip())


def silence_midpoints(wav):
    log = ffmpeg("-i", wav, "-af", "silencedetect=noise=-35dB:d=0.6", "-f", "null", "-").stderr
    starts = [float(v) for v in re.findall(r"silence_start: ([0-9.]+)", log)]
    ends = [float(v) for v in re.findall(r"silence_end: ([0-9.]+)", log)]
    return sorted((s + e) / 2 for s, e in zip(starts, ends))


def cut_points(mids, total, target):
    cuts, t = [], target
    while t < total - target / 4:
        # Nearest silence to the target, but never a chunk shorter than half the target.
        best = min(mids, key=lambda m: abs(m - t)) if mids else t
        if (cuts and best - cuts[-1] < target / 2) or best < target / 2:
            best = t
        if not cuts or best > cuts[-1]:
            cuts.append(best)
        t += target
    return cuts


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("source")
    parser.add_argument("outdir")
    parser.add_argument("--target", type=float, default=240.0, help="chunk length in seconds")
    parser.add_argument("--limit", type=float, default=540.0, help="split only above this length")
    args = parser.parse_args()

    os.makedirs(args.outdir, exist_ok=True)
    wav = os.path.join(args.outdir, "audio.wav")
    extract(args.source, wav)

    total = duration(wav)
    if total <= args.limit:
        print(wav)
        return

    cuts = cut_points(silence_midpoints(wav), total, args.target)
    if not cuts:
        die("no split points found")
    pattern = os.path.join(args.outdir, "chunk_%03d.wav")
    result = ffmpeg("-v", "error", "-y", "-i", wav, "-f", "segment",
                    "-segment_times", ",".join(f"{c:.2f}" for c in cuts), "-c", "copy", pattern)
    if result.returncode != 0:
        die(f"segmenting failed\n{result.stderr.strip()}")
    for name in sorted(os.listdir(args.outdir)):
        if name.startswith("chunk_"):
            print(os.path.join(args.outdir, name))


if __name__ == "__main__":
    main()
