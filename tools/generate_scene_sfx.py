#!/usr/bin/env python3
"""
Generate sci-fi scene SFX for Last Light Odyssey.
Uses Python's wave module for WAV synthesis, then ffmpeg to convert to MP3.
Updated with separate scene channel support and louder volume.
"""

import wave
import struct
import math
import random
import os
import subprocess
import sys

SAMPLE_RATE = 44100
BASE_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                        "assets", "audio", "sfx", "scenes")


def generate_samples(duration_sec, generator_func):
    """Generate audio samples using a generator function."""
    num_samples = int(SAMPLE_RATE * duration_sec)
    samples = []
    for i in range(num_samples):
        t = i / SAMPLE_RATE
        val = generator_func(t, duration_sec)
        val = max(-1.0, min(1.0, val))
        samples.append(val)
    return samples


def apply_envelope(samples, attack=0.05, decay=0.1, sustain_level=0.7, release=0.3):
    """Apply ADSR envelope to samples."""
    n = len(samples)
    attack_samples = int(attack * SAMPLE_RATE)
    decay_samples = int(decay * SAMPLE_RATE)
    release_samples = int(release * SAMPLE_RATE)
    sustain_samples = n - attack_samples - decay_samples - release_samples

    if sustain_samples < 0:
        sustain_samples = 0
        release_samples = n - attack_samples - decay_samples
        if release_samples < 0:
            release_samples = 0
            decay_samples = n - attack_samples

    result = []
    for i in range(n):
        if i < attack_samples:
            env = i / max(1, attack_samples)
        elif i < attack_samples + decay_samples:
            progress = (i - attack_samples) / max(1, decay_samples)
            env = 1.0 - (1.0 - sustain_level) * progress
        elif i < attack_samples + decay_samples + sustain_samples:
            env = sustain_level
        else:
            progress = (i - attack_samples - decay_samples - sustain_samples) / max(1, release_samples)
            env = sustain_level * (1.0 - progress)
        result.append(samples[i] * env)
    return result


def white_noise(amplitude=1.0):
    """Generate white noise sample."""
    return random.uniform(-amplitude, amplitude)


def sine_wave(t, freq):
    """Generate sine wave sample."""
    return math.sin(2 * math.pi * freq * t)


def saw_wave(t, freq):
    """Generate sawtooth wave sample."""
    phase = (t * freq) % 1.0
    return 2.0 * phase - 1.0


def square_wave(t, freq):
    """Generate square wave sample."""
    return 1.0 if (t * freq) % 1.0 < 0.5 else -1.0


def mix(*components):
    """Mix multiple audio components."""
    return sum(components) / len(components)


def save_wav(samples, filepath):
    """Save samples to WAV file."""
    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    with wave.open(filepath, 'w') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        for s in samples:
            # INCREASED VOLUME: 0.95 (near max) instead of 0.8 (-6dB)
            # User reported sounds were too quiet
            val = int(s * 32767 * 0.95)
            wav.writeframes(struct.pack('<h', max(-32768, min(32767, val))))


def wav_to_mp3(wav_path, mp3_path):
    """Convert WAV to MP3 using ffmpeg."""
    subprocess.run([
        'ffmpeg', '-y', '-i', wav_path,
        '-codec:a', 'libmp3lame', '-b:a', '192k',
        '-ar', '44100', mp3_path
    ], capture_output=True, check=True)
    os.remove(wav_path)


def generate_sfx(name, subdir, duration, generator_func,
                 attack=0.05, decay=0.1, sustain=0.7, release=0.3):
    """Generate a single SFX file."""
    out_dir = os.path.join(BASE_DIR, subdir)
    wav_path = os.path.join(out_dir, name.replace('.mp3', '.wav'))
    mp3_path = os.path.join(out_dir, name)

    print(f"  Generating {subdir}/{name}...")
    samples = generate_samples(duration, generator_func)
    samples = apply_envelope(samples, attack, decay, sustain, release)
    save_wav(samples, wav_path)
    wav_to_mp3(wav_path, mp3_path)


# ============================================================================
# NEW SFX GENERATORS (BEAM, EXTRACTION, OUTPOST)
# ============================================================================

def beam_gen(t, dur):
    """Sci-fi teleport beam sound."""
    # Rising/falling shimmer
    shimmer = sine_wave(t, 200 + 800 * sine_wave(t, 10)) * 0.4
    # High frequency carrier
    carrier = sine_wave(t, 2000 + 500 * sine_wave(t, 20)) * 0.15
    # Energy swoosh
    progress = t / dur
    whoosh = white_noise(0.3) * (0.5 + 0.5 * sine_wave(t, 2)) * max(0, 1 - abs(progress - 0.5) * 4)
    # Bass hum
    hum = sine_wave(t, 100) * 0.3
    return mix(shimmer, carrier, whoosh, hum)

def extraction_complete_gen(t, dur):
    """Mission success fanfare."""
    progress = t / dur
    # Major chord fanfare
    c = sine_wave(t, 523) * 0.3
    e = sine_wave(t, 659) * 0.25
    g = sine_wave(t, 784) * 0.25
    c_high = sine_wave(t, 1046) * 0.2
    # Ascending visual
    sweep = sine_wave(t, 400 + 400 * progress) * 0.15
    # Confirmation chime
    chime = sine_wave(t, 1500) * 0.15 * (1 if progress > 0.8 else 0)
    return mix(c, e, g, c_high, sweep, chime)

def extraction_failed_gen(t, dur):
    """Mission failure, team lost."""
    progress = t / dur
    # Dissonant fall
    fall = sine_wave(t, 400 * (1 - progress * 0.5)) * 0.3
    # Warning buzzer
    buzz = square_wave(t, 150) * 0.2 * (1 if (t * 4) % 1.0 < 0.5 else 0)
    # Static failure
    static = white_noise(0.3) * progress * 0.3
    # Low thud
    thud = sine_wave(t, 60 * (1 - progress)) * 0.4
    return mix(fall, buzz, static, thud)

def outpost_arrival_gen(t, dur):
    """Docking with trading outpost."""
    # Mechanical docking latches
    latch = square_wave(t, 60) * 0.2 * (1 if (t * 2) % 1.0 < 0.1 else 0)
    # Station hum
    hum = sine_wave(t, 120) * 0.25
    # Communication bleeps
    bleep = sine_wave(t, 1200 + 400 * random.choice([-1, 0, 1])) * 0.15 * (1 if random.random() < 0.1 else 0)
    # Air hiss
    hiss = white_noise(0.2) * (1 - t/dur) * 0.3
    return mix(latch, hum, bleep, hiss)

def voyage_failure_gen(t, dur):
    """Final game over screen (recap)."""
    # Simply a longer, more final version of extinction
    progress = t / dur
    # Dying drone
    drone = sine_wave(t, 100 * (1 - progress * 0.2)) * 0.4
    # Wind/Vacuum
    wind = white_noise(0.2) * (0.3 + 0.3 * sine_wave(t, 0.2)) * 0.3
    # Sad toll
    toll = sine_wave(t, 220) * 0.3 * max(0, 1 - (t % 2.0))
    return mix(drone, wind, toll)


# ============================================================================
# EVENT SCENE SFX GENERATORS
# ============================================================================

def solar_flare_gen(t, dur):
    """Intense solar radiation - energy surge with warning alarm."""
    # Rising energy sweep
    sweep_freq = 200 + 800 * (t / dur)
    energy = sine_wave(t, sweep_freq) * 0.4
    # Crackling radiation
    crackle = white_noise(0.3) * (0.5 + 0.5 * sine_wave(t, 3))
    # Warning alarm
    alarm_freq = 880 if (t * 4) % 1.0 < 0.5 else 660
    alarm = sine_wave(t, alarm_freq) * 0.2 * (1 if (t * 2) % 1.0 < 0.7 else 0)
    # Low rumble
    rumble = sine_wave(t, 60 + 20 * sine_wave(t, 0.5)) * 0.3
    return mix(energy, crackle, alarm, rumble)


def meteor_shower_gen(t, dur):
    """Meteor impacts on hull - thuds, debris, warnings."""
    # Impact thuds at random-ish intervals
    impact_phase = (t * 3.7) % 1.0
    impact = sine_wave(t, 80) * max(0, 1.0 - impact_phase * 8) * 0.5
    # Debris rattling
    debris = white_noise(0.25) * (0.3 + 0.7 * abs(sine_wave(t, 5.5)))
    # Hull stress
    stress = sine_wave(t, 150 + 50 * sine_wave(t, 1.3)) * 0.2
    # Warning beep
    beep = sine_wave(t, 1200) * 0.15 * (1 if (t * 6) % 1.0 < 0.1 else 0)
    return mix(impact, debris, stress, beep)


def disease_outbreak_gen(t, dur):
    """Medical alarms, quarantine sirens."""
    # Biohazard siren (rising/falling)
    siren_freq = 600 + 200 * sine_wave(t, 1.5)
    siren = sine_wave(t, siren_freq) * 0.35
    # Heartbeat monitor beeps
    heartbeat_phase = (t * 1.2) % 1.0
    heartbeat = sine_wave(t, 1000) * max(0, 1.0 - heartbeat_phase * 15) * 0.3
    # Flatline hint toward end
    flatline_mix = max(0, (t / dur - 0.7) / 0.3)
    flatline = sine_wave(t, 1000) * 0.2 * flatline_mix
    # Ambient tension
    tension = sine_wave(t, 120) * 0.15
    return mix(siren, heartbeat, flatline, tension)


def system_malfunction_gen(t, dur):
    """Electrical sparks, error beeps, system failures."""
    # Electrical sparks (random bursts of noise)
    spark_trigger = sine_wave(t, 7.3)
    sparks = white_noise(0.5) * (1 if spark_trigger > 0.7 else 0) * 0.4
    # Error beeps (descending)
    error_freq = 800 - 200 * (t / dur)
    error_beep = square_wave(t, error_freq) * 0.15 * (1 if (t * 4) % 1.0 < 0.15 else 0)
    # Power fluctuation
    power = sine_wave(t, 60) * 0.3 * (0.5 + 0.5 * sine_wave(t, 0.8))
    # Digital glitch
    glitch_freq = 2000 + 1000 * random.uniform(-1, 1) if random.random() < 0.05 else 440
    glitch = saw_wave(t, glitch_freq) * 0.1
    return mix(sparks, error_beep, power, glitch)


def pirate_ambush_gen(t, dur):
    """Weapons fire, explosions, combat alarms."""
    # Laser shots
    laser_phase = (t * 5) % 1.0
    laser_freq = 3000 - 2500 * laser_phase
    laser = sine_wave(t, laser_freq) * max(0, 1.0 - laser_phase * 5) * 0.3
    # Explosion rumble
    explosion = white_noise(0.4) * sine_wave(t, 30) * 0.3
    # Red alert
    alert_freq = 440 if (t * 2) % 1.0 < 0.5 else 550
    alert = square_wave(t, alert_freq) * 0.2
    # Shield impact
    shield = sine_wave(t, 200 + 100 * sine_wave(t, 8)) * 0.2
    return mix(laser, explosion, alert, shield)


def space_debris_gen(t, dur):
    """Space debris hitting hull, navigation warnings."""
    # Metallic pings
    ping_phase = (t * 4.3) % 1.0
    ping = sine_wave(t, 2000 + 500 * sine_wave(t, 0.7)) * max(0, 1.0 - ping_phase * 10) * 0.3
    # Hull stress groaning
    groan = sine_wave(t, 80 + 30 * sine_wave(t, 0.3)) * 0.35
    # Scraping
    scrape = white_noise(0.2) * abs(sine_wave(t, 2.5)) * 0.3
    # Nav warning
    nav = sine_wave(t, 700) * 0.15 * (1 if (t * 3) % 1.0 < 0.08 else 0)
    return mix(ping, groan, scrape, nav)


def sensor_ghost_gen(t, dur):
    """Mysterious scanner blips, eerie silence."""
    # Mysterious ping
    ping_phase = (t * 0.8) % 1.0
    ping = sine_wave(t, 1500 + 500 * sine_wave(t, 0.2)) * max(0, 1.0 - ping_phase * 6) * 0.25
    # Eerie ambient
    eerie1 = sine_wave(t, 180 + 20 * sine_wave(t, 0.15)) * 0.2
    eerie2 = sine_wave(t, 270 + 15 * sine_wave(t, 0.12)) * 0.15
    # Static whispers
    static = white_noise(0.08) * (0.3 + 0.7 * abs(sine_wave(t, 0.4)))
    # Scanner sweep
    sweep = sine_wave(t, 400 + 300 * sine_wave(t, 0.5)) * 0.1
    return mix(ping, eerie1, eerie2, static, sweep)


def radiation_storm_gen(t, dur):
    """Geiger counter, radiation warnings, energy interference."""
    # Geiger clicks
    click_rate = 10 + 20 * (t / dur)
    geiger = sine_wave(t, 4000) * (1 if random.random() < click_rate / SAMPLE_RATE * 5 else 0) * 0.3
    # Radiation hum
    rad_hum = sine_wave(t, 100 + 50 * sine_wave(t, 0.7)) * 0.3
    # Warning
    warn = sine_wave(t, 950) * 0.2 * (1 if (t * 3) % 1.0 < 0.5 else 0) * (1 if (t * 6) % 1.0 < 0.3 else 0)
    # Interference
    interference = white_noise(0.2) * (0.5 + 0.5 * sine_wave(t, 1.5))
    return mix(geiger, rad_hum, warn, interference)


def cryo_failure_gen(t, dur):
    """Cryogenic system alarm, freezing sounds."""
    # Cryo alarm (high-pitched pulsing)
    cryo_alarm = sine_wave(t, 1100 + 100 * sine_wave(t, 3)) * 0.25 * (1 if (t * 4) % 1.0 < 0.6 else 0)
    # Freezing/hissing
    hiss = white_noise(0.3) * 0.3 * (0.5 + 0.5 * sine_wave(t, 0.5))
    # Pod opening (low whoosh)
    whoosh = sine_wave(t, 60 + 40 * (t / dur)) * 0.3
    # Emergency beep
    emergency = sine_wave(t, 800) * 0.2 * (1 if (t * 8) % 1.0 < 0.05 else 0)
    return mix(cryo_alarm, hiss, whoosh, emergency)


def clear_skies_gen(t, dur):
    """Calm ambient hum, all-clear tone."""
    # Peaceful ship hum
    hum = sine_wave(t, 120) * 0.2
    hum2 = sine_wave(t, 180) * 0.1
    # All-clear chime (gentle)
    chime_phase = (t * 0.5) % 1.0
    chime = sine_wave(t, 800) * max(0, 1.0 - chime_phase * 4) * 0.2
    chime2 = sine_wave(t, 1200) * max(0, 1.0 - chime_phase * 5) * 0.1
    # Soft ambience
    ambience = sine_wave(t, 300 + 10 * sine_wave(t, 0.1)) * 0.08
    return mix(hum, hum2, chime, chime2, ambience)


# ============================================================================
# COLONIST LOSS MILESTONE SFX GENERATORS
# ============================================================================

def casualties_mount_gen(t, dur):
    """Warning tones, first crisis, growing concern."""
    # Warning tone
    warn = sine_wave(t, 500 + 100 * sine_wave(t, 1.5)) * 0.3
    # Slow heartbeat
    beat_phase = (t * 1.0) % 1.0
    beat = sine_wave(t, 80) * max(0, 1.0 - beat_phase * 8) * 0.35
    # Somber pad
    pad = sine_wave(t, 220) * 0.15 + sine_wave(t, 330) * 0.1
    return mix(warn, beat, pad)


def weight_of_command_gen(t, dur):
    """Heavy alarms, desperation building."""
    # Heavier alarm
    alarm = sine_wave(t, 400 + 150 * sine_wave(t, 2)) * 0.35
    # Strained systems
    strain = sine_wave(t, 60 + 20 * sine_wave(t, 0.8)) * 0.3
    # Distorted heartbeat (faster)
    beat_phase = (t * 1.5) % 1.0
    beat = sine_wave(t, 70) * max(0, 1.0 - beat_phase * 6) * 0.3
    # Dissonant tones
    dissonance = sine_wave(t, 310) * 0.1 + sine_wave(t, 317) * 0.1
    return mix(alarm, strain, beat, dissonance)


def desperation_gen(t, dur):
    """Critical warnings, failing systems."""
    # Critical alarm (fast pulsing)
    alarm = sine_wave(t, 700) * 0.3 * (1 if (t * 5) % 1.0 < 0.5 else 0)
    # System dying
    dying = sine_wave(t, 200 - 100 * (t / dur)) * 0.3
    # Chaotic noise
    chaos = white_noise(0.2) * (0.5 + 0.5 * sine_wave(t, 3))
    # Deep bass dread
    dread = sine_wave(t, 45) * 0.35
    return mix(alarm, dying, chaos, dread)


def all_hope_lost_gen(t, dur):
    """Emergency sirens, near-total failure."""
    # Wailing siren
    siren_freq = 500 + 400 * sine_wave(t, 3)
    siren = sine_wave(t, siren_freq) * 0.3
    # Systems failing (descending)
    failing = sine_wave(t, 300 - 200 * (t / dur)) * 0.25
    # Noise/static building
    static = white_noise(0.3) * (t / dur) * 0.4
    # Dread bass
    bass = sine_wave(t, 35) * 0.4
    return mix(siren, failing, static, bass)


def extinction_gen(t, dur):
    """Final system shutdown, silence, end."""
    # Systems powering down
    progress = t / dur
    powerdown = sine_wave(t, 300 * (1 - progress * 0.8)) * 0.3 * (1 - progress)
    # Last heartbeat
    if t < dur * 0.3:
        beat_phase = (t * 0.8) % 1.0
        beat = sine_wave(t, 60) * max(0, 1.0 - beat_phase * 8) * 0.4
    else:
        beat = 0
    # Flatline
    flatline = sine_wave(t, 1000) * 0.15 * max(0, progress - 0.6) / 0.4 if progress > 0.6 else 0
    # Fading hum
    hum = sine_wave(t, 100) * 0.2 * (1 - progress)
    return mix(powerdown, beat, flatline, hum)


# ============================================================================
# MISSION SCENE SFX GENERATORS
# ============================================================================

def mission_station_gen(t, dur):
    """Airlock opening, beam-down activation."""
    # Airlock hiss
    progress = t / dur
    hiss = white_noise(0.35) * max(0, 1 - progress * 3) if progress < 0.4 else 0
    # Beam activation (rising tone)
    beam_start = 0.3
    if t > beam_start:
        beam_progress = (t - beam_start) / (dur - beam_start)
        beam = sine_wave(t, 300 + 700 * beam_progress) * 0.35
        beam += sine_wave(t, 600 + 1400 * beam_progress) * 0.15
    else:
        beam = 0
    # Metallic clunk
    clunk = sine_wave(t, 150) * max(0, 1 - (t * 10)) * 0.4 if t < 0.2 else 0
    # Station ambience
    ambience = sine_wave(t, 90) * 0.1
    return mix(hiss, beam, clunk, ambience)


def mission_asteroid_gen(t, dur):
    """Mining environment, rocky deployment."""
    # Rocky rumble
    rumble = sine_wave(t, 50 + 20 * sine_wave(t, 0.5)) * 0.35
    # Mining drill hint
    drill = saw_wave(t, 300 + 100 * sine_wave(t, 4)) * 0.15
    # Deployment whoosh
    progress = t / dur
    whoosh = white_noise(0.3) * max(0, 1 - abs(progress - 0.5) * 4) * 0.3
    # Metallic echoes
    echo = sine_wave(t, 800) * max(0, 1 - ((t * 3) % 1.0) * 8) * 0.15
    return mix(rumble, drill, whoosh, echo)


def mission_planet_gen(t, dur):
    """Atmospheric entry, alien environment."""
    # Atmospheric whoosh
    progress = t / dur
    atmo = white_noise(0.3) * (0.5 + 0.5 * sine_wave(t, 0.5)) * 0.3
    # Entry heat (rising then fading)
    heat = sine_wave(t, 200 + 300 * max(0, 1 - abs(progress - 0.4) * 4)) * 0.25
    # Wind-like sounds
    wind = white_noise(0.2) * abs(sine_wave(t, 0.3)) * 0.25
    # Alien ambience
    alien = sine_wave(t, 250 + 30 * sine_wave(t, 0.2)) * 0.15
    alien2 = sine_wave(t, 370 + 20 * sine_wave(t, 0.15)) * 0.1
    return mix(atmo, heat, wind, alien, alien2)


# ============================================================================
# OBJECTIVE / ELIMINATION / VICTORY / GAME OVER SFX GENERATORS
# ============================================================================

def objective_complete_gen(t, dur):
    """Success chime, positive confirmation."""
    # Victory chime (ascending notes)
    progress = t / dur
    if progress < 0.25:
        note_freq = 523  # C5
    elif progress < 0.5:
        note_freq = 659  # E5
    elif progress < 0.75:
        note_freq = 784  # G5
    else:
        note_freq = 1047  # C6
    chime = sine_wave(t, note_freq) * 0.3
    # Harmonic
    harmonic = sine_wave(t, note_freq * 2) * 0.1
    # Sparkling
    sparkle = sine_wave(t, note_freq * 3) * 0.05 * abs(sine_wave(t, 8))
    # Confirmation beep
    confirm = sine_wave(t, 1200) * 0.1 * (1 if progress > 0.85 else 0)
    return mix(chime, harmonic, sparkle, confirm)


def all_hostiles_eliminated_gen(t, dur):
    """Final combat fading, victory tone, all-clear."""
    progress = t / dur
    # Final shot fading
    if progress < 0.3:
        shot = white_noise(0.3) * (1 - progress / 0.3) * 0.3
        shot += sine_wave(t, 150) * (1 - progress / 0.3) * 0.2
    else:
        shot = 0
    # Silence break
    # Victory tone (ascending)
    if progress > 0.4:
        vic_progress = (progress - 0.4) / 0.6
        vic_freq = 400 + 400 * vic_progress
        victory = sine_wave(t, vic_freq) * 0.3
        victory += sine_wave(t, vic_freq * 1.5) * 0.1
    else:
        victory = 0
    # All-clear signal
    clear = sine_wave(t, 880) * 0.2 * (1 if progress > 0.7 and (t * 3) % 1.0 < 0.15 else 0)
    return mix(shot, victory, clear)


def arrival_perfect_gen(t, dur):
    """Triumphant arrival, celebration, hope."""
    progress = t / dur
    # Major chord (C major)
    c = sine_wave(t, 262) * 0.2
    e = sine_wave(t, 330) * 0.15
    g = sine_wave(t, 392) * 0.15
    # Rising sweep
    sweep = sine_wave(t, 200 + 600 * progress) * 0.15
    # Celebration sparkles
    sparkle = sine_wave(t, 1500 + 500 * sine_wave(t, 6)) * 0.1 * abs(sine_wave(t, 4))
    # Triumphant horn
    horn = sine_wave(t, 523 + 262 * progress) * 0.2
    return mix(c, e, g, sweep, sparkle, horn)


def arrival_good_gen(t, dur):
    """Relief, cautious optimism, survival."""
    progress = t / dur
    # Relieved sigh (filtered noise)
    relief = white_noise(0.15) * max(0, 1 - progress * 2) * 0.2
    # Hopeful tone
    hope = sine_wave(t, 330 + 50 * progress) * 0.25
    hope2 = sine_wave(t, 440 + 30 * progress) * 0.15
    # Gentle chime
    chime_phase = (t * 0.7) % 1.0
    chime = sine_wave(t, 800) * max(0, 1 - chime_phase * 5) * 0.2
    # Ship systems stable
    stable = sine_wave(t, 150) * 0.1
    return mix(relief, hope, hope2, chime, stable)


def arrival_bad_gen(t, dur):
    """Somber arrival, bittersweet, against odds."""
    progress = t / dur
    # Minor chord (A minor)
    a = sine_wave(t, 220) * 0.2
    c = sine_wave(t, 262) * 0.15
    e = sine_wave(t, 330) * 0.15
    # Somber pad
    pad = sine_wave(t, 165) * 0.2
    # Slow, tired ship hum
    hum = sine_wave(t, 80 + 10 * sine_wave(t, 0.2)) * 0.15
    # Distant, weak chime
    chime_phase = (t * 0.4) % 1.0
    chime = sine_wave(t, 600) * max(0, 1 - chime_phase * 6) * 0.1
    return mix(a, c, e, pad, hum, chime)


def game_over_extinction_gen(t, dur):
    """Final breath, systems dying, silence."""
    progress = t / dur
    # Dying systems
    dying = sine_wave(t, 200 * (1 - progress * 0.9)) * 0.3 * (1 - progress * 0.8)
    # Last breath (noise fading)
    breath = white_noise(0.2) * max(0, 1 - progress * 1.5) * 0.25
    # Flatline
    if progress > 0.5:
        flatline = sine_wave(t, 1000) * 0.2 * min(1, (progress - 0.5) / 0.2)
    else:
        flatline = 0
    # Deep void
    void = sine_wave(t, 40) * 0.3 * (1 - progress)
    return mix(dying, breath, flatline, void)


def ship_destroyed_gen(t, dur):
    """Massive explosion, catastrophic hull breach."""
    progress = t / dur
    # Initial explosion
    if progress < 0.4:
        explosion = white_noise(0.6) * (1 - progress / 0.4) * 0.5
        explosion += sine_wave(t, 60 + 40 * sine_wave(t, 2)) * (1 - progress / 0.4) * 0.4
    else:
        explosion = 0
    # Hull breach (whoosh)
    breach = white_noise(0.3) * max(0, 1 - abs(progress - 0.3) * 4) * 0.3
    # Metal tearing
    tear = saw_wave(t, 150 + 100 * sine_wave(t, 5)) * 0.2 * max(0, 1 - progress * 2)
    # Fading debris
    debris = white_noise(0.1) * max(0, progress - 0.5) * 0.2
    return mix(explosion, breach, tear, debris)


def captain_died_gen(t, dur):
    """Somber tone, loss of command."""
    progress = t / dur
    # Somber low tone
    somber = sine_wave(t, 150) * 0.25
    somber2 = sine_wave(t, 225) * 0.15  # Perfect fifth below
    # Fading heartbeat
    if progress < 0.5:
        beat_phase = (t * 0.8) % 1.0
        beat = sine_wave(t, 60) * max(0, 1 - beat_phase * 8) * 0.3 * (1 - progress * 2)
    else:
        beat = 0
    # Empty ship hum
    hum = sine_wave(t, 90, ) * 0.15 * max(0, 1 - progress * 0.5)
    # Slow, mournful tone
    mourn = sine_wave(t, 440 * (1 - progress * 0.1)) * 0.1
    return mix(somber, somber2, beat, hum, mourn)


def voyage_intro_gen(t, dur):
    """Epic beginning, ship launching, hopeful departure."""
    progress = t / dur
    # Engine ignition (building)
    engine = sine_wave(t, 80 + 120 * progress) * 0.3
    engine_rumble = white_noise(0.2) * (0.3 + 0.7 * progress) * 0.25
    # Hopeful ascending tone
    hope = sine_wave(t, 262 + 200 * progress) * 0.2
    hope2 = sine_wave(t, 330 + 200 * progress) * 0.12
    # Launch whoosh
    whoosh = white_noise(0.3) * max(0, 1 - abs(progress - 0.5) * 3) * 0.2
    # Stars passing (sparkles)
    sparkle = sine_wave(t, 2000 + 500 * sine_wave(t, 5)) * 0.05 * progress
    return mix(engine, engine_rumble, hope, hope2, whoosh, sparkle)


# ============================================================================
# MAIN
# ============================================================================

def main():
    print("=" * 60)
    print("Last Light Odyssey - Scene SFX Generator (LOUD VOLUME)")
    print("=" * 60)

    # NEW: Additional Scene SFX
    print("\n[0/8] Additional Scenes:")
    extras = [
        ("beam.mp3", beam_gen, 3.0),
        ("extraction_complete.mp3", extraction_complete_gen, 4.0),
        ("extraction_failed.mp3", extraction_failed_gen, 4.0),
        ("outpost_arrival.mp3", outpost_arrival_gen, 3.0),
        ("voyage_failure.mp3", voyage_failure_gen, 5.0),
    ]
    # Place these in appropriate folders or a 'common' folder?
    # User requested separate files. I will put them in 'common_scene' folder 
    # OR repurpose/add to existing struct. 
    # Let's put them in 'event_scene' or similar for now, or creates specific ones.
    # To correspond with code, let's stick to strict folders.
    # Actually, for 'beam', it's tactical but 'scene' volume. 
    # For 'extraction', it's mission recap.
    # Let's create a 'common' subfolder in scenes.
    for name, gen, dur in extras:
        generate_sfx(name, "common_scene", dur, gen, attack=0.1, release=0.5)


    # Event Scenes
    print("\n[1/8] Event Scenes:")
    events = [
        ("solar_flare.mp3", solar_flare_gen, 3.0),
        ("meteor_shower.mp3", meteor_shower_gen, 3.0),
        ("disease_outbreak.mp3", disease_outbreak_gen, 3.5),
        ("system_malfunction.mp3", system_malfunction_gen, 3.0),
        ("pirate_ambush.mp3", pirate_ambush_gen, 3.0),
        ("space_debris.mp3", space_debris_gen, 3.0),
        ("sensor_ghost.mp3", sensor_ghost_gen, 3.5),
        ("radiation_storm.mp3", radiation_storm_gen, 3.0),
        ("cryo_failure.mp3", cryo_failure_gen, 3.0),
        ("clear_skies.mp3", clear_skies_gen, 3.0),
    ]
    for name, gen, dur in events:
        generate_sfx(name, "event_scene", dur, gen, attack=0.1, release=0.5)

    # Colonist Loss Milestones
    print("\n[2/8] Colonist Loss Milestones:")
    milestones = [
        ("casualties_mount.mp3", casualties_mount_gen, 3.0),
        ("weight_of_command.mp3", weight_of_command_gen, 3.5),
        ("desperation.mp3", desperation_gen, 3.5),
        ("all_hope_lost.mp3", all_hope_lost_gen, 4.0),
        ("extinction.mp3", extinction_gen, 4.0),
    ]
    for name, gen, dur in milestones:
        generate_sfx(name, "colonist_loss_scene", dur, gen, attack=0.15, release=0.8)

    # Mission Scenes
    print("\n[3/8] Mission Scenes:")
    missions = [
        ("mission_station.mp3", mission_station_gen, 3.0),
        ("mission_asteroid.mp3", mission_asteroid_gen, 3.0),
        ("mission_planet.mp3", mission_planet_gen, 3.5),
    ]
    for name, gen, dur in missions:
        generate_sfx(name, "mission_scene", dur, gen, attack=0.05, release=0.5)

    # Objective Complete
    print("\n[4/8] Objective Complete:")
    generate_sfx("objective_complete.mp3", "objective_complete_scene", 2.5,
                 objective_complete_gen, attack=0.02, decay=0.05, sustain=0.8, release=0.4)

    # Enemy Elimination
    print("\n[5/8] Enemy Elimination:")
    generate_sfx("all_hostiles_eliminated.mp3", "enemy_elimination_scene", 3.0,
                 all_hostiles_eliminated_gen, attack=0.05, release=0.5)

    # New Earth Arrival
    print("\n[6/8] New Earth Arrival:")
    arrivals = [
        ("arrival_perfect.mp3", arrival_perfect_gen, 3.5),
        ("arrival_good.mp3", arrival_good_gen, 3.0),
        ("arrival_bad.mp3", arrival_bad_gen, 3.5),
    ]
    for name, gen, dur in arrivals:
        generate_sfx(name, "new_earth_scene", dur, gen, attack=0.1, release=0.6)

    # Game Over
    print("\n[7/8] Game Over:")
    game_overs = [
        ("extinction.mp3", game_over_extinction_gen, 4.0),
        ("ship_destroyed.mp3", ship_destroyed_gen, 3.5),
        ("captain_died.mp3", captain_died_gen, 4.0),
    ]
    for name, gen, dur in game_overs:
        generate_sfx(name, "game_over_scene", dur, gen, attack=0.05, release=1.0)

    # Voyage Intro
    print("\n[8/8] Voyage Intro:")
    generate_sfx("voyage_intro.mp3", "voyage_intro_scene", 4.0,
                 voyage_intro_gen, attack=0.2, decay=0.2, sustain=0.8, release=0.8)

    print("\n" + "=" * 60)
    print("All scene SFX (including new files) generated successfully!")
    print("=" * 60)


if __name__ == "__main__":
    random.seed(42)  # Deterministic output
    main()
