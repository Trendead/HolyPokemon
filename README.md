# HolyC Pokemon Red (TempleOS)

This repo contains a TempleOS-targeted Game Boy emulator path focused on running real Pokemon Red with real gameplay and persistent save support.

## Quick Start

1. Put your legally-owned Pokemon Red ROM at:
`/Users/macbook/Downloads/Pokemon - Red Version (USA, Europe) (SGB Enhanced).gb`

2. Launch:

```bash
python3 /Users/macbook/Desktop/HolyC_Pokemon/runtime/qemu/run_mp_live.py
```

3. Connect VNC:
- Host: `127.0.0.1:5901`
- Password: `holyred`

## Controls

- D-Pad: Arrow keys
- A: `Z`
- B: `X`
- Start: `Enter`
- Select: `Backspace`
- Exit game script: `Shift+Esc`
- Speed up / down: `W` / `Q`

## Save Management

Check status:

```bash
python3 /Users/macbook/Desktop/HolyC_Pokemon/runtime/qemu/save_manager.py status
```

Import a save:

```bash
python3 /Users/macbook/Desktop/HolyC_Pokemon/runtime/qemu/save_manager.py import "/path/to/file.sav"
```

Backup current save:

```bash
python3 /Users/macbook/Desktop/HolyC_Pokemon/runtime/qemu/save_manager.py backup
```

## Key Runtime Files

- `/Users/macbook/Desktop/HolyC_Pokemon/runtime/fat_root/GBCPUX.HC`
- `/Users/macbook/Desktop/HolyC_Pokemon/runtime/fat_root/MP.HC`
- `/Users/macbook/Desktop/HolyC_Pokemon/runtime/fat_root/RED.HC`
- `/Users/macbook/Desktop/HolyC_Pokemon/runtime/qemu/run_mp_live.py`
- `/Users/macbook/Desktop/HolyC_Pokemon/runtime/qemu/save_manager.py`
