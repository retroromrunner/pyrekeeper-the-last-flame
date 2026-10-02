#!/bin/bash
set -e
cd "$(dirname "$0")"
python3 gen.py > textdata.asm
./dasm-src/bin/dasm pyrekeeper.asm -opyrekeeper.bin -f3
ls -la pyrekeeper.bin
