"""
Last Light Odyssey - Procedural Audio Generator
Dark ambient + retro synthwave fusion music, clean sci-fi SFX
All output: 16-bit PCM WAV, 44100 Hz, stereo
3 music tracks (60-120s loops) + 25 sound effects = 28 files
"""

import numpy as np
import os
import struct
import wave

SAMPLE_RATE = 44100
BIT_DEPTH = 16


def ensure_dir(path):
    os.makedirs(path, exist_ok=True)


def save_wav_stereo(filepath, left, right):
    """Save stereo 16-bit PCM WAV file from two mono channel arrays."""
    ensure_dir(os.path.dirname(filepath))
    left = np.clip(left, -1.0, 1.0)
    right = np.clip(right, -1.0, 1.0)
    # Interleave L/R samples
    stereo = np.empty(len(left) + len(right), dtype=np.float64)
    stereo[0::2] = left
    stereo[1::2] = right
    samples_int = (stereo * 32767).astype(np.int16)
    with wave.open(filepath, 'w') as f:
        f.setnchannels(2)
        f.setsampwidth(2)
        f.setframerate(SAMPLE_RATE)
        f.writeframes(samples_int.tobytes())


def save_wav_mono_as_stereo(filepath, samples):
    """Save mono signal as stereo WAV (identical L/R)."""
    save_wav_stereo(filepath, samples, samples)


def t_array(duration):
    """Time array for given duration."""
    return np.linspace(0, duration, int(SAMPLE_RATE * duration), endpoint=False)


def sine(freq, duration):
    return np.sin(2 * np.pi * freq * t_array(duration))


def square(freq, duration, duty=0.5):
    t = t_array(duration)
    phase = (2 * np.pi * freq * t) % (2 * np.pi)
    return np.where(phase < 2 * np.pi * duty, 1.0, -1.0)


def saw(freq, duration):
    t = t_array(duration)
    return 2.0 * (freq * t - np.floor(0.5 + freq * t))


def noise(duration):
    return np.random.uniform(-1.0, 1.0, int(SAMPLE_RATE * duration))


def pink_noise(duration):
    """Generate pink noise using the Voss-McCartney algorithm approximation."""
    n = int(SAMPLE_RATE * duration)
    white = np.random.randn(n)
    # Simple pink filter: cascade of first-order lowpass
    b = [0.049922035, -0.095993537, 0.050612699, -0.004709510]
    a = [1.0, -2.494956002, 2.017265875, -0.522189400]
    from scipy.signal import lfilter
    try:
        pink = lfilter(b, a, white)
    except Exception:
        # Fallback: simple integration approach
        pink = np.cumsum(white)
        pink = pink - np.linspace(pink[0], pink[-1], n)
    # Normalize
    peak = np.max(np.abs(pink))
    if peak > 0:
        pink = pink / peak
    return pink


def lowpass(samples, cutoff):
    """Simple one-pole lowpass filter."""
    rc = 1.0 / (2 * np.pi * cutoff)
    dt = 1.0 / SAMPLE_RATE
    alpha = dt / (rc + dt)
    out = np.zeros_like(samples)
    out[0] = alpha * samples[0]
    for i in range(1, len(samples)):
        out[i] = out[i-1] + alpha * (samples[i] - out[i-1])
    return out


def highpass(samples, cutoff):
    """Simple one-pole highpass filter."""
    rc = 1.0 / (2 * np.pi * cutoff)
    dt = 1.0 / SAMPLE_RATE
    alpha = rc / (rc + dt)
    out = np.zeros_like(samples)
    out[0] = samples[0]
    for i in range(1, len(samples)):
        out[i] = alpha * (out[i-1] + samples[i] - samples[i-1])
    return out


def bandpass(samples, low, high):
    return highpass(lowpass(samples, high), low)


def reverb(samples, decay=0.3, delays=None):
    """Simple comb filter reverb."""
    if delays is None:
        delays = [int(SAMPLE_RATE * d) for d in [0.029, 0.037, 0.044, 0.053]]
    out = samples.copy()
    for delay in delays:
        delayed = np.zeros_like(samples)
        delayed[delay:] = samples[:-delay] * decay
        out += delayed
    # Normalize
    peak = np.max(np.abs(out))
    if peak > 1.0:
        out /= peak
    return out


def adsr(samples, attack=0.01, decay=0.1, sustain_level=0.7, release=0.1):
    """Apply ADSR envelope."""
    n = len(samples)
    a_n = min(int(SAMPLE_RATE * attack), n)
    d_n = min(int(SAMPLE_RATE * decay), n - a_n)
    r_n = min(int(SAMPLE_RATE * release), n - a_n - d_n)
    s_n = max(0, n - a_n - d_n - r_n)

    env = np.ones(n)
    idx = 0
    if a_n > 0:
        env[idx:idx + a_n] = np.linspace(0, 1, a_n)
        idx += a_n
    if d_n > 0:
        env[idx:idx + d_n] = np.linspace(1, sustain_level, d_n)
        idx += d_n
    if s_n > 0:
        env[idx:idx + s_n] = sustain_level
        idx += s_n
    if r_n > 0:
        env[idx:idx + r_n] = np.linspace(sustain_level, 0, r_n)
    return samples * env


def fade_in_out(samples, fade_in=2.0, fade_out=2.0):
    """Apply fade in/out for seamless looping."""
    fi = int(SAMPLE_RATE * fade_in)
    fo = int(SAMPLE_RATE * fade_out)
    if fi > 0 and fi < len(samples):
        samples[:fi] *= np.linspace(0, 1, fi)
    if fo > 0 and fo < len(samples):
        samples[-fo:] *= np.linspace(1, 0, fo)
    return samples


def freq_sweep(f_start, f_end, duration):
    """Generate a sine with linearly sweeping frequency."""
    t = t_array(duration)
    freq = np.linspace(f_start, f_end, len(t))
    phase = np.cumsum(2 * np.pi * freq / SAMPLE_RATE)
    return np.sin(phase)


def exp_sweep(f_start, f_end, duration):
    """Generate a sine with exponentially sweeping frequency."""
    t = t_array(duration)
    freq = f_start * (f_end / f_start) ** (t / duration)
    phase = np.cumsum(2 * np.pi * freq / SAMPLE_RATE)
    return np.sin(phase)


def stereo_spread(mono, spread=0.3):
    """Create stereo from mono with slight delay and filtering for width."""
    delay_samples = int(SAMPLE_RATE * 0.0008 * spread)  # up to ~0.24ms
    left = mono.copy()
    right = np.zeros_like(mono)
    if delay_samples > 0 and delay_samples < len(mono):
        right[delay_samples:] = mono[:-delay_samples]
    else:
        right = mono.copy()
    # Slight EQ difference for more width
    left = left * (1.0 + spread * 0.1)
    right = right * (1.0 - spread * 0.1)
    return left, right


# ============================================================================
# MUSIC TRACKS — Dark ambient + retro synthwave fusion
# ============================================================================

def generate_title_ambient():
    """~90s — Mysterious, slow evolving pads, gentle arpeggio, deep sub-bass, eerie."""
    duration = 90.0
    n = int(SAMPLE_RATE * duration)
    t = t_array(duration)
    left = np.zeros(n)
    right = np.zeros(n)

    # -- Sub-bass drone: D1 (36.71 Hz) with slow wobble --
    sub_freq = 36.71
    lfo_sub = 1.0 + 0.08 * np.sin(2 * np.pi * 0.05 * t)  # very slow wobble
    sub = np.sin(2 * np.pi * sub_freq * t * lfo_sub) * 0.2
    sub = lowpass(sub, 80)
    left += sub
    right += sub

    # -- Deep pad: Dm7 chord (D2, F2, A2, C3) with slow filter sweep --
    pad_freqs = [73.42, 87.31, 110.0, 130.81]
    for i, f in enumerate(pad_freqs):
        # Detuned pairs for thickness
        wave_a = np.sin(2 * np.pi * f * t)
        wave_b = np.sin(2 * np.pi * (f * 1.003) * t)  # slight detune
        pad = (wave_a + wave_b) * 0.08
        # Add 2nd harmonic
        pad += np.sin(2 * np.pi * f * 2 * t) * 0.03
        # Slow volume drift
        vol_lfo = 0.6 + 0.4 * np.sin(2 * np.pi * (0.03 + i * 0.01) * t)
        pad *= vol_lfo
        # Pan slightly for width
        pan = 0.3 * (i / len(pad_freqs) - 0.5)
        left += pad * (0.5 + pan)
        right += pad * (0.5 - pan)

    # -- Eerie high shimmer: filtered noise evolving --
    shim = noise(duration)
    # Slow filter sweep
    for cutoff in [1800, 2200, 2600]:
        component = lowpass(highpass(shim, cutoff - 200), cutoff + 200) * 0.015
        lfo = 0.5 + 0.5 * np.sin(2 * np.pi * 0.07 * t + cutoff * 0.01)
        component *= lfo
        left += component * 0.7
        right += component * 1.3

    # -- Gentle arpeggio: D minor pentatonic, every ~4 seconds --
    arp_notes = [293.66, 349.23, 392.00, 440.00, 523.25]  # D4, F4, G4, A4, C5
    note_dur = 1.8
    gap = 0.2
    cycle_time = (note_dur + gap)
    for beat_idx in range(int(duration / cycle_time)):
        note_idx = beat_idx % len(arp_notes)
        freq = arp_notes[note_idx]
        start = beat_idx * cycle_time
        start_sample = int(start * SAMPLE_RATE)
        note_n = int(note_dur * SAMPLE_RATE)
        if start_sample + note_n > n:
            break
        nt = t_array(note_dur)
        note = np.sin(2 * np.pi * freq * nt) * 0.06
        # Add soft overtone
        note += np.sin(2 * np.pi * freq * 2 * nt) * 0.02
        # Soft envelope
        note = adsr(note, attack=0.15, decay=0.4, sustain_level=0.3, release=0.8)
        # Gentle reverb tail
        note = reverb(note, decay=0.25)
        # Alternate stereo placement
        pan = 0.2 * np.sin(beat_idx * 0.7)
        left[start_sample:start_sample + len(note)] += note * (0.5 + pan)
        right[start_sample:start_sample + len(note)] += note * (0.5 - pan)

    # -- Slow evolving texture: ring-modulated pad --
    ring_carrier = np.sin(2 * np.pi * 220 * t)
    ring_mod = np.sin(2 * np.pi * 0.1 * t)
    ring = ring_carrier * ring_mod * 0.04
    ring = lowpass(ring, 600)
    left += ring * 0.6
    right += ring * 1.0

    # Fade in/out and normalize
    left = fade_in_out(left, 3.0, 3.0)
    right = fade_in_out(right, 3.0, 3.0)
    mx = max(np.max(np.abs(left)), np.max(np.abs(right)), 0.01)
    left = np.clip(left / mx * 0.85, -1.0, 1.0)
    right = np.clip(right / mx * 0.85, -1.0, 1.0)
    return left, right


def generate_management_ambient():
    """~80s — Tense pulsing bass, steady tick rhythm, decision-weight atmosphere."""
    duration = 80.0
    n = int(SAMPLE_RATE * duration)
    t = t_array(duration)
    left = np.zeros(n)
    right = np.zeros(n)

    # -- Pulsing bass: A1 (55 Hz) with rhythmic amplitude --
    bass_freq = 55.0
    # Pulse at ~0.5 Hz (2 second cycle) — tense heartbeat-like
    pulse_env = 0.4 + 0.6 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.5 * t)) ** 2
    bass = np.sin(2 * np.pi * bass_freq * t) * 0.22
    bass += np.sin(2 * np.pi * bass_freq * 2 * t) * 0.08  # 2nd harmonic
    bass *= pulse_env
    bass = lowpass(bass, 150)
    left += bass
    right += bass

    # -- Tick rhythm: metallic click every 0.5s (120 BPM half-time feel) --
    tick_interval = 0.5
    tick_dur = 0.03
    for i in range(int(duration / tick_interval)):
        start_sample = int(i * tick_interval * SAMPLE_RATE)
        tick_n = int(tick_dur * SAMPLE_RATE)
        if start_sample + tick_n > n:
            break
        tick_t = t_array(tick_dur)
        tick = np.sin(2 * np.pi * 4000 * tick_t) * 0.12
        tick += noise(tick_dur) * 0.04
        tick = adsr(tick, attack=0.001, decay=0.008, sustain_level=0.0, release=0.02)
        # Alternate L/R slightly
        pan = 0.15 * (-1 if i % 2 == 0 else 1)
        left[start_sample:start_sample + len(tick)] += tick * (0.5 + pan)
        right[start_sample:start_sample + len(tick)] += tick * (0.5 - pan)

    # -- Synth pad layers: Am7 (A, C, E, G) — tense minor seventh --
    pad_freqs = [220.0, 261.63, 329.63, 392.00]
    for i, f in enumerate(pad_freqs):
        wave_a = np.sin(2 * np.pi * f * t)
        wave_b = np.sin(2 * np.pi * (f * 1.005) * t)  # detune
        pad = (wave_a + wave_b) * 0.06
        # Slow filter modulation
        vol_lfo = 0.5 + 0.5 * np.sin(2 * np.pi * (0.04 + i * 0.015) * t)
        pad *= vol_lfo
        pad = lowpass(pad, 1500)
        pan = 0.4 * (i / len(pad_freqs) - 0.5)
        left += pad * (0.5 + pan)
        right += pad * (0.5 - pan)

    # -- Tension riser: very slow ascending filtered noise --
    tens = noise(duration)
    tens = bandpass(tens, 800, 3000) * 0.04
    # Slow volume swell
    swell = np.linspace(0, 1, n) ** 2
    tens *= swell * 0.5
    left += tens * 0.7
    right += tens * 1.3

    # -- Occasional deep rumble accent every ~10 seconds --
    rumble_interval = 10.0
    rumble_dur = 2.0
    for i in range(int(duration / rumble_interval)):
        start_sample = int(i * rumble_interval * SAMPLE_RATE)
        r_n = int(rumble_dur * SAMPLE_RATE)
        if start_sample + r_n > n:
            break
        rt = t_array(rumble_dur)
        rumble = np.sin(2 * np.pi * 30 * rt) * 0.08
        rumble += noise(rumble_dur) * 0.02
        rumble = lowpass(rumble, 60)
        rumble = adsr(rumble, attack=0.3, decay=0.5, sustain_level=0.3, release=0.8)
        left[start_sample:start_sample + len(rumble)] += rumble
        right[start_sample:start_sample + len(rumble)] += rumble

    left = fade_in_out(left, 3.0, 3.0)
    right = fade_in_out(right, 3.0, 3.0)
    mx = max(np.max(np.abs(left)), np.max(np.abs(right)), 0.01)
    left = np.clip(left / mx * 0.85, -1.0, 1.0)
    right = np.clip(right / mx * 0.85, -1.0, 1.0)
    return left, right


def generate_combat_ambient():
    """~70s — Driving pulse, fast arp sequences, urgent bass, high energy atmospheric."""
    duration = 70.0
    n = int(SAMPLE_RATE * duration)
    t = t_array(duration)
    left = np.zeros(n)
    right = np.zeros(n)
    bpm = 140.0
    beat_dur = 60.0 / bpm

    # -- Driving bass: E1 (41.2 Hz) with sidechain-like pumping --
    bass_freq = 41.2
    # Sidechain pump: fast attack, medium release, on every beat
    pump = np.ones(n)
    for i in range(int(duration / beat_dur)):
        start = int(i * beat_dur * SAMPLE_RATE)
        pump_n = int(0.15 * SAMPLE_RATE)  # pump dip duration
        if start + pump_n > n:
            break
        pump_t = np.linspace(0, 1, pump_n)
        pump_shape = 1.0 - 0.7 * np.exp(-pump_t * 8)
        pump[start:start + pump_n] = pump_shape

    bass = np.sin(2 * np.pi * bass_freq * t) * 0.25
    bass += np.sin(2 * np.pi * bass_freq * 2 * t) * 0.1
    bass += saw(bass_freq, duration) * 0.05  # add grit
    bass = lowpass(bass, 200)
    bass *= pump
    left += bass
    right += bass

    # -- Kick drum on every beat --
    kick_dur = 0.08
    for i in range(int(duration / beat_dur)):
        start = int(i * beat_dur * SAMPLE_RATE)
        k_n = int(kick_dur * SAMPLE_RATE)
        if start + k_n > n:
            break
        kt = t_array(kick_dur)
        # Pitch-dropping sine for kick
        kick_freq = 150 * np.exp(-kt * 40) + 40
        kick_phase = np.cumsum(2 * np.pi * kick_freq / SAMPLE_RATE)
        kick = np.sin(kick_phase) * 0.3
        kick *= np.exp(-kt * 25)  # fast decay
        left[start:start + k_n] += kick
        right[start:start + k_n] += kick

    # -- Hi-hat: every 8th note --
    eighth_dur = beat_dur / 2
    hat_dur = 0.03
    for i in range(int(duration / eighth_dur)):
        start = int(i * eighth_dur * SAMPLE_RATE)
        h_n = int(hat_dur * SAMPLE_RATE)
        if start + h_n > n:
            break
        hat = noise(hat_dur) * 0.08
        hat = highpass(hat, 6000)
        hat = adsr(hat, attack=0.001, decay=0.01, sustain_level=0.0, release=0.015)
        # Open hat on off-beats
        if i % 2 == 1:
            hat *= 1.3
        pan = 0.1 * (-1 if i % 2 == 0 else 1)
        left[start:start + len(hat)] += hat * (0.5 + pan)
        right[start:start + len(hat)] += hat * (0.5 - pan)

    # -- Fast arp: Em pentatonic, 16th notes --
    arp_notes = [164.81, 196.00, 246.94, 329.63, 392.00, 493.88]  # E3-B4
    sixteenth = beat_dur / 4
    arp_note_dur = sixteenth * 0.7
    for i in range(int(duration / sixteenth)):
        note_idx = i % len(arp_notes)
        freq = arp_notes[note_idx]
        start = int(i * sixteenth * SAMPLE_RATE)
        an = int(arp_note_dur * SAMPLE_RATE)
        if start + an > n:
            break
        at = t_array(arp_note_dur)
        # Saw + sine for synthwave character
        note = saw(freq, arp_note_dur) * 0.04
        note += np.sin(2 * np.pi * freq * at) * 0.03
        note = lowpass(note, 3000)
        note = adsr(note, attack=0.005, decay=0.03, sustain_level=0.4, release=arp_note_dur * 0.3)
        # Wide stereo arp
        pan = 0.3 * np.sin(i * 0.5)
        left[start:start + len(note)] += note * (0.5 + pan)
        right[start:start + len(note)] += note * (0.5 - pan)

    # -- Urgent pad: Em (E, G, B) power chord area --
    pad_freqs = [82.41, 123.47, 164.81]
    for i, f in enumerate(pad_freqs):
        wave_a = np.sin(2 * np.pi * f * t) * 0.06
        wave_b = np.sin(2 * np.pi * (f * 1.007) * t) * 0.04
        pad = wave_a + wave_b
        pad *= pump  # sidechain
        pad = lowpass(pad, 800)
        pan = 0.3 * (i / len(pad_freqs) - 0.5)
        left += pad * (0.5 + pan)
        right += pad * (0.5 - pan)

    # -- Noise riser/texture --
    tex = noise(duration)
    tex = bandpass(tex, 2000, 6000) * 0.03
    tex *= pump
    left += tex * 0.6
    right += tex * 1.0

    left = fade_in_out(left, 2.0, 2.0)
    right = fade_in_out(right, 2.0, 2.0)
    mx = max(np.max(np.abs(left)), np.max(np.abs(right)), 0.01)
    left = np.clip(left / mx * 0.85, -1.0, 1.0)
    right = np.clip(right / mx * 0.85, -1.0, 1.0)
    return left, right


# ============================================================================
# SFX GENERATORS — Clean sci-fi
# ============================================================================

def generate_ui_click():
    """Short crisp digital click, bright tone."""
    dur = 0.08
    t = t_array(dur)
    click = np.sin(2 * np.pi * 2400 * t) * 0.5
    click += np.sin(2 * np.pi * 4800 * t) * 0.2
    click += noise(dur) * 0.1
    click = highpass(click, 1000)
    return adsr(click, attack=0.001, decay=0.015, sustain_level=0.0, release=0.05)


def generate_ui_hover():
    """Soft high-frequency sweep, subtle."""
    dur = 0.06
    sweep = freq_sweep(3000, 5000, dur) * 0.15
    sweep += freq_sweep(6000, 8000, dur) * 0.05
    return adsr(sweep, attack=0.005, decay=0.02, sustain_level=0.0, release=0.03)


def generate_ui_dialog_open():
    """Rising tone sweep, terminal boot feel."""
    dur = 0.25
    t = t_array(dur)
    sweep = freq_sweep(300, 1800, dur) * 0.4
    # Add digital overtones
    sweep += freq_sweep(600, 3600, dur) * 0.12
    # Terminal-like blip at the end
    blip_start = int(0.18 * SAMPLE_RATE)
    blip = np.zeros(len(t))
    blip_dur = 0.05
    blip_n = int(blip_dur * SAMPLE_RATE)
    if blip_start + blip_n <= len(blip):
        blip[blip_start:blip_start + blip_n] = np.sin(2 * np.pi * 2000 * t_array(blip_dur)) * 0.15
    sweep += blip
    sweep = lowpass(sweep, 5000)
    return adsr(sweep, attack=0.01, decay=0.08, sustain_level=0.2, release=0.1)


def generate_ui_dialog_close():
    """Falling tone sweep."""
    dur = 0.2
    sweep = freq_sweep(1800, 300, dur) * 0.35
    sweep += freq_sweep(3600, 600, dur) * 0.1
    sweep = lowpass(sweep, 5000)
    return adsr(sweep, attack=0.005, decay=0.06, sustain_level=0.0, release=0.1)


def generate_ui_end_turn():
    """Confirmation beep sequence (two-tone)."""
    beep1_dur = 0.08
    gap_dur = 0.04
    beep2_dur = 0.1
    t1 = t_array(beep1_dur)
    t2 = t_array(beep2_dur)
    beep1 = np.sin(2 * np.pi * 880 * t1) * 0.4
    beep1 += np.sin(2 * np.pi * 1760 * t1) * 0.1
    gap = np.zeros(int(SAMPLE_RATE * gap_dur))
    beep2 = np.sin(2 * np.pi * 1174.66 * t2) * 0.45  # D6 — affirming rise
    beep2 += np.sin(2 * np.pi * 2349.32 * t2) * 0.1
    out = np.concatenate([beep1, gap, beep2])
    return adsr(out, attack=0.003, decay=0.03, sustain_level=0.5, release=0.06)


def generate_ui_transition():
    """Whoosh sweep with reverb tail."""
    dur = 0.5
    t = t_array(dur)
    # Filtered noise whoosh
    whoosh = noise(dur)
    whoosh = bandpass(whoosh, 200, 8000) * 0.4
    # Volume envelope: crescendo then decrescendo
    env = np.sin(np.pi * t / dur) ** 0.5
    whoosh *= env
    # Add tonal sweep
    sweep = freq_sweep(150, 3000, dur) * 0.1 * env
    out = whoosh + sweep
    out = reverb(out, decay=0.2)
    return adsr(out, attack=0.02, decay=0.15, sustain_level=0.3, release=0.2)


def generate_combat_fire():
    """Clean laser/pulse rifle shot."""
    dur = 0.18
    t = t_array(dur)
    # Descending pitch zap
    zap = freq_sweep(3000, 400, dur) * 0.5
    # Noise burst at attack
    burst = noise(dur) * 0.3
    burst = highpass(burst, 2000)
    burst *= np.exp(-t * 30)
    out = zap + burst
    return adsr(out, attack=0.001, decay=0.04, sustain_level=0.0, release=0.12)


def generate_combat_hit():
    """Impact thud with metallic ring."""
    dur = 0.25
    t = t_array(dur)
    # Low thud
    thud = np.sin(2 * np.pi * 60 * t) * 0.6
    thud *= np.exp(-t * 15)
    # Metallic ring
    ring = np.sin(2 * np.pi * 1200 * t) * 0.2
    ring += np.sin(2 * np.pi * 2700 * t) * 0.1
    ring *= np.exp(-t * 10)
    # Noise impact
    impact = noise(dur) * 0.25
    impact = bandpass(impact, 500, 3000)
    impact *= np.exp(-t * 20)
    return thud + ring + impact


def generate_combat_miss():
    """Whizz-by ricochet."""
    dur = 0.3
    t = t_array(dur)
    # Doppler-like frequency shift
    center = dur * 0.3
    freq = 800 + 600 * np.exp(-((t - center) ** 2) / (2 * 0.04 ** 2))
    phase = np.cumsum(2 * np.pi * freq / SAMPLE_RATE)
    whizz = np.sin(phase) * 0.3
    # Noise whoosh
    whoosh = noise(dur) * 0.15
    whoosh = bandpass(whoosh, 1000, 5000)
    whoosh *= np.exp(-np.abs(t - center) * 8)
    out = whizz + whoosh
    return adsr(out, attack=0.01, decay=0.08, sustain_level=0.0, release=0.15)


def generate_combat_crit():
    """Enhanced hit with extra punch and ring."""
    dur = 0.35
    t = t_array(dur)
    # Heavy impact
    thud = np.sin(2 * np.pi * 45 * t) * 0.7
    thud *= np.exp(-t * 12)
    # Bright metallic ring — more harmonics than regular hit
    ring = np.sin(2 * np.pi * 1500 * t) * 0.25
    ring += np.sin(2 * np.pi * 3000 * t) * 0.15
    ring += np.sin(2 * np.pi * 4500 * t) * 0.08
    ring *= np.exp(-t * 7)
    # Extra punch: distorted noise burst
    punch = noise(dur) * 0.4
    punch = bandpass(punch, 300, 4000)
    punch *= np.exp(-t * 18)
    # Dramatic low sweep
    sweep = freq_sweep(200, 50, dur) * 0.15
    sweep *= np.exp(-t * 8)
    out = thud + ring + punch + sweep
    return adsr(out, attack=0.001, decay=0.08, sustain_level=0.1, release=0.2)


def generate_combat_overwatch():
    """Alert ping + snap shot combo."""
    dur = 0.3
    # Alert ping
    ping_dur = 0.08
    tp = t_array(ping_dur)
    ping = np.sin(2 * np.pi * 2000 * tp) * 0.35
    ping *= np.exp(-tp * 20)
    # Gap
    gap = np.zeros(int(SAMPLE_RATE * 0.05))
    # Snap shot (quick fire sound)
    snap_dur = 0.15
    ts = t_array(snap_dur)
    snap = freq_sweep(2500, 600, snap_dur) * 0.4
    snap += noise(snap_dur) * 0.15
    snap = highpass(snap, 800)
    snap *= np.exp(-ts * 15)
    out = np.concatenate([ping, gap, snap])
    # Pad to dur
    target_n = int(SAMPLE_RATE * dur)
    if len(out) < target_n:
        out = np.concatenate([out, np.zeros(target_n - len(out))])
    return out[:target_n]


def generate_combat_turret_fire():
    """Rapid electronic burst."""
    dur = 0.15
    t = t_array(dur)
    # Rapid pulses
    pulse_freq = 40  # 40 Hz = rapid stutter
    gate = (np.sin(2 * np.pi * pulse_freq * t) > 0).astype(float)
    burst = freq_sweep(2000, 800, dur) * 0.4
    burst += noise(dur) * 0.2
    burst = highpass(burst, 1000)
    burst *= gate
    return adsr(burst, attack=0.001, decay=0.03, sustain_level=0.3, release=0.08)


def generate_combat_heal():
    """Warm ascending chime sequence."""
    notes = [523.25, 659.25, 783.99, 1046.50]  # C5, E5, G5, C6
    note_dur = 0.15
    out = np.array([])
    for i, freq in enumerate(notes):
        t = t_array(note_dur)
        chime = np.sin(2 * np.pi * freq * t) * 0.3
        chime += np.sin(2 * np.pi * freq * 2 * t) * 0.08  # overtone
        chime = adsr(chime, attack=0.008, decay=0.04, sustain_level=0.3, release=0.06)
        out = np.concatenate([out, chime])
    out = reverb(out, decay=0.15)
    return out


def generate_combat_charge():
    """Heavy whoosh + impact slam."""
    dur = 0.4
    t = t_array(dur)
    # Whoosh buildup
    whoosh = noise(dur) * 0.3
    whoosh = bandpass(whoosh, 200, 3000)
    whoosh *= np.linspace(0.1, 1.0, len(t))
    # Low rumble buildup
    rumble = np.sin(2 * np.pi * 60 * t) * 0.3
    rumble *= np.linspace(0, 1, len(t)) ** 2
    # Impact at 75% through
    impact_time = 0.3
    impact_sample = int(impact_time * SAMPLE_RATE)
    impact = np.zeros(len(t))
    remaining = len(t) - impact_sample
    if remaining > 0:
        it = t_array(remaining / SAMPLE_RATE)
        imp = np.sin(2 * np.pi * 40 * it) * 0.5
        imp += noise(remaining / SAMPLE_RATE) * 0.3
        imp = lowpass(imp, 500)
        imp *= np.exp(-it * 12)
        impact[impact_sample:impact_sample + len(imp)] = imp
    out = whoosh + rumble + impact
    return out


def generate_combat_execute():
    """Dramatic single powerful shot."""
    dur = 0.35
    t = t_array(dur)
    # Massive bass hit
    bass = np.sin(2 * np.pi * 35 * t) * 0.7
    bass *= np.exp(-t * 10)
    # Sharp high crack
    crack = noise(dur) * 0.5
    crack = highpass(crack, 3000)
    crack *= np.exp(-t * 25)
    # Mid resonance
    mid = np.sin(2 * np.pi * 400 * t) * 0.2
    mid *= np.exp(-t * 12)
    out = bass + crack + mid
    return adsr(out, attack=0.001, decay=0.1, sustain_level=0.0, release=0.2)


def generate_combat_precision():
    """Charged-up release, long-range sniper feel."""
    dur = 0.5
    t = t_array(dur)
    # Charge-up phase (first 0.2s)
    charge_end = 0.2
    charge_mask = (t < charge_end).astype(float)
    charge = freq_sweep(200, 4000, dur) * 0.2 * charge_mask
    charge *= np.linspace(0, 1, len(t))
    # Release crack at 0.2s
    release_mask = (t >= charge_end).astype(float)
    crack = noise(dur) * 0.5 * release_mask
    crack = highpass(crack, 2000)
    crack *= np.exp(-np.maximum(t - charge_end, 0) * 15)
    # Sniper tone: sharp, ringing
    tone = np.sin(2 * np.pi * 1800 * t) * 0.2 * release_mask
    tone *= np.exp(-np.maximum(t - charge_end, 0) * 8)
    # Echo tail
    out = charge + crack + tone
    out = reverb(out, decay=0.2)
    return out


def generate_combat_damage():
    """Dull impact, armor absorb."""
    dur = 0.15
    t = t_array(dur)
    # Dull thud — lower frequencies
    thud = np.sin(2 * np.pi * 80 * t) * 0.4
    thud += np.sin(2 * np.pi * 120 * t) * 0.2
    thud *= np.exp(-t * 18)
    # Muffled noise
    n = noise(dur) * 0.2
    n = lowpass(n, 600)
    n *= np.exp(-t * 20)
    return thud + n


def generate_combat_death():
    """Collapse with metallic clatter."""
    dur = 0.6
    t = t_array(dur)
    # Descending tone — falling
    desc = freq_sweep(400, 60, dur) * 0.3
    desc *= np.exp(-t * 4)
    # Metallic clatter — multiple resonant hits
    clatter = np.zeros(len(t))
    clatter_times = [0.05, 0.12, 0.2, 0.3, 0.42]
    clatter_freqs = [2200, 1800, 3100, 1500, 2600]
    for ct, cf in zip(clatter_times, clatter_freqs):
        ci = int(ct * SAMPLE_RATE)
        remaining = len(t) - ci
        if remaining > 0:
            ct_t = t_array(remaining / SAMPLE_RATE)
            hit = np.sin(2 * np.pi * cf * ct_t) * 0.12
            hit += noise(remaining / SAMPLE_RATE) * 0.05
            hit *= np.exp(-ct_t * 15)
            clatter[ci:ci + len(hit)] += hit
    out = desc + clatter
    return adsr(out, attack=0.005, decay=0.2, sustain_level=0.2, release=0.3)


def generate_combat_enemy_alert():
    """Sharp alert ping, hostile detected."""
    dur = 0.25
    # Two sharp pings, rising
    ping1_dur = 0.06
    t1 = t_array(ping1_dur)
    ping1 = np.sin(2 * np.pi * 1800 * t1) * 0.4
    ping1 *= np.exp(-t1 * 25)
    gap = np.zeros(int(SAMPLE_RATE * 0.03))
    ping2_dur = 0.08
    t2 = t_array(ping2_dur)
    ping2 = np.sin(2 * np.pi * 2400 * t2) * 0.45
    ping2 *= np.exp(-t2 * 20)
    out = np.concatenate([ping1, gap, ping2])
    target_n = int(SAMPLE_RATE * dur)
    if len(out) < target_n:
        out = np.concatenate([out, np.zeros(target_n - len(out))])
    return out[:target_n]


def generate_alarm_cryo():
    """Urgent repeating klaxon, cold/digital."""
    dur = 1.0
    t = t_array(dur)
    # Klaxon: oscillating between two tones at 4 Hz
    mod = (np.sin(2 * np.pi * 4 * t) > 0).astype(float)
    tone_hi = np.sin(2 * np.pi * 880 * t) * 0.4
    tone_lo = np.sin(2 * np.pi * 660 * t) * 0.35
    klaxon = tone_hi * mod + tone_lo * (1 - mod)
    # Add harsh digital edge
    klaxon += square(440, dur) * 0.08
    klaxon = lowpass(klaxon, 4000)
    # Cold shimmer overlay
    shim = noise(dur) * 0.06
    shim = bandpass(shim, 4000, 8000)
    out = klaxon + shim
    return adsr(out, attack=0.01, decay=0.1, sustain_level=0.8, release=0.1)


def generate_alarm_game_over():
    """Low dramatic drone, descending."""
    dur = 2.0
    t = t_array(dur)
    # Deep descending drone
    drone = freq_sweep(200, 40, dur) * 0.4
    drone += freq_sweep(300, 60, dur) * 0.2
    # Minor chord dissolving
    chord = np.sin(2 * np.pi * 146.83 * t) * 0.15  # D3
    chord += np.sin(2 * np.pi * 174.61 * t) * 0.12  # F3
    chord *= np.exp(-t * 1.5)
    # Noise texture
    tex = noise(dur) * 0.08
    tex = lowpass(tex, 500)
    out = drone + chord + tex
    return adsr(out, attack=0.05, decay=0.5, sustain_level=0.4, release=1.0)


def generate_alarm_victory():
    """Triumphant ascending fanfare."""
    dur = 1.5
    # C major arpeggio ascending: C5, E5, G5, C6
    notes = [523.25, 659.25, 783.99, 1046.50]
    note_dur = 0.3
    out = np.array([])
    for i, freq in enumerate(notes):
        t = t_array(note_dur)
        tone = np.sin(2 * np.pi * freq * t) * 0.35
        tone += np.sin(2 * np.pi * freq * 2 * t) * 0.1  # octave
        tone += np.sin(2 * np.pi * freq * 3 * t) * 0.05  # 12th
        tone = adsr(tone, attack=0.01, decay=0.08, sustain_level=0.5, release=0.1)
        out = np.concatenate([out, tone])
    # Final sustain chord
    final_dur = dur - len(notes) * note_dur
    if final_dur > 0:
        ft = t_array(final_dur)
        chord = np.zeros(len(ft))
        for freq in notes:
            chord += np.sin(2 * np.pi * freq * ft) * 0.15
        chord = adsr(chord, attack=0.02, decay=0.1, sustain_level=0.6, release=final_dur * 0.6)
        out = np.concatenate([out, chord])
    out = reverb(out, decay=0.2)
    return out


def generate_move_step():
    """Metallic boot on grating."""
    dur = 0.1
    t = t_array(dur)
    # Transient click
    click = noise(dur) * 0.4
    click = bandpass(click, 800, 4000)
    click *= np.exp(-t * 35)
    # Metallic resonance
    ring = np.sin(2 * np.pi * 3500 * t) * 0.15
    ring *= np.exp(-t * 25)
    return click + ring


def generate_move_extraction():
    """Beam-up energy shimmer."""
    dur = 1.2
    t = t_array(dur)
    # Rising shimmer — multiple harmonics ascending
    out = np.zeros(len(t))
    for i, base in enumerate([300, 500, 700, 900]):
        freq = base + base * 0.8 * (t / dur)
        phase = np.cumsum(2 * np.pi * freq / SAMPLE_RATE)
        harmonic = np.sin(phase) * (0.12 / (i + 1))
        out += harmonic
    # Sparkle noise
    sparkle = noise(dur) * 0.08
    sparkle = highpass(sparkle, 5000)
    sparkle *= np.linspace(0.2, 1.0, len(t))
    out += sparkle
    # Volume swell
    out *= np.linspace(0.3, 1.0, len(t))
    out = reverb(out, decay=0.2)
    return adsr(out, attack=0.1, decay=0.3, sustain_level=0.6, release=0.4)


def generate_move_jump():
    """FTL warp whoosh, deep bass to high sweep."""
    dur = 0.9
    t = t_array(dur)
    # Deep bass buildup
    bass = np.sin(2 * np.pi * 30 * t) * 0.4
    bass *= np.exp(-t * 3)
    # Exponential frequency sweep: bass to treble
    sweep = exp_sweep(50, 8000, dur) * 0.3
    sweep *= np.sin(np.pi * t / dur)  # envelope: rise and fall
    # Whoosh noise
    whoosh = noise(dur) * 0.2
    whoosh = bandpass(whoosh, 200, 6000)
    whoosh *= np.sin(np.pi * t / dur)
    out = bass + sweep + whoosh
    out = reverb(out, decay=0.15)
    return out


# ============================================================================
# MAIN
# ============================================================================

def main():
    print("Last Light Odyssey — Audio Generator")
    print("44100 Hz, 16-bit, Stereo")
    print("=" * 60)

    base = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")

    # --- Music (stereo, directly generated) ---
    music_dir = os.path.join(base, "music")
    music_tracks = [
        ("title_ambient.wav", generate_title_ambient),
        ("management_ambient.wav", generate_management_ambient),
        ("combat_ambient.wav", generate_combat_ambient),
    ]
    print("\n[MUSIC]")
    for name, gen in music_tracks:
        print(f"  Generating {name}...")
        left, right = gen()
        save_wav_stereo(os.path.join(music_dir, name), left, right)

    # --- SFX (mono generators, saved as stereo) ---
    sfx = [
        ("sfx/ui", "click.wav", generate_ui_click),
        ("sfx/ui", "hover.wav", generate_ui_hover),
        ("sfx/ui", "dialog_open.wav", generate_ui_dialog_open),
        ("sfx/ui", "dialog_close.wav", generate_ui_dialog_close),
        ("sfx/ui", "end_turn.wav", generate_ui_end_turn),
        ("sfx/ui", "transition.wav", generate_ui_transition),
        ("sfx/combat", "fire.wav", generate_combat_fire),
        ("sfx/combat", "hit.wav", generate_combat_hit),
        ("sfx/combat", "miss.wav", generate_combat_miss),
        ("sfx/combat", "crit.wav", generate_combat_crit),
        ("sfx/combat", "overwatch.wav", generate_combat_overwatch),
        ("sfx/combat", "turret_fire.wav", generate_combat_turret_fire),
        ("sfx/combat", "heal.wav", generate_combat_heal),
        ("sfx/combat", "charge.wav", generate_combat_charge),
        ("sfx/combat", "execute.wav", generate_combat_execute),
        ("sfx/combat", "precision.wav", generate_combat_precision),
        ("sfx/combat", "damage.wav", generate_combat_damage),
        ("sfx/combat", "death.wav", generate_combat_death),
        ("sfx/combat", "enemy_alert.wav", generate_combat_enemy_alert),
        ("sfx/alarms", "cryo_alarm.wav", generate_alarm_cryo),
        ("sfx/alarms", "game_over.wav", generate_alarm_game_over),
        ("sfx/alarms", "victory.wav", generate_alarm_victory),
        ("sfx/movement", "footstep.wav", generate_move_step),
        ("sfx/movement", "extraction_beam.wav", generate_move_extraction),
        ("sfx/movement", "jump_warp.wav", generate_move_jump),
    ]

    categories = {}
    for subdir, name, gen in sfx:
        cat = subdir.split("/")[-1].upper()
        if cat not in categories:
            categories[cat] = []
        categories[cat].append((subdir, name, gen))

    for cat, items in categories.items():
        print(f"\n[{cat} SFX]")
        for subdir, name, gen in items:
            print(f"  Generating {name}...")
            samples = gen()
            path = os.path.join(base, subdir, name)
            save_wav_mono_as_stereo(path, samples)

    print("\n" + "=" * 60)
    total = len(music_tracks) + len(sfx)
    print(f"Audio generation complete! {total} files created.")
    print(f"Output: {os.path.abspath(base)}")


if __name__ == "__main__":
    main()
