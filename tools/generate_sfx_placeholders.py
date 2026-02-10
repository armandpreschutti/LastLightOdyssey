#!/usr/bin/env python3
"""
Generate placeholder MP3 audio files for SFX system.
Creates simple tone/beep files organized by category.
"""

import os
import sys
import math
from pathlib import Path

try:
    import numpy as np
    from pydub import AudioSegment
    from pydub.generators import Sine
except ImportError:
    print("Error: Required packages not installed.")
    print("Please install: pip install numpy pydub")
    sys.exit(1)


# Base directory for the project
BASE_DIR = Path(__file__).parent.parent
SFX_BASE = BASE_DIR / "assets" / "audio" / "sfx"

# SFX definitions: (category, name, frequency_hz, duration_ms)
SFX_DEFINITIONS = [
    # Combat SFX
    ("combat", "shoot", 800, 150),
    ("combat", "hit", 400, 200),
    ("combat", "miss", 200, 250),
    ("combat", "charge", 300, 300),
    ("combat", "patch", 600, 200),
    ("combat", "turret", 500, 250),
    ("combat", "execute", 350, 400),
    ("combat", "precision_shot", 1000, 100),
    ("combat", "damage", 250, 300),
    ("combat", "death", 150, 500),
    
    # UI SFX
    ("ui", "click", 1000, 100),
    ("ui", "menu_open", 600, 200),
    ("ui", "menu_close", 400, 200),
    
    # Interaction SFX
    ("interactions", "pickup", 800, 150),
    ("interactions", "fuel_pickup", 600, 200),
    ("interactions", "scrap_pickup", 700, 180),
    ("interactions", "health_pickup", 500, 250),
]


def generate_tone(frequency: float, duration_ms: int, sample_rate: int = 44100) -> AudioSegment:
    """
    Generate a simple sine wave tone.
    
    Args:
        frequency: Frequency in Hz
        duration_ms: Duration in milliseconds
        sample_rate: Sample rate (default 44100)
    
    Returns:
        AudioSegment with the generated tone
    """
    # Generate time array
    duration_sec = duration_ms / 1000.0
    t = np.linspace(0, duration_sec, int(sample_rate * duration_sec), False)
    
    # Generate sine wave
    wave = np.sin(2 * np.pi * frequency * t)
    
    # Normalize to 16-bit integer range
    wave_normalized = np.int16(wave * 32767 * 0.5)  # 0.5 volume to avoid clipping
    
    # Convert to AudioSegment
    audio = AudioSegment(
        wave_normalized.tobytes(),
        frame_rate=sample_rate,
        channels=1,
        sample_width=2
    )
    
    # Add a quick fade in/out to avoid clicks
    audio = audio.fade_in(10).fade_out(10)
    
    return audio


def generate_sfx_file(category: str, name: str, frequency: float, duration_ms: int) -> None:
    """
    Generate a single SFX file.
    
    Args:
        category: Category folder name (combat, ui, interactions)
        name: File name without extension
        frequency: Tone frequency in Hz
        duration_ms: Duration in milliseconds
    """
    # Create category directory if it doesn't exist
    category_dir = SFX_BASE / category
    category_dir.mkdir(parents=True, exist_ok=True)
    
    # Generate the tone
    audio = generate_tone(frequency, duration_ms)
    
    # Export as MP3
    output_path = category_dir / f"{name}.mp3"
    audio.export(str(output_path), format="mp3", bitrate="128k")
    
    print(f"Generated: {output_path.relative_to(BASE_DIR)}")


def main():
    """Generate all placeholder SFX files."""
    print("Generating placeholder SFX files...")
    print(f"Base directory: {BASE_DIR}")
    print(f"SFX directory: {SFX_BASE}\n")
    
    # Create base SFX directory if it doesn't exist
    SFX_BASE.mkdir(parents=True, exist_ok=True)
    
    # Generate all SFX files
    for category, name, frequency, duration in SFX_DEFINITIONS:
        try:
            generate_sfx_file(category, name, frequency, duration)
        except Exception as e:
            print(f"Error generating {category}/{name}.mp3: {e}")
    
    print(f"\nDone! Generated {len(SFX_DEFINITIONS)} placeholder SFX files.")


if __name__ == "__main__":
    main()
