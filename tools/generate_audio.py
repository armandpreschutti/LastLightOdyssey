"""
Last Light Odyssey - Procedural Audio Generator
Creates retro sci-fi audio files using procedural synthesis:
- 3 music tracks (ambient loops)
- 27 sound effects (UI, combat, alarms, movement)
All output: 16-bit PCM WAV, 22050 Hz, mono
"""

import numpy as np
import wave
import os
import math

SAMPLE_RATE = 22050
BIT_DEPTH = 16

def ensure_dir(path):
    """Ensure directory exists"""
    os.makedirs(path, exist_ok=True)

def save_wav(filepath, samples):
    """Save numpy array as 16-bit PCM WAV file"""
    ensure_dir(os.path.dirname(filepath))
    
    # Normalize to [-1, 1] range
    samples = np.clip(samples, -1.0, 1.0)
    
    # Convert to 16-bit integers
    samples_int = (samples * 32767).astype(np.int16)
    
    with wave.open(filepath, 'w') as wav_file:
        wav_file.setnchannels(1)  # Mono
        wav_file.setsampwidth(2)   # 16-bit = 2 bytes
        wav_file.setframerate(SAMPLE_RATE)
        wav_file.writeframes(samples_int.tobytes())

def generate_sine(freq, duration, sample_rate=SAMPLE_RATE):
    """Generate sine wave"""
    t = np.linspace(0, duration, int(sample_rate * duration), False)
    return np.sin(2 * np.pi * freq * t)

def generate_square(freq, duration, duty=0.5, sample_rate=SAMPLE_RATE):
    """Generate square wave"""
    t = np.linspace(0, duration, int(sample_rate * duration), False)
    phase = (2 * np.pi * freq * t) % (2 * np.pi)
    return np.where(phase < 2 * np.pi * duty, 1.0, -1.0)

def generate_noise(duration, sample_rate=SAMPLE_RATE):
    """Generate white noise"""
    samples = int(sample_rate * duration)
    return np.random.uniform(-1.0, 1.0, samples)

def apply_envelope(samples, attack=0.01, decay=0.1, sustain=0.7, release=0.1):
    """Apply ADSR envelope"""
    total_samples = len(samples)
    attack_samples = int(SAMPLE_RATE * attack)
    decay_samples = int(SAMPLE_RATE * decay)
    release_samples = int(SAMPLE_RATE * release)
    sustain_samples = total_samples - attack_samples - decay_samples - release_samples
    
    # Ensure we don't exceed total_samples
    if sustain_samples < 0:
        # Adjust release if needed
        release_samples = max(0, total_samples - attack_samples - decay_samples)
        sustain_samples = 0
    
    envelope = np.ones(total_samples)
    
    # Attack
    if attack_samples > 0 and attack_samples <= total_samples:
        envelope[:attack_samples] = np.linspace(0, 1, attack_samples)
    
    # Decay
    if decay_samples > 0:
        start = attack_samples
        end = min(start + decay_samples, total_samples - release_samples)
        if end > start:
            decay_len = end - start
            envelope[start:end] = np.linspace(1, sustain, decay_len)
    
    # Sustain
    if sustain_samples > 0:
        start = attack_samples + decay_samples
        end = start + sustain_samples
        if end <= total_samples:
            envelope[start:end] = sustain
    
    # Release
    if release_samples > 0:
        start = total_samples - release_samples
        if start >= 0:
            sustain_val = sustain if sustain_samples > 0 else envelope[start] if start < total_samples else 0
            envelope[start:] = np.linspace(sustain_val, 0, release_samples)
    
    return samples * envelope

def apply_lowpass(samples, cutoff_freq, sample_rate=SAMPLE_RATE):
    """Simple low-pass filter"""
    # Simple RC filter approximation
    alpha = 1.0 / (1.0 + 2 * np.pi * cutoff_freq / sample_rate)
    filtered = np.zeros_like(samples)
    filtered[0] = samples[0]
    for i in range(1, len(samples)):
        filtered[i] = alpha * samples[i] + (1 - alpha) * filtered[i-1]
    return filtered

def apply_highpass(samples, cutoff_freq, sample_rate=SAMPLE_RATE):
    """Simple high-pass filter"""
    alpha = 1.0 / (1.0 + 2 * np.pi * cutoff_freq / sample_rate)
    filtered = np.zeros_like(samples)
    filtered[0] = samples[0]
    for i in range(1, len(samples)):
        filtered[i] = alpha * (filtered[i-1] + samples[i] - samples[i-1])
    return filtered

# ============================================================================
# MUSIC TRACKS
# ============================================================================

def generate_title_ambient():
    """~30s loop, slow dark ambient drone - improved version"""
    duration = 30.0
    samples = int(SAMPLE_RATE * duration)
    t = np.linspace(0, duration, samples, False)
    output = np.zeros(samples)
    
    # Root note: D (73.42 Hz) - dark and mysterious
    root_freq = 73.42
    
    # Layer 1: Deep bass drone with harmonics (additive synthesis)
    for harmonic in [1, 2, 3, 4]:
        freq = root_freq * harmonic
        wave = generate_sine(freq, duration)
        # Slow vibrato (LFO)
        vibrato = generate_sine(0.15, duration) * 0.02 + 1.0
        wave = wave * vibrato
        # Harmonic volume decreases
        volume = 0.25 / harmonic
        output += wave * volume
    
    # Layer 2: Mid-range pad with chord tones (Dm chord: D, F, A)
    chord_notes = [root_freq, root_freq * 1.2, root_freq * 1.5]  # D, F, A
    for note_freq in chord_notes:
        pad = generate_sine(note_freq, duration)
        # Slow phasing effect
        phase_lfo = generate_sine(0.08, duration) * 0.1
        pad = np.sin(2 * np.pi * note_freq * t + phase_lfo)
        pad = apply_lowpass(pad, 800)
        output += pad * 0.12
    
    # Layer 3: High shimmer (filtered noise with resonance)
    shimmer = generate_noise(duration)
    shimmer = apply_lowpass(shimmer, 1200)
    # Add resonance by emphasizing certain frequencies
    for freq in [440, 880, 1320]:
        resonance = generate_sine(freq, duration) * 0.03
        output += resonance
    output += shimmer * 0.08
    
    # Layer 4: Subtle rhythmic pulse (very slow, every 8 seconds)
    pulse_env = generate_sine(0.125, duration) * 0.15 + 0.85  # 8 second cycle
    output *= pulse_env
    
    # Gentle fade in/out for seamless loop
    fade_samples = int(SAMPLE_RATE * 2.0)
    fade = np.linspace(0, 1, fade_samples)
    output[:fade_samples] *= fade
    output[-fade_samples:] *= fade[::-1]
    
    # Normalize and apply gentle compression
    output = np.clip(output * 0.7, -1.0, 1.0)
    return output

def generate_management_ambient():
    """~30s loop, gentle pulse - improved version with melody"""
    duration = 30.0
    samples = int(SAMPLE_RATE * duration)
    t = np.linspace(0, duration, samples, False)
    output = np.zeros(samples)
    
    # Root: A (220 Hz) - warm and stable
    root_freq = 220.0
    
    # Layer 1: Warm pad with major chord (A, C#, E)
    chord_notes = [root_freq, root_freq * 1.26, root_freq * 1.5]  # A, C#, E
    for i, note_freq in enumerate(chord_notes):
        pad = generate_sine(note_freq, duration)
        # Add harmonics for warmth
        for harmonic in [2, 3]:
            harmonic_wave = generate_sine(note_freq * harmonic, duration) * (0.15 / harmonic)
            pad += harmonic_wave
        # Gentle tremolo
        tremolo = generate_sine(2.0, duration) * 0.1 + 0.9
        pad = pad * tremolo
        volume = 0.18 if i == 0 else 0.12
        output += pad * volume
    
    # Layer 2: Gentle arpeggio pattern (every 4 seconds)
    arp_notes = [root_freq, root_freq * 1.26, root_freq * 1.5, root_freq * 2.0]  # A, C#, E, A
    arp_duration = 4.0  # 4 seconds per cycle
    arp_cycles = int(duration / arp_duration)
    arp_output = np.zeros(samples)
    
    for cycle in range(arp_cycles):
        cycle_start = cycle * arp_duration
        note_duration = arp_duration / len(arp_notes)
        for i, note_freq in enumerate(arp_notes):
            note_start = cycle_start + i * note_duration
            note_end = note_start + note_duration
            if note_end <= duration:
                note_samples = int(SAMPLE_RATE * note_duration)
                note_t = np.linspace(0, note_duration, note_samples, False)
                note_wave = generate_sine(note_freq, note_duration) * 0.15
                # Soft attack
                note_wave[:int(SAMPLE_RATE * 0.1)] *= np.linspace(0, 1, int(SAMPLE_RATE * 0.1))
                start_idx = int(SAMPLE_RATE * note_start)
                end_idx = start_idx + note_samples
                if end_idx <= len(arp_output):
                    arp_output[start_idx:end_idx] += note_wave
    
    output += arp_output
    
    # Layer 3: Subtle bass pulse (every 2 seconds)
    pulse_freq = 0.5  # 2 second cycle
    pulse = generate_sine(root_freq * 0.5, duration)  # Octave below root
    pulse_env = generate_sine(pulse_freq, duration) * 0.2 + 0.8
    pulse = pulse * pulse_env * 0.15
    output += pulse
    
    # Fade for seamless loop
    fade_samples = int(SAMPLE_RATE * 2.0)
    fade = np.linspace(0, 1, fade_samples)
    output[:fade_samples] *= fade
    output[-fade_samples:] *= fade[::-1]
    
    # Normalize
    output = np.clip(output * 0.75, -1.0, 1.0)
    return output

def generate_combat_ambient():
    """~20s loop, tense 120 BPM - improved version"""
    duration = 20.0
    samples = int(SAMPLE_RATE * duration)
    t = np.linspace(0, duration, samples, False)
    output = np.zeros(samples)
    
    # 120 BPM = 2 beats per second
    bpm = 120.0
    beat_freq = bpm / 60.0  # 2.0 Hz
    
    # Root: E (82.41 Hz) - tense and aggressive
    root_freq = 82.41
    
    # Layer 1: Aggressive bass drone with distortion-like harmonics
    bass = generate_sine(root_freq, duration)
    # Add odd harmonics for aggressive tone (square wave-like)
    for harmonic in [3, 5, 7]:
        harmonic_wave = generate_sine(root_freq * harmonic, duration) * (0.2 / harmonic)
        bass += harmonic_wave
    # Slight detuning for thickness
    detuned = generate_sine(root_freq * 1.01, duration) * 0.1
    bass += detuned
    bass = apply_lowpass(bass, 300)
    output += bass * 0.25
    
    # Layer 2: Rhythmic kick pulse (120 BPM)
    kick_pattern = []
    beats_per_measure = 4
    measures = int(duration * beat_freq / beats_per_measure)
    for measure in range(measures):
        for beat in range(beats_per_measure):
            beat_time = (measure * beats_per_measure + beat) / beat_freq
            if beat_time < duration:
                # Kick on beat 1, softer on beat 3
                volume = 0.3 if beat == 0 else (0.15 if beat == 2 else 0.0)
                if volume > 0:
                    kick_duration = 0.1
                    kick_samples = int(SAMPLE_RATE * kick_duration)
                    kick_freq = 60.0  # Low thump
                    kick_t = np.linspace(0, kick_duration, kick_samples, False)
                    kick = generate_sine(kick_freq, kick_duration)
                    # Fast decay envelope
                    kick_env = np.exp(-kick_t * 20)
                    kick = kick * kick_env * volume
                    start_idx = int(SAMPLE_RATE * beat_time)
                    end_idx = min(start_idx + kick_samples, len(output))
                    if start_idx < len(output):
                        output[start_idx:end_idx] += kick[:end_idx-start_idx]
    
    # Layer 3: Tense mid-range pad (minor chord: E, G, B)
    minor_chord = [root_freq, root_freq * 1.2, root_freq * 1.5]  # E, G, B
    for note_freq in minor_chord:
        pad = generate_sine(note_freq, duration)
        # Add harmonics
        for harmonic in [2, 3]:
            pad += generate_sine(note_freq * harmonic, duration) * (0.1 / harmonic)
        # Rhythmic gating (every 2 beats)
        gate_freq = beat_freq / 2.0  # 1 Hz
        gate = generate_square(gate_freq, duration, duty=0.6)
        pad = pad * gate * 0.15
        output += pad
    
    # Layer 4: High frequency tension (filtered noise bursts)
    tension = generate_noise(duration)
    tension = apply_highpass(tension, 2000)
    tension = apply_lowpass(tension, 5000)
    # Rhythmic bursts
    burst_env = generate_square(beat_freq * 2, duration, duty=0.2)
    tension = tension * burst_env * 0.12
    output += tension
    
    # Layer 5: Subtle rhythmic accent (every 4 beats)
    accent_freq = beat_freq / 4.0  # 0.5 Hz
    accent = generate_sine(root_freq * 2, duration) * 0.1
    accent_env = generate_square(accent_freq, duration, duty=0.1)
    accent = accent * accent_env
    output += accent
    
    # Fade for seamless loop
    fade_samples = int(SAMPLE_RATE * 1.0)
    fade = np.linspace(0, 1, fade_samples)
    output[:fade_samples] *= fade
    output[-fade_samples:] *= fade[::-1]
    
    # Normalize and apply slight compression
    output = np.clip(output * 0.8, -1.0, 1.0)
    return output

# ============================================================================
# UI SOUNDS
# ============================================================================

def generate_ui_click():
    """0.08s, square wave blip"""
    duration = 0.08
    freq = 800
    click = generate_square(freq, duration, duty=0.3)
    click = apply_lowpass(click, 2000)
    return apply_envelope(click, attack=0.001, decay=0.02, sustain=0.0, release=0.06)

def generate_ui_hover():
    """0.05s, soft sine tick"""
    duration = 0.05
    freq = 600
    hover = generate_sine(freq, duration)
    hover = apply_lowpass(hover, 3000)
    return apply_envelope(hover, attack=0.001, decay=0.01, sustain=0.0, release=0.04)

def generate_ui_dialog_open():
    """0.15s, rising sweep"""
    duration = 0.15
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), False)
    # Frequency sweep from 200 to 800 Hz
    freq_sweep = 200 + (600 * t / duration)
    phase = np.cumsum(2 * np.pi * freq_sweep / SAMPLE_RATE)
    sweep = np.sin(phase)
    sweep = apply_lowpass(sweep, 2000)
    return apply_envelope(sweep, attack=0.02, decay=0.05, sustain=0.0, release=0.08)

def generate_ui_dialog_close():
    """0.12s, descending sweep"""
    duration = 0.12
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), False)
    # Frequency sweep from 800 to 200 Hz
    freq_sweep = 800 - (600 * t / duration)
    phase = np.cumsum(2 * np.pi * freq_sweep / SAMPLE_RATE)
    sweep = np.sin(phase)
    sweep = apply_lowpass(sweep, 2000)
    return apply_envelope(sweep, attack=0.01, decay=0.04, sustain=0.0, release=0.07)

def generate_ui_end_turn():
    """0.2s, two-tone beep"""
    duration = 0.2
    beep1 = generate_sine(440, 0.1)  # A4
    beep2 = generate_sine(554, 0.1)  # C#5
    silence = np.zeros(int(SAMPLE_RATE * 0.05))
    output = np.concatenate([beep1, silence, beep2])
    output = apply_lowpass(output, 3000)
    return apply_envelope(output, attack=0.01, decay=0.05, sustain=0.0, release=0.14)

def generate_ui_transition():
    """0.4s, filtered noise whoosh"""
    duration = 0.4
    noise = generate_noise(duration)
    # Frequency sweep filter
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), False)
    cutoff = 200 + (8000 * t / duration)
    # Approximate with multiple lowpass passes
    filtered = noise
    for _ in range(3):
        filtered = apply_lowpass(filtered, 5000)
    return apply_envelope(filtered, attack=0.05, decay=0.15, sustain=0.0, release=0.2)

# ============================================================================
# COMBAT SOUNDS
# ============================================================================

def generate_combat_fire():
    """0.15s, laser burst"""
    duration = 0.15
    # Sharp attack with noise
    noise = generate_noise(duration) * 0.3
    noise = apply_highpass(noise, 2000)
    
    # Pitch sweep
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), False)
    freq_sweep = 800 - (400 * t / duration)
    phase = np.cumsum(2 * np.pi * freq_sweep / SAMPLE_RATE)
    sweep = np.sin(phase) * 0.5
    
    output = noise + sweep
    return apply_envelope(output, attack=0.001, decay=0.05, sustain=0.0, release=0.1)

def generate_combat_hit():
    """0.2s, noise + low thump"""
    duration = 0.2
    # High frequency noise
    noise = generate_noise(duration) * 0.4
    noise = apply_highpass(noise, 1000)
    
    # Low thump
    thump = generate_sine(60, duration) * 0.6
    thump = apply_lowpass(thump, 200)
    
    output = noise + thump
    return apply_envelope(output, attack=0.001, decay=0.05, sustain=0.0, release=0.15)

def generate_combat_miss():
    """0.25s, sine ricochet"""
    duration = 0.25
    # Rising then falling pitch
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), False)
    freq_peak = duration * 0.3
    freq = 400 + (200 * np.exp(-((t - freq_peak) ** 2) / (2 * 0.05 ** 2)))
    phase = np.cumsum(2 * np.pi * freq / SAMPLE_RATE)
    ricochet = np.sin(phase) * 0.5
    ricochet = apply_lowpass(ricochet, 1500)
    return apply_envelope(ricochet, attack=0.01, decay=0.1, sustain=0.0, release=0.14)

def generate_combat_overwatch():
    """0.2s, sharp snap"""
    duration = 0.2
    # Sharp click with resonance
    click = generate_square(1200, 0.02, duty=0.1)
    click = apply_lowpass(click, 3000)
    silence = np.zeros(int(SAMPLE_RATE * (duration - 0.02)))
    output = np.concatenate([click, silence])
    return apply_envelope(output, attack=0.001, decay=0.05, sustain=0.0, release=0.15)

def generate_combat_turret_fire():
    """0.12s, rapid square burst"""
    duration = 0.12
    # Rapid square wave burst
    burst = generate_square(800, duration, duty=0.2)
    burst = apply_lowpass(burst, 2500)
    return apply_envelope(burst, attack=0.001, decay=0.03, sustain=0.0, release=0.09)

def generate_combat_heal():
    """0.3s, rising arpeggio chime"""
    duration = 0.3
    # Arpeggio: C, E, G (major triad)
    notes = [261.63, 329.63, 392.00]  # C4, E4, G4
    note_duration = duration / 3
    output = np.array([])
    for note in notes:
        chime = generate_sine(note, note_duration)
        chime = apply_lowpass(chime, 4000)
        output = np.concatenate([output, chime])
    return apply_envelope(output, attack=0.02, decay=0.08, sustain=0.0, release=0.2)

def generate_combat_charge():
    """0.3s, rush rumble"""
    duration = 0.3
    # Low frequency rumble with rising intensity
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), False)
    freq = 80 + (40 * t / duration)
    phase = np.cumsum(2 * np.pi * freq / SAMPLE_RATE)
    rumble = np.sin(phase) * 0.6
    rumble = apply_lowpass(rumble, 300)
    
    # Add noise texture
    noise = generate_noise(duration) * 0.2
    noise = apply_lowpass(noise, 500)
    
    output = rumble + noise
    intensity = t / duration
    return apply_envelope(output * intensity, attack=0.05, decay=0.1, sustain=0.0, release=0.15)

def generate_combat_execute():
    """0.25s, deep bass kill shot"""
    duration = 0.25
    # Deep bass hit
    bass = generate_sine(50, duration) * 0.8
    bass = apply_lowpass(bass, 150)
    
    # Sharp attack
    attack = generate_noise(0.05) * 0.5
    attack = apply_highpass(attack, 3000)
    silence = np.zeros(int(SAMPLE_RATE * (duration - 0.05)))
    attack_full = np.concatenate([attack, silence])
    
    output = bass + attack_full
    return apply_envelope(output, attack=0.001, decay=0.1, sustain=0.0, release=0.15)

def generate_combat_precision():
    """0.35s, crack + echo"""
    duration = 0.35
    # Sharp crack
    crack = generate_noise(0.1) * 0.6
    crack = apply_highpass(crack, 2000)
    
    # Echo (delayed, quieter)
    echo_delay = int(SAMPLE_RATE * 0.15)
    echo = np.concatenate([np.zeros(echo_delay), crack * 0.3])
    if len(echo) < len(crack):
        echo = np.pad(echo, (0, len(crack) - len(echo)))
    elif len(echo) > len(crack):
        echo = echo[:len(crack)]
    
    output = crack + echo
    return apply_envelope(output, attack=0.001, decay=0.1, sustain=0.0, release=0.25)

def generate_combat_damage():
    """0.15s, short noise thud"""
    duration = 0.15
    # Noise thud
    noise = generate_noise(duration) * 0.4
    noise = apply_lowpass(noise, 800)
    
    # Low thump
    thump = generate_sine(80, duration) * 0.3
    
    output = noise + thump
    return apply_envelope(output, attack=0.001, decay=0.05, sustain=0.0, release=0.1)

def generate_combat_death():
    """0.5s, descending tone + fade"""
    duration = 0.5
    # Descending tone
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), False)
    freq = 300 - (250 * t / duration)
    phase = np.cumsum(2 * np.pi * freq / SAMPLE_RATE)
    tone = np.sin(phase) * 0.5
    tone = apply_lowpass(tone, 1000)
    return apply_envelope(tone, attack=0.01, decay=0.2, sustain=0.0, release=0.29)

def generate_combat_enemy_alert():
    """0.3s, two high staccato beeps"""
    duration = 0.3
    beep1 = generate_sine(1000, 0.08)
    silence1 = np.zeros(int(SAMPLE_RATE * 0.05))
    beep2 = generate_sine(1200, 0.08)
    silence2 = np.zeros(int(SAMPLE_RATE * (duration - 0.08 - 0.05 - 0.08)))
    output = np.concatenate([beep1, silence1, beep2, silence2])
    output = apply_lowpass(output, 4000)
    return apply_envelope(output, attack=0.001, decay=0.02, sustain=0.0, release=0.06)

# ============================================================================
# ALARM SOUNDS
# ============================================================================

def generate_alarm_cryo():
    """0.6s, oscillating siren"""
    duration = 0.6
    # Oscillating siren (frequency modulation)
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), False)
    mod_freq = 3.0  # 3 Hz oscillation
    freq_base = 600
    freq_variation = 200
    freq = freq_base + freq_variation * np.sin(2 * np.pi * mod_freq * t)
    phase = np.cumsum(2 * np.pi * freq / SAMPLE_RATE)
    siren = np.sin(phase) * 0.7
    siren = apply_lowpass(siren, 3000)
    return apply_envelope(siren, attack=0.05, decay=0.2, sustain=0.3, release=0.05)

def generate_alarm_game_over():
    """1.5s, descending minor chord"""
    duration = 1.5
    # Minor chord: A, C, E (A minor)
    notes = [220.00, 261.63, 329.63]  # A3, C4, E4
    output = np.zeros(int(SAMPLE_RATE * duration))
    for note in notes:
        chord = generate_sine(note, duration) * 0.3
        output += chord
    output = apply_lowpass(output, 2000)
    # Descending pitch
    t = np.linspace(0, duration, len(output), False)
    pitch_bend = 1.0 - (0.3 * t / duration)
    output = output * pitch_bend
    return apply_envelope(output, attack=0.1, decay=0.5, sustain=0.0, release=0.9)

def generate_alarm_victory():
    """1.0s, ascending major triad"""
    duration = 1.0
    # Major triad: C, E, G (C major)
    notes = [261.63, 329.63, 392.00]  # C4, E4, G4
    output = np.zeros(int(SAMPLE_RATE * duration))
    for note in notes:
        chord = generate_sine(note, duration) * 0.3
        output += chord
    output = apply_lowpass(output, 3000)
    # Ascending pitch
    t = np.linspace(0, duration, len(output), False)
    pitch_bend = 1.0 + (0.2 * t / duration)
    output = output * pitch_bend
    return apply_envelope(output, attack=0.05, decay=0.3, sustain=0.0, release=0.65)

# ============================================================================
# MOVEMENT SOUNDS
# ============================================================================

def generate_move_step():
    """0.08s, filtered noise tick"""
    duration = 0.08
    noise = generate_noise(duration) * 0.5
    noise = apply_lowpass(noise, 1000)
    noise = apply_highpass(noise, 200)
    return apply_envelope(noise, attack=0.001, decay=0.02, sustain=0.0, release=0.06)

def generate_move_extraction():
    """1.0s, rising shimmer"""
    duration = 1.0
    # Rising shimmer with multiple frequencies
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), False)
    output = np.zeros(len(t))
    
    # Multiple harmonics rising
    for i, freq_base in enumerate([200, 400, 600]):
        freq = freq_base + (freq_base * 0.5 * t / duration)
        phase = np.cumsum(2 * np.pi * freq / SAMPLE_RATE)
        harmonic = np.sin(phase) * (0.2 / (i + 1))
        output += harmonic
    
    # Add noise shimmer
    noise = generate_noise(duration) * 0.1
    noise = apply_highpass(noise, 2000)
    output += noise
    
    output = apply_lowpass(output, 4000)
    return apply_envelope(output, attack=0.1, decay=0.3, sustain=0.0, release=0.6)

def generate_move_jump():
    """0.8s, low sweep + whoosh"""
    duration = 0.8
    # Low frequency sweep
    t = np.linspace(0, duration, int(SAMPLE_RATE * duration), False)
    freq = 100 - (80 * t / duration)
    phase = np.cumsum(2 * np.pi * freq / SAMPLE_RATE)
    sweep = np.sin(phase) * 0.4
    sweep = apply_lowpass(sweep, 500)
    
    # Whoosh noise
    whoosh = generate_noise(duration) * 0.3
    whoosh = apply_lowpass(whoosh, 2000)
    whoosh = apply_highpass(whoosh, 300)
    
    output = sweep + whoosh
    return apply_envelope(output, attack=0.05, decay=0.2, sustain=0.0, release=0.55)

# ============================================================================
# MAIN
# ============================================================================

def main():
    print("Generating Last Light Odyssey audio files...")
    print("=" * 60)
    
    base_path = "../assets/audio"
    
    # Music tracks
    print("\n[MUSIC]")
    music_path = os.path.join(base_path, "music")
    print("  Generating title_ambient.wav...")
    save_wav(os.path.join(music_path, "title_ambient.wav"), generate_title_ambient())
    print("  Generating management_ambient.wav...")
    save_wav(os.path.join(music_path, "management_ambient.wav"), generate_management_ambient())
    print("  Generating combat_ambient.wav...")
    save_wav(os.path.join(music_path, "combat_ambient.wav"), generate_combat_ambient())
    
    # UI sounds
    print("\n[UI SOUNDS]")
    ui_path = os.path.join(base_path, "sfx", "ui")
    print("  Generating click.wav...")
    save_wav(os.path.join(ui_path, "click.wav"), generate_ui_click())
    print("  Generating hover.wav...")
    save_wav(os.path.join(ui_path, "hover.wav"), generate_ui_hover())
    print("  Generating dialog_open.wav...")
    save_wav(os.path.join(ui_path, "dialog_open.wav"), generate_ui_dialog_open())
    print("  Generating dialog_close.wav...")
    save_wav(os.path.join(ui_path, "dialog_close.wav"), generate_ui_dialog_close())
    print("  Generating end_turn.wav...")
    save_wav(os.path.join(ui_path, "end_turn.wav"), generate_ui_end_turn())
    print("  Generating transition.wav...")
    save_wav(os.path.join(ui_path, "transition.wav"), generate_ui_transition())
    
    # Combat sounds
    print("\n[COMBAT SOUNDS]")
    combat_path = os.path.join(base_path, "sfx", "combat")
    print("  Generating fire.wav...")
    save_wav(os.path.join(combat_path, "fire.wav"), generate_combat_fire())
    print("  Generating hit.wav...")
    save_wav(os.path.join(combat_path, "hit.wav"), generate_combat_hit())
    print("  Generating miss.wav...")
    save_wav(os.path.join(combat_path, "miss.wav"), generate_combat_miss())
    print("  Generating overwatch.wav...")
    save_wav(os.path.join(combat_path, "overwatch.wav"), generate_combat_overwatch())
    print("  Generating turret_fire.wav...")
    save_wav(os.path.join(combat_path, "turret_fire.wav"), generate_combat_turret_fire())
    print("  Generating heal.wav...")
    save_wav(os.path.join(combat_path, "heal.wav"), generate_combat_heal())
    print("  Generating charge.wav...")
    save_wav(os.path.join(combat_path, "charge.wav"), generate_combat_charge())
    print("  Generating execute.wav...")
    save_wav(os.path.join(combat_path, "execute.wav"), generate_combat_execute())
    print("  Generating precision.wav...")
    save_wav(os.path.join(combat_path, "precision.wav"), generate_combat_precision())
    print("  Generating damage.wav...")
    save_wav(os.path.join(combat_path, "damage.wav"), generate_combat_damage())
    print("  Generating death.wav...")
    save_wav(os.path.join(combat_path, "death.wav"), generate_combat_death())
    print("  Generating enemy_alert.wav...")
    save_wav(os.path.join(combat_path, "enemy_alert.wav"), generate_combat_enemy_alert())
    
    # Alarm sounds
    print("\n[ALARM SOUNDS]")
    alarm_path = os.path.join(base_path, "sfx", "alarms")
    print("  Generating cryo_alarm.wav...")
    save_wav(os.path.join(alarm_path, "cryo_alarm.wav"), generate_alarm_cryo())
    print("  Generating game_over.wav...")
    save_wav(os.path.join(alarm_path, "game_over.wav"), generate_alarm_game_over())
    print("  Generating victory.wav...")
    save_wav(os.path.join(alarm_path, "victory.wav"), generate_alarm_victory())
    
    # Movement sounds
    print("\n[MOVEMENT SOUNDS]")
    movement_path = os.path.join(base_path, "sfx", "movement")
    print("  Generating footstep.wav...")
    save_wav(os.path.join(movement_path, "footstep.wav"), generate_move_step())
    print("  Generating extraction_beam.wav...")
    save_wav(os.path.join(movement_path, "extraction_beam.wav"), generate_move_extraction())
    print("  Generating jump_warp.wav...")
    save_wav(os.path.join(movement_path, "jump_warp.wav"), generate_move_jump())
    
    print("\n" + "=" * 60)
    print("Audio generation complete! 27 files created.")
    print(f"All files saved to: {base_path}")

if __name__ == "__main__":
    main()
