# HolyC Pokemon Red 

This repo contains a TempleOS targeted Game Boy emulator path focused on running Pokemon Red.
## Quick Start

1. Clone this repo and `cd` into it.

2. Provide your legally-owned Pokemon Red ROM in either way:
- Place it at `runtime/roms/POKEMON.GB`, or
- Set env var `HOLY_RED_ROM` to your ROM path.

3. Launch:

```bash
python3 runtime/qemu/run_mp_live.py
```

4. Connect VNC:
- Host: `127.0.0.1:5901`
- Password: `holyred`

## Cross-Platform Notes

- macOS/Linux (bash/zsh):
```bash
export HOLY_RED_ROM="/absolute/path/to/Pokemon Red.gb"
python3 runtime/qemu/run_mp_live.py
```

- Windows PowerShell:
```powershell
$env:HOLY_RED_ROM="C:\path\to\Pokemon Red.gb"
python runtime/qemu/run_mp_live.py
```

## Controls

- D-Pad: Arrow keys
- A: `Z`
- B: `X`
- Start: `A`
- Select: `S`
- Exit game script: `Shift+Esc`
- Speed up / down: `W` / `Q`

## Save Management

Check status:

```bash
python3 runtime/qemu/save_manager.py status
```

Import a save:

```bash
python3 runtime/qemu/save_manager.py import "/path/to/file.sav"
```

Backup current save:

```bash
python3 runtime/qemu/save_manager.py backup
```

## Key Runtime Files

- `runtime/fat_root/GBCPUX.HC`
- `runtime/fat_root/MP.HC`
- `runtime/fat_root/RED.HC`
- `runtime/qemu/run_mp_live.py`
- `runtime/qemu/save_manager.py`
