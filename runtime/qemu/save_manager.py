#!/usr/bin/env python3
from __future__ import annotations

import argparse
import subprocess
from pathlib import Path

ROOT = Path("/Users/macbook/Desktop/HolyC_Pokemon")
IMG = ROOT / "runtime" / "qemu" / "holyred_fat_v4.img"
MTOOLS_DRIVE = f"{IMG}@@512"


def run(cmd: list[str], check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(cmd, check=check, text=True, capture_output=True)


def list_files() -> str:
    cp = run(["mdir", "-/", "-i", MTOOLS_DRIVE, "::"], check=True)
    return cp.stdout


def backup_to(host_path: Path) -> None:
    host_path.parent.mkdir(parents=True, exist_ok=True)
    run(["mcopy", "-o", "-i", MTOOLS_DRIVE, "::POKEMON.SAV", str(host_path)], check=True)


def remove_in_image() -> None:
    run(["mdel", "-i", MTOOLS_DRIVE, "::POKEMON.SAV"], check=False)


def import_from(host_path: Path) -> None:
    if not host_path.exists():
        raise FileNotFoundError(host_path)
    if host_path.stat().st_size not in (32768,):
        raise ValueError(
            f"Unexpected save size {host_path.stat().st_size} bytes; expected 32768 for Pokemon Red."
        )
    run(["mcopy", "-o", "-i", MTOOLS_DRIVE, str(host_path), "::POKEMON.SAV"], check=True)


def main() -> int:
    parser = argparse.ArgumentParser(description="Manage Pokemon Red save in TempleOS FAT image.")
    sub = parser.add_subparsers(dest="cmd", required=True)

    sub.add_parser("status", help="Show whether POKEMON.SAV exists in disk image.")

    p_backup = sub.add_parser("backup", help="Backup POKEMON.SAV from image to host path.")
    p_backup.add_argument(
        "--out",
        default=str(ROOT / "runtime" / "qemu" / "saves" / "pokemon_red_backup.sav"),
        help="Output host path",
    )

    p_import = sub.add_parser("import", help="Import host .sav into image as POKEMON.SAV.")
    p_import.add_argument("path", help="Path to .sav file on host")
    p_import.add_argument("--no-backup", action="store_true", help="Skip pre-import backup")

    args = parser.parse_args()

    if args.cmd == "status":
        out = list_files()
        if "POKEMON  SAV" in out:
            print("POKEMON.SAV present in image.")
        else:
            print("POKEMON.SAV NOT present in image.")
        return 0

    if args.cmd == "backup":
        out_path = Path(args.out).expanduser().resolve()
        backup_to(out_path)
        print(f"Backed up save to: {out_path}")
        return 0

    if args.cmd == "import":
        src = Path(args.path).expanduser().resolve()
        if not args.no_backup:
            dst = ROOT / "runtime" / "qemu" / "saves" / "pre_import_backup.sav"
            try:
                backup_to(dst)
                print(f"Existing save backed up to: {dst}")
            except subprocess.CalledProcessError:
                print("No existing save to back up.")
        remove_in_image()
        import_from(src)
        print(f"Imported save from: {src}")
        return 0

    return 1


if __name__ == "__main__":
    raise SystemExit(main())
