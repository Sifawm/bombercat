"""Downloads every sound effect and music loop of the game from its CC0 source and writes it
to game/assets/audio/<name>.ogg at an even volume. The table below is the single record of
where each file comes from; docs/credits.md repeats it for readers.
Needs Python 3 and ffmpeg. From the repository root:

    python3 art/import_audio.py
"""
import io
import os
import re
import subprocess
import tempfile
import urllib.request
import zipfile

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "game", "assets", "audio")
KENNEY = "https://kenney.nl/media/pages/assets/"
OGA = "https://opengameart.org/sites/default/files/"
PACKS = {
    "interface": KENNEY + "interface-sounds/fa43c1dd4d-1677589452/kenney_interface-sounds.zip",
    "impact": KENNEY + "impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip",
    "sci-fi": KENNEY + "sci-fi-sounds/6b296f9ecf-1677589334/kenney_sci-fi-sounds.zip",
    "rpg": KENNEY + "rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip",
    "jingles": KENNEY + "music-jingles/f37e530b9e-1677590399/kenney_music-jingles.zip",
}
# name in the game: (source, peak volume in dB). A source is "pack:file inside its zip" or a URL.
SOUNDS = {
    "place_bomb": ("interface:Audio/drop_002.ogg", -4),
    "fuse_tick": ("interface:Audio/tick_001.ogg", -12),
    "explosion": ("sci-fi:Audio/explosionCrunch_000.ogg", -1),
    "explosion_chain": ("sci-fi:Audio/lowFrequency_explosion_001.ogg", -1),
    "crate_break": ("impact:Audio/impactWood_heavy_000.ogg", -4),
    "powerup": ("interface:Audio/confirmation_001.ogg", -5),
    "collect_cucumber": ("interface:Audio/error_006.ogg", -5),
    "paw_swipe": ("rpg:Audio/knifeSlice.ogg", -4),
    "nine_lives": ("impact:Audio/impactBell_heavy_000.ogg", -4),
    "portal": ("sci-fi:Audio/forceField_000.ogg", -6),
    "meow": (OGA + "Meow.ogg", -3),
    "death": (OGA + "cat_mewfood.wav", -2),
    "victory": ("jingles:Audio/Steel jingles/jingles_STEEL07.ogg", -5),
    "ui_move": ("interface:Audio/click_001.ogg", -12),
    "ui_confirm": ("interface:Audio/confirmation_002.ogg", -9),
    "ui_cancel": ("interface:Audio/back_001.ogg", -9),
    "countdown": ("interface:Audio/bong_001.ogg", -6),
    "go": ("interface:Audio/maximize_003.ogg", -5),
    "warning": ("interface:Audio/toggle_001.ogg", -8),
    "music_menu": (OGA + "simple_loop.ogg", -10),
    "music_round": (OGA + "HappyClappyLoop.wav", -9),
}


def download(url):
    request = urllib.request.Request(url, headers={"User-Agent": "bombercat-import-audio"})
    return urllib.request.urlopen(request).read()


def build():
    os.makedirs(OUT, exist_ok=True)
    packs = {}
    with tempfile.TemporaryDirectory() as folder:
        for name, (source, peak) in SOUNDS.items():
            pack, _, inside = source.partition(":")
            if pack in PACKS:
                if pack not in packs:
                    packs[pack] = zipfile.ZipFile(io.BytesIO(download(PACKS[pack])))
                data = packs[pack].read(inside)
            else:
                data = download(source)
            original = os.path.join(folder, name + os.path.splitext(source)[1])
            with open(original, "wb") as file:
                file.write(data)
            measured = subprocess.run(["ffmpeg", "-i", original, "-af", "volumedetect", "-f", "null", "-"],
                                      capture_output=True, text=True).stderr
            loudest = float(re.search(r"max_volume: ([-0-9.]+)", measured).group(1))
            subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", original, "-map_metadata", "-1",
                            "-af", "volume=%.1fdB" % (peak - loudest), "-c:a", "libvorbis", "-q:a", "5",
                            os.path.join(OUT, name + ".ogg")], check=True)
            print(name)


if __name__ == "__main__":
    build()
