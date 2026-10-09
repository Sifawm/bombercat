"""Synthesises every sound effect and music loop of the game into game/assets/audio/<name>.wav.
Nothing is sampled or downloaded, so the results are the project's own (see docs/credits.md).
Needs Python 3 with numpy. From the repository root:

    python3 art/build_audio.py
"""
import os
import wave

import numpy as np

RATE = 32000
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "assets", "audio")
random = np.random.default_rng(9)  # fixed seed: the same files on every run


# --- building blocks ---------------------------------------------------------------------

def time(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def wave_of(shape, phase):
    """One of the basic waveforms at the given phase (in cycles)."""
    cycle = phase % 1.0
    if shape == "sine":
        return np.sin(2 * np.pi * phase)
    if shape == "square":
        return np.where(cycle < 0.5, 1.0, -1.0) * 0.6
    if shape == "saw":
        return (2.0 * cycle - 1.0) * 0.7
    return 4.0 * np.abs(cycle - 0.5) - 1.0  # triangle


def tone(shape, frequency, seconds, decay=None, attack=0.005):
    """A note. `frequency` is a number or a list of (moment 0-1, Hz) points to glide through.
    `decay` is the time constant of its fade; without it the note holds and releases."""
    t = time(seconds)
    if not np.isscalar(frequency):
        moments, values = zip(*frequency)
        frequency = np.interp(t / seconds, moments, values)
    phase = np.cumsum(np.full_like(t, 1.0) * frequency) / RATE
    volume = np.exp(-t / decay) if decay else np.ones_like(t)
    volume *= np.clip(t / attack, 0.0, 1.0) * np.clip((seconds - t) / 0.01, 0.0, 1.0)
    return wave_of(shape, phase) * volume


def noise(seconds, decay, low=0.0, high=RATE / 2):
    """Noise between two frequencies, fading out."""
    t = time(seconds)
    spectrum = np.fft.rfft(random.uniform(-1.0, 1.0, t.size))
    frequencies = np.fft.rfftfreq(t.size, 1.0 / RATE)
    spectrum[(frequencies < low) | (frequencies > high)] = 0.0
    sound = np.fft.irfft(spectrum, t.size)
    return sound / np.abs(sound).max() * np.exp(-t / decay)


def mix(seconds, *parts):
    """Lays (start, sound, volume) parts over silence."""
    track = np.zeros(int(RATE * seconds))
    for start, sound, volume in parts:
        first = int(RATE * start)
        sound = sound[: track.size - first]
        track[first : first + sound.size] += sound * volume
    return track


def sequence(shape, notes, note_seconds, decay=None, gap=0.0):
    """Notes (in Hz) one after another."""
    step = note_seconds + gap
    return mix(step * len(notes), *[(i * step, tone(shape, pitch, note_seconds, decay), 1.0) for i, pitch in enumerate(notes)])


def hz(semitones_from_a4):
    return 440.0 * 2.0 ** (semitones_from_a4 / 12.0)


def meow(seconds, pitch):
    """A cat voice: a buzzy note gliding along `pitch`, with a vowel that opens and closes."""
    voice = tone("saw", pitch, seconds, attack=0.04) + 0.5 * tone("square", pitch, seconds, attack=0.04)
    t = time(seconds) / seconds
    wobble = 1.0 + 0.15 * np.sin(2 * np.pi * 9.0 * time(seconds))
    return voice * np.sin(np.pi * t) ** 0.6 * wobble


def save(name, sound, peak=0.8):
    sound = sound / np.abs(sound).max() * peak
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes((sound * 32767).astype("<i2").tobytes())


# --- music -------------------------------------------------------------------------------

def loop(beats_per_minute, bars, voices):
    """A seamless loop of 4/4 bars. Each voice is (shape, volume, decay, notes) with notes as
    (beat, semitones from A4, length in beats). Whatever rings past the end wraps to the start."""
    beat = 60.0 / beats_per_minute
    length = int(RATE * beat * 4 * bars)
    track = np.zeros(length * 2)
    for shape, volume, decay, notes in voices:
        for start, semitones, beats in notes:
            sound = noise(beats * beat, decay, 6000) if shape == "noise" else tone(shape, hz(semitones), beats * beat, decay)
            first = int(RATE * start * beat)
            track[first : first + sound.size] += sound * volume
    track[:length] += track[length:]
    return track[:length]


def chords_voices(chords, bass_octave, arpeggio):
    """Bass and arpeggio notes for one chord per bar. A chord is its three notes in semitones
    from A4; `arpeggio` lists which chord note sounds on each half beat."""
    bass, harmony = [], []
    for bar, chord in enumerate(chords):
        for beat in range(4):
            bass.append((bar * 4 + beat, chord[0] - 12 * bass_octave, 0.9))
        for half, index in enumerate(arpeggio):
            if index is not None:
                harmony.append((bar * 4 + half * 0.5, chord[index % 3] + 12 * (index // 3), 0.45))
    return bass, harmony


A_MINOR, F_MAJOR, C_MAJOR, G_MAJOR = (0, 3, 7), (-4, 0, 3), (-9, -5, -2), (-2, 2, 5)


def music_menu():
    chords = [C_MAJOR, A_MINOR, F_MAJOR, G_MAJOR] * 2
    bass, harmony = chords_voices(chords, 1, [0, 1, 2, 3, 2, 1, 2, 1])
    bass = [note for note in bass if note[0] % 2 == 0]
    tune = [(0, 3, 2), (2, 7, 1), (3, 5, 1), (4, 3, 3), (8, 0, 2), (10, 3, 1), (11, 5, 1), (12, 2, 3),
            (16, 3, 2), (18, 7, 1), (19, 10, 1), (20, 12, 3), (24, 8, 2), (26, 7, 1), (27, 5, 1), (28, 2, 4)]
    return loop(84, 8, [("triangle", 0.5, 0.5, bass), ("triangle", 0.3, 0.25, harmony), ("sine", 0.35, 0.6, tune)])


def music_round():
    chords = [A_MINOR, F_MAJOR, C_MAJOR, G_MAJOR] * 2
    bass, harmony = chords_voices(chords, 2, [0, None, 2, 1, 3, None, 2, 1])
    bass = [(beat + offset, pitch, 0.4) for beat, pitch, _ in bass for offset in (0.0, 0.5)]
    phrase = [(0, 12, 0.5), (0.5, 15, 0.5), (1, 19, 1), (2.5, 17, 0.5), (3, 15, 1),
              (4, 12, 0.5), (4.5, 15, 0.5), (5, 20, 1), (6.5, 19, 0.5), (7, 15, 1),
              (8, 14, 0.5), (8.5, 15, 0.5), (9, 19, 1), (10.5, 22, 0.5), (11, 19, 1),
              (12, 17, 0.5), (12.5, 14, 0.5), (13, 10, 1), (14, 14, 0.5), (14.5, 17, 0.5), (15, 14, 1)]
    tune = phrase + [(beat + 16, pitch, beats) for beat, pitch, beats in phrase]
    hats = [(half * 0.5, 0, 0.2) for half in range(64)]
    return loop(150, 8, [("square", 0.45, 0.25, bass), ("triangle", 0.3, 0.15, harmony),
                         ("square", 0.3, 0.2, tune), ("noise", 0.1, 0.03, hats)])


# --- the catalogue -----------------------------------------------------------------------

def build():
    os.makedirs(OUT, exist_ok=True)
    save("place_bomb", tone("sine", [(0, 240), (1, 80)], 0.16, 0.05))
    save("fuse_tick", tone("square", 1700, 0.03, 0.01) + noise(0.03, 0.01, 3000), 0.35)
    save("explosion", mix(0.7, (0, noise(0.7, 0.16, 0, 1800), 1.0), (0, tone("sine", [(0, 130), (1, 35)], 0.5, 0.15), 1.0),
                          (0, noise(0.08, 0.02, 2000), 0.6)), 0.95)
    save("explosion_chain", mix(1.1, (0, noise(1.1, 0.28, 0, 1200), 1.0), (0, tone("sine", [(0, 100), (1, 28)], 0.8, 0.25), 1.2),
                                (0, noise(0.1, 0.03, 1500), 0.7)), 0.95)
    save("crate_break", mix(0.3, (0, noise(0.3, 0.05, 300, 3500), 1.0), (0.04, noise(0.1, 0.02, 1500, 6000), 0.7),
                            (0.09, noise(0.1, 0.02, 800, 4000), 0.5), (0, tone("triangle", 160, 0.1, 0.03), 0.8)))
    save("powerup", sequence("square", [hz(3), hz(7), hz(10), hz(15)], 0.07, 0.08), 0.45)
    save("collect_cucumber", sequence("saw", [hz(3), hz(2), hz(-3), [(0, hz(-4)), (1, hz(-9))]], 0.13, 0.2), 0.7)
    save("paw_swipe", mix(0.22, (0, noise(0.22, 0.07, 1500, 7000), 0.8), (0, tone("sine", [(0, 300), (1, 1100)], 0.15, 0.06), 0.6)))
    save("nine_lives", mix(0.7, (0, tone("sine", hz(12), 0.7, 0.25), 1.0), (0.05, tone("sine", hz(19), 0.65, 0.25), 0.7),
                           (0.1, tone("sine", hz(24), 0.6, 0.2), 0.5)))
    save("meow", meow(0.45, [(0, 480), (0.3, 760), (1, 430)]), 0.7)
    save("death", meow(0.9, [(0, 820), (0.2, 900), (1, 210)]), 0.75)
    save("victory", mix(1.3, (0, sequence("square", [hz(-2), hz(3), hz(7), hz(10)], 0.11, 0.2), 1.0),
                        (0.44, tone("square", hz(15), 0.8, 0.4), 1.0), (0.44, tone("triangle", hz(7), 0.8, 0.4), 0.8)), 0.7)
    save("ui_move", tone("triangle", 880, 0.05, 0.02), 0.4)
    save("ui_confirm", sequence("triangle", [660, 990], 0.06, 0.04), 0.5)
    save("ui_cancel", sequence("triangle", [520, 350], 0.06, 0.04), 0.5)
    save("countdown", tone("square", 660, 0.14, 0.08), 0.5)
    save("go", tone("square", 990, 0.4, 0.2), 0.5)
    save("warning", sequence("square", [1250, 1250], 0.06, 0.04, 0.04), 0.4)
    save("music_menu", music_menu(), 0.6)
    save("music_round", music_round(), 0.6)


if __name__ == "__main__":
    build()
