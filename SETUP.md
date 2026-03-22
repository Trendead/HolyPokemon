# Setup

This minimal source package excludes large VM artifacts and ROMs.

You must provide:
- TempleOS boot ISO at `runtime/templeos/TempleOS_run.iso`
- TempleOS FAT disk image at `runtime/qemu/holyred_fat_v4.img`
- Pokemon Red ROM at either:
  - `runtime/roms/POKEMON.GB`, or
  - any local path set via `HOLY_RED_ROM`

Launch:

```bash
python3 runtime/qemu/run_mp_live.py
```

Examples:

macOS/Linux:
```bash
export HOLY_RED_ROM="/absolute/path/to/Pokemon Red.gb"
python3 runtime/qemu/run_mp_live.py
```

Windows PowerShell:
```powershell
$env:HOLY_RED_ROM="C:\path\to\Pokemon Red.gb"
python runtime/qemu/run_mp_live.py
```
