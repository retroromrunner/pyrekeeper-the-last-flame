# PYREKEEPER - Atari 2600 Version

4KB Atari 2600 ROM of PYREKEEPER: The Last Flame.

## Files
- `pyrekeeper.asm` - Main source (DASM syntax)
- `textdata.asm` - Generated playfield text data (do not edit manually)
- `gen.py` - Generates textdata.asm from font definitions
- `build.sh` - Build script

## Building
Requires DASM:
```bash
./build.sh
```
This runs `gen.py` to regenerate textdata.asm, then assembles with DASM to `pyrekeeper.bin`.

## Status
In development. Known issues with display timing on real hardware/emulators.
