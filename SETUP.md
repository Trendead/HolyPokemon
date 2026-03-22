# Setup

This minimal source package excludes large VM artifacts and ROMs.

You must provide:
- TempleOS boot ISO at `runtime/templeos/TempleOS_run.iso`
- TempleOS FAT disk image at `runtime/qemu/holyred_fat_v4.img`
- Pokemon Red ROM at your local path expected by `run_mp_live.py`

Launch:

```bash
python3 runtime/qemu/run_mp_live.py
```
