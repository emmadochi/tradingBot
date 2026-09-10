import os
import math
import struct
import wave

output_dir = r"c:\Users\DELL\Downloads\Trading Robots details\mobile_app\assets\audio"
os.makedirs(output_dir, exist_ok=True)
output_path = os.path.join(output_dir, "alert.wav")

sample_rate = 44100
duration = 0.6  # 600ms chime

# Two-tone luxury trading chime: 880 Hz (A5) -> 1320 Hz (E6)
freq1 = 880.0
freq2 = 1320.0

total_samples = int(sample_rate * duration)
half_samples = total_samples // 2

samples = []

# Tone 1
for i in range(half_samples):
    t = i / sample_rate
    envelope = math.exp(-t * 6.0) # decay
    val = math.sin(2.0 * math.pi * freq1 * t) * envelope * 0.85
    # Add a soft harmonic
    val += math.sin(2.0 * math.pi * freq1 * 2 * t) * envelope * 0.25
    samples.append(val)

# Tone 2 (higher crisp chime)
for i in range(half_samples):
    t = i / sample_rate
    envelope = math.exp(-t * 5.0) # decay
    val = math.sin(2.0 * math.pi * freq2 * t) * envelope * 0.95
    # Harmonic
    val += math.sin(2.0 * math.pi * freq2 * 2 * t) * envelope * 0.2
    samples.append(val)

with wave.open(output_path, "w") as wav_file:
    wav_file.setnchannels(1) # Mono
    wav_file.setsampwidth(2) # 16-bit
    wav_file.setframerate(sample_rate)
    for s in samples:
        clamped = max(-1.0, min(1.0, s))
        int_sample = int(clamped * 32767.0)
        wav_file.writeframes(struct.pack("<h", int_sample))

print(f"Synthesized luxury trading alert sound at: {output_path}")
