#!/usr/bin/env python3
"""Kalastajan repliikit puhesynteesillä WAV-tiedostoiksi (assets/sounds/voice/).

Puhe tehdään Piper-puhesynteesillä ja suomenkielisellä fi_FI-harri-äänellä
(opetusaineisto CC0). Repliikit ovat pelissä tiedostossa
scripts/audio/angler_voice.gd – samat tunnisteet molemmissa.

Käyttö (vaatii uv:n, lataa äänimallin ~60 Mt ensimmäisellä kerralla):
    python3 tools/make_voice.py            (kaikki repliikit)
    python3 tools/make_voice.py eagle      (vain annetut tunnisteet)
Tiedostot voi korvata omilla äänityksillä (22 050 Hz mono WAV, sama nimi).
"""
import os
import subprocess
import sys
import urllib.request
import wave

import numpy as np

LINES = {
    "start": "No niin, kalaan.",
    "bite_1": "No nyt tärppäs!",
    "bite_2": "Nyt nykäsi!",
    "hooked": "Kala kiinni!",
    "lost": "Ei perhana, se pääsi irti!",
    "snap": "Voi hemmetti, siima poikki!",
    "snag": "Ei kai taas pohjassa...",
    "shore": "Ei sinne pitänyt heittää.",
    "quiet_1": "Ei perhana tule mitään.",
    "quiet_2": "Onkohan tässä järvessä kaloja ollenkaan?",
    "big": "Onpa järkäle!",
    "small": "Pikkuinen, mutta kala kuitenkin.",
    "landed": "Siinä se on!",
    "rain": "Alkaa sataa. Pitäisköhän lähteä kotiin?",
    "hole": "Reikä valmis. Nyt pilkille.",
    "anchor": "Perkele, ankkuri!",
    "eagle": "Oho! Merikotka!",
    # Lajin tunnistus veneen lähellä
    "fish_hauki": "Hauki!",
    "fish_ahven": "Ahven!",
    "fish_sarki": "Särki!",
    "fish_kiiski": "Kiiski!",
    "fish_lahna": "Lahna!",
    "fish_made": "Made!",
}

# Puhesynteesille eri kirjoitusasu kuin tekstitykseen: Piper venyttää
# huudahdusmerkkiin päättyvää "Oho!":ta, joten huudahdus sanotaan yhtenä lauseena
SPOKEN = {"eagle": "Oho merikotka!"}

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
OUT = os.path.join(ROOT, "assets", "sounds", "voice")
MODEL_DIR = os.path.join(ROOT, "data", "piper") # ei versionhallinnassa
VOICE = "fi_FI-harri-medium"
URL = "https://huggingface.co/rhasspy/piper-voices/resolve/main/fi/fi_FI/harri/medium/"


def download_model() -> str:
    os.makedirs(MODEL_DIR, exist_ok=True)
    for name in (VOICE + ".onnx", VOICE + ".onnx.json"):
        path = os.path.join(MODEL_DIR, name)
        if not os.path.exists(path):
            print("Ladataan", name)
            urllib.request.urlretrieve(URL + name, path)
    return os.path.join(MODEL_DIR, VOICE + ".onnx")


def synthesize(model: str, text: str, path: str) -> None:
    subprocess.run(
        ["uvx", "--python", "3.12", "--from", "piper-tts", "piper", "-m", model, "-f", path,
         "--length-scale", "1.05", "--sentence-silence", "0.1"],
        input=text.encode("utf-8"), check=True, capture_output=True)


def tidy(path: str) -> None:
    """Hiljaisuus pois alusta ja lopusta, voimakkuus tasaiseksi, pehmeät reunat."""
    with wave.open(path, "rb") as w:
        rate = w.getframerate()
        data = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768.0
    loud = np.nonzero(np.abs(data) > 0.02)[0]
    if loud.size:
        data = data[max(0, loud[0] - int(0.03 * rate)):loud[-1] + int(0.12 * rate)]
    data *= 0.7 / (np.max(np.abs(data)) + 1e-9)
    fade = int(0.01 * rate)
    data[:fade] *= np.linspace(0, 1, fade)
    data[-fade:] *= np.linspace(1, 0, fade)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes((data * 32767).astype(np.int16).tobytes())


def main() -> None:
    model = download_model()
    os.makedirs(OUT, exist_ok=True)
    keys = sys.argv[1:] or list(LINES)
    for key in keys:
        text = LINES[key]
        path = os.path.join(OUT, key + ".wav")
        synthesize(model, SPOKEN.get(key, text), path)
        tidy(path)
        print(f"{key}.wav  {text}")


if __name__ == "__main__":
    main()
