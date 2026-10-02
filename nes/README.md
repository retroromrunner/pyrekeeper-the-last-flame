# PYREKEEPER - NES Version

NES ROM of PYREKEEPER: The Last Flame (Mapper 0 / NROM).

## Files
- `pyrekeeper.asm` - Main source (custom minimal 6502 syntax)
- `asm6502.py` - Minimal 6502 assembler used to build the ROM

## Building
```bash
python3 asm6502.py pyrekeeper.asm pyrekeeper.o
# Then use the build script in pyrekeeper-nes/ to link into .nes
```
Or see the Python build script that generates the iNES file directly.

## Controls
- D-pad: Move keeper
- B: Fire bolt
- Start: Start game / restart

## Status
In development. Basic gameplay implemented.
