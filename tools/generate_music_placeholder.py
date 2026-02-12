#!/usr/bin/env python3
"""
Generate a placeholder MP3 music track for Last Light Odyssey title menu.
Creates a simple atmospheric drone with a basic melody.
"""

import math
import numpy as np
from pydub import AudioSegment
from pathlib import Path

# Project paths
BASE_DIR = Path(__file__).parent.parent
MUSIC_DIR = BASE_DIR / "assets" / "audio" / "music"

def generate_oscillator(freq, duration_ms, amplitude=0.5, sample_rate=44100):
    """Generate a sine wave tone."""
    duration_sec = duration_ms / 1000.0
    t = np.linspace(0, duration_sec, int(sample_rate * duration_sec), False)
    wave = np.sin(2 * np.pi * freq * t)
    return (wave * amplitude * 32767).astype(np.int16)

def apply_fade(audio, fade_ms=1000):
    """Apply fade in and fade out."""
    return audio.fade_in(fade_ms).fade_out(fade_ms)

def generate_title_music():
    """Generate a 30-second atmospheric placeholder track."""
    print("Generating title music placeholder...")
    sample_rate = 44100
    duration_ms = 30000 # 30 seconds
    
    # 1. Base Drone (Deep, spacey)
    base_freq = 55.0  # A1
    drone1 = generate_oscillator(base_freq, duration_ms, amplitude=0.2)
    drone2 = generate_oscillator(base_freq * 1.5, duration_ms, amplitude=0.1) # Perfect fifth
    
    # Mix drones
    drone_mix = (drone1.astype(np.int32) + drone2.astype(np.int32))
    
    # 2. Add some "pulsing" to the drone
    pulse_freq = 0.2 # low frequency oscillation
    t = np.linspace(0, duration_ms/1000.0, len(drone_mix), False)
    pulser = (np.sin(2 * np.pi * pulse_freq * t) * 0.3 + 0.7)
    drone_pulsed = (drone_mix * pulser).astype(np.int16)
    
    # 3. Add a simple melody (Arpeggio)
    melody = np.zeros(len(drone_pulsed), dtype=np.int16)
    notes = [440.0, 554.37, 659.25, 880.0] # A4, C#5, E5, A5
    note_duration = 2000 # 2 seconds
    
    for i in range(0, duration_ms, note_duration):
        note_idx = (i // note_duration) % len(notes)
        freq = notes[note_idx]
        start_sample = int((i/1000.0) * sample_rate)
        end_sample = min(start_sample + int((note_duration/1000.0) * sample_rate), len(melody))
        
        # Generate note with fade
        note_wave = generate_oscillator(freq, note_duration, amplitude=0.1)
        note_segment = AudioSegment(
            note_wave.tobytes(), 
            frame_rate=sample_rate, 
            sample_width=2, 
            channels=1
        ).fade_in(500).fade_out(1000)
        
        # Convert back to numpy
        note_data = np.frombuffer(note_segment.raw_data, dtype=np.int16)
        
        # Place in melody array
        place_end = min(start_sample + len(note_data), len(melody))
        melody[start_sample:place_end] = note_data[:place_end-start_sample]

    # Combine all
    final_mix = (drone_pulsed.astype(np.int32) + melody.astype(np.int32))
    # Normalize to avoid clipping
    max_val = np.max(np.abs(final_mix))
    if max_val > 32767:
        final_mix = (final_mix * (32767 / max_val)).astype(np.int16)
    else:
        final_mix = final_mix.astype(np.int16)

    # Convert to AudioSegment
    audio = AudioSegment(
        final_mix.tobytes(),
        frame_rate=sample_rate,
        sample_width=2,
        channels=1
    )
    
    audio = apply_fade(audio)
    
    # Export
    MUSIC_DIR.mkdir(parents=True, exist_ok=True)
    output_path = MUSIC_DIR / "title_menu_music.mp3"
    audio.export(str(output_path), format="mp3", bitrate="128k")
    print(f"Successfully generated: {output_path}")

if __name__ == "__main__":
    generate_title_music()
