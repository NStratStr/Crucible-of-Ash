import math
import struct
import wave
import random

SAMPLE_RATE = 44100

def write_wav(filename, samples):
    with wave.open(filename, 'w') as wav_file:
        wav_file.setnchannels(1)  # Mono
        wav_file.setsampwidth(2)  # 16-bit
        wav_file.setframerate(SAMPLE_RATE)
        # Clamp and pack
        packed_frames = bytearray()
        for s in samples:
            clamped = max(-1.0, min(1.0, s))
            int_val = int(clamped * 32767.0)
            packed_frames.extend(struct.pack('<h', int_val))
        wav_file.writeframes(packed_frames)

def generate_slash():
    # Whoosh + sharp metallic blade slice
    duration = 0.28
    total_samples = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        # Noise burst with quick decaying envelope
        env = math.exp(-t * 22)
        noise = random.uniform(-1, 1) * 0.4
        # Metallic overtone (800Hz dropping to 240Hz)
        freq = 800 * math.exp(-t * 8)
        tone = math.sin(2 * math.pi * freq * t) * 0.6
        # Fast swoosh low-pass resonance
        swoosh = math.sin(2 * math.pi * 140 * t) * 0.3 * math.exp(-t * 12)
        samples.append((noise + tone + swoosh) * env)
    return samples

def generate_blunt_hit():
    # Heavy thud / armor impact
    duration = 0.32
    total_samples = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 18)
        # Low boom: 110Hz dropping to 45Hz
        freq = 110 * math.exp(-t * 9)
        boom = math.sin(2 * math.pi * freq * t) * 0.8
        # High impact click at start
        click = random.uniform(-1, 1) * 0.4 * math.exp(-t * 60)
        samples.append((boom + click) * env)
    return samples

def generate_shield_block():
    # Metallic clang / shield deflection
    duration = 0.40
    total_samples = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 11)
        # Ringing iron bell/plate harmonics (880Hz + 1320Hz + 2200Hz)
        h1 = math.sin(2 * math.pi * 880 * t) * 0.5
        h2 = math.sin(2 * math.pi * 1320 * t) * 0.3
        h3 = math.sin(2 * math.pi * 2200 * t) * 0.2
        clang = (h1 + h2 + h3) * env
        # Initial spark click
        spark = random.uniform(-1, 1) * 0.3 * math.exp(-t * 80)
        samples.append((clang + spark))
    return samples

def generate_spell_cast():
    # Aetheric shimmer / magic hum
    duration = 0.45
    total_samples = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        env = math.sin(math.pi * (t / duration)) # swell up and down
        # Rising resonant frequencies (320Hz rising to 640Hz)
        freq = 320 + 320 * (t / duration)
        vibrato = math.sin(2 * math.pi * 12 * t) * 20
        tone1 = math.sin(2 * math.pi * (freq + vibrato) * t) * 0.5
        tone2 = math.sin(2 * math.pi * (freq * 1.5) * t) * 0.3
        shimmer = random.uniform(-1, 1) * 0.15
        samples.append((tone1 + tone2 + shimmer) * env)
    return samples

def generate_card_play():
    # Tactile paper / crisp leather snap
    duration = 0.18
    total_samples = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 35)
        snap = (random.uniform(-1, 1) * 0.7 + math.sin(2 * math.pi * 440 * t) * 0.3) * env
        samples.append(snap)
    return samples

def generate_victory_horn():
    # Brass/gothic triumphant low chord
    duration = 1.2
    total_samples = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(total_samples):
        t = i / SAMPLE_RATE
        env = min(1.0, t * 8.0) * math.exp(-t * 2.2) # swell then sustain decay
        # D minor power triad: D3 (146.8Hz), A3 (220Hz), D4 (293.7Hz)
        f1 = math.sin(2 * math.pi * 146.83 * t) * 0.45
        f2 = math.sin(2 * math.pi * 220.00 * t) * 0.35
        f3 = math.sin(2 * math.pi * 293.66 * t) * 0.25
        samples.append((f1 + f2 + f3) * env)
    return samples

if __name__ == '__main__':
    write_wav('assets/audio/sfx_slash.wav', generate_slash())
    write_wav('assets/audio/sfx_hit.wav', generate_blunt_hit())
    write_wav('assets/audio/sfx_block.wav', generate_shield_block())
    write_wav('assets/audio/sfx_spell.wav', generate_spell_cast())
    write_wav('assets/audio/sfx_card.wav', generate_card_play())
    write_wav('assets/audio/sfx_victory.wav', generate_victory_horn())
    print("Synthesized Dark Fantasy SFX audio assets successfully.")
