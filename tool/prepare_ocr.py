"""Package the pinned OCR client, portable WASM core and reading models locally."""
from pathlib import Path
import shutil
import subprocess

SOURCE = Path(__file__).resolve().parent / "ocr"
# Only these browser resources are public. Lockfile integrity is checked by npm
# at build time. The deployed application's OCR never reaches a package registry.
OCR_ASSETS = {
    "photo_ocr.mjs": "photo_ocr.mjs",
    "tesseract.esm.min.js": "node_modules/tesseract.js/dist/tesseract.esm.min.js",
    "worker.min.js": "node_modules/tesseract.js/dist/worker.min.js",
    "tesseract-core-lstm.js": "node_modules/tesseract.js-core/tesseract-core-lstm.js",
    "tesseract-core-lstm.wasm": "node_modules/tesseract.js-core/tesseract-core-lstm.wasm",
    "kor.traineddata.gz": "node_modules/@tesseract.js-data/kor/4.0.0_best_int/kor.traineddata.gz",
    "eng.traineddata.gz": "node_modules/@tesseract.js-data/eng/4.0.0_best_int/eng.traineddata.gz",
    "LICENSE-tesseract.txt": "node_modules/tesseract.js/LICENSE.md",
    "LICENSE-core.txt": "node_modules/tesseract.js-core/LICENSE",
    "NOTICE-worker.txt": "node_modules/tesseract.js/dist/worker.min.js.LICENSE.txt",
    "NOTICE-browser.txt": "node_modules/tesseract.js/dist/tesseract.min.js.LICENSE.txt",
    "NOTICE-models.txt": "NOTICE-models.txt",
}


def build(output: Path) -> None:
    subprocess.run(["npm", "ci", "--prefer-offline", "--ignore-scripts", "--no-audit",
                    "--no-fund"], cwd=SOURCE, check=True)
    output.mkdir(parents=True, exist_ok=True)
    for name, source in OCR_ASSETS.items():
        shutil.copyfile(SOURCE / source, output / name)


if __name__ == "__main__":
    build(SOURCE.parents[1] / "web" / "ocr")
