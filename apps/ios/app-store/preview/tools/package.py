#!/usr/bin/env python3
"""Turns a folder of rendered frames and the synthesized audio into the App Store MP4.

Video: H.264 High Profile level 4.0, 30 fps, about 11 Mbps, yuv420p, Rec. 709. Audio: stereo AAC at 48 kHz and 256 kbps, loudness-normalized
to about -16 LUFS with true peaks under -1 dBTP. Exactly 792 frames, 26.4 seconds.
Usage: package.py <device> <frames-dir> <out.mp4> [--skip-audio]
"""
import json, os, re, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, "..")
device, frames, out = sys.argv[1:4]
work = os.path.join(ROOT, "renders", device)
os.makedirs(work, exist_ok=True)
py = sys.executable

if "--skip-audio" not in sys.argv:
    # The music is "Still Pickin'" by Kevin MacLeod (see music/CREDITS.md): 100.0 bpm, so its bars are the film's bars. The excerpt starts on a
    # downbeat and is faded out over the last 1.4 s. The sound effects are synthesized from events.json and laid over it.
    subprocess.check_call([py, os.path.join(HERE, "audio.py"), os.path.join(ROOT, "events.json"), device, work])
    music = os.path.join(work, "music-excerpt.wav")
    subprocess.check_call(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-ss", "23.7614", "-t", "27.4", "-i", os.path.join(ROOT, "music", "still-pickin-kevin-macleod.mp3"),
                           "-af", "aresample=48000,aformat=channel_layouts=stereo,afade=t=in:st=0:d=0.03,afade=t=out:st=25.0:d=1.4,volume=-3dB", "-c:a", "pcm_f32le", music])
    import numpy as np, soundfile as sf
    m, sr = sf.read(music); fx, _ = sf.read(os.path.join(work, "fx.wav"))
    n = max(len(m), len(fx)); mix = np.zeros((n, 2)); mix[:len(m)] += m; mix[:len(fx)] += fx * 0.63   # the effects sit a few dB under the music
    sf.write(os.path.join(work, "mix-raw.wav"), mix, 48000, subtype="FLOAT")
    raw0 = os.path.join(work, "mix-raw.wav")
    raw = os.path.join(work, "mix-limited.wav")
    # Tame peaks first (a lookahead limiter), so loudness normalization can reach its target without clipping.
    subprocess.check_call(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", raw0, "-af", "alimiter=limit=0.84:attack=3:release=120:level=false", "-c:a", "pcm_f32le", raw])
    # Two-pass loudness normalization: measure, then apply linearly so the shape of the mix is untouched.
    flt = "loudnorm=I=-16:TP=-1.5:LRA=7:print_format=json"
    r = subprocess.run(["ffmpeg", "-hide_banner", "-nostats", "-i", raw, "-af", flt, "-f", "null", "-"], capture_output=True, text=True)
    m2 = json.loads(re.search(r"\{[^{}]*\"input_i\"[^{}]*\}", r.stderr, re.S).group(0))
    apply = (f"loudnorm=I=-16:TP=-1.5:LRA=7:measured_I={m2['input_i']}:measured_TP={m2['input_tp']}:measured_LRA={m2['input_lra']}"
             f":measured_thresh={m2['input_thresh']}:offset={m2['target_offset']}:linear=true,atrim=0:26.4,asetpts=N/SR/TB")
    subprocess.check_call(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", raw, "-af", apply, "-ar", "48000", "-ac", "2", "-c:a", "pcm_s16le", os.path.join(work, "mix.wav")])

cmd = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-framerate", "30", "-i", os.path.join(frames, "%05d.png"), "-i", os.path.join(work, "mix.wav"),
       "-map", "0:v", "-map", "1:a", "-frames:v", "792",
       "-vf", "scale=in_range=full:out_range=tv:out_color_matrix=bt709,format=yuv420p",
       "-c:v", "libx264", "-profile:v", "high", "-level:v", "4.0", "-preset", "slow", "-b:v", "11M", "-maxrate", "12M", "-bufsize", "24M", "-g", "30", "-bf", "2",
       "-colorspace", "bt709", "-color_primaries", "bt709", "-color_trc", "bt709", "-color_range", "tv",
       "-c:a", "aac", "-b:a", "256k", "-ar", "48000", "-ac", "2", "-movflags", "+faststart", "-t", "26.4", out]
subprocess.check_call(cmd)
print(out, os.path.getsize(out) // 1024, "KB")
