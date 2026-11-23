#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")/.."

python3 tool/prepare_ocr.py
flutter pub get --enforce-lockfile
flutter build web --release --no-wasm-dry-run --csp --no-web-resources-cdn --no-source-maps
mkdir -p build/web/review
cp build/web/index.html build/web/review/index.html
