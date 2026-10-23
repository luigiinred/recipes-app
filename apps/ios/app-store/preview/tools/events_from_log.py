#!/usr/bin/env python3
"""Reads a recorded scene's log and prints each APP_PREVIEW_EVENT as seconds into the .mov, using the recording's creation time.

The test prints unix times; the recording starts at RECORD_START (about a second before the first frame), so the
offsets are approximate. Use them to find the frame to look at, then confirm in the footage.
Usage: events_from_log.py <scene.log> <scene.mov>
"""
import re, subprocess, sys, json

log, mov = sys.argv[1:3]
start = None
events = []
for line in open(log, errors="ignore"):
    m = re.match(r"RECORD_START ([\d.]+)", line)
    if m: start = float(m.group(1))
    m = re.match(r"APP_PREVIEW_EVENT (\S+) ([\d.]+)", line)
    if m: events.append((m.group(1), float(m.group(2))))
dur = float(subprocess.check_output(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", mov]).strip())
print(json.dumps({"duration": dur, "events": [(n, round(t - start, 3)) for n, t in events]}))
