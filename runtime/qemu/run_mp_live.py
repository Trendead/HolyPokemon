#!/usr/bin/env python3
from __future__ import annotations

import socket
import subprocess
import time
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IMG = ROOT / "qemu" / "holyred_fat_v4.img"
ISO = ROOT / "templeos" / "TempleOS_run.iso"
ROM_DEFAULT = ROOT / "roms" / "POKEMON.GB"
ROM_ENV = "HOLY_RED_ROM"
MON_HOST = "127.0.0.1"
MON_PORT = 55622

SPECIAL = {
    " ": "spc",
    "\n": "ret",
    "(": "shift-9",
    ")": "shift-0",
    '"': "shift-0x2b",
    ":": "shift-semicolon",
    "/": "slash",
    ";": "semicolon",
    "[": "bracket_left",
    "]": "bracket_right",
    "=": "equal",
    "'": "apostrophe",
    ".": "dot",
    ",": "comma",
    "*": "shift-8",
    "+": "shift-equal",
    "?": "shift-slash",
    "-": "minus",
    "_": "shift-minus",
    "#": "shift-3",
}


def key_for_char(ch: str) -> str:
    if ch in SPECIAL:
        return SPECIAL[ch]
    if "A" <= ch <= "Z":
        return "shift-" + ch.lower()
    if ch.isalnum():
        return ch.lower()
    raise ValueError(ch)


def sendkey(name: str, delay_s: float = 0.05) -> None:
    ok = False
    for _ in range(4):
        try:
            sock = socket.create_connection((MON_HOST, MON_PORT), timeout=2)
            try:
                sock.settimeout(0.2)
                try:
                    sock.recv(4096)
                except OSError:
                    pass
                sock.sendall(f"sendkey {name}\n".encode())
                ok = True
                break
            finally:
                sock.close()
        except OSError:
            time.sleep(0.08)
    if not ok:
        raise RuntimeError(f"sendkey failed: {name}")
    time.sleep(delay_s)


def sendtext(txt: str, delay_s: float = 0.03) -> None:
    for ch in txt:
        sendkey(key_for_char(ch), delay_s)


def wait_monitor(timeout_s: float = 12.0) -> bool:
    t0 = time.time()
    while time.time() - t0 < timeout_s:
        try:
            sock = socket.create_connection((MON_HOST, MON_PORT), timeout=1.0)
            sock.close()
            return True
        except OSError:
            time.sleep(0.2)
    return False


def main() -> int:
    rom_src = Path(os.environ.get(ROM_ENV, str(ROM_DEFAULT))).expanduser()
    subprocess.run(["pkill", "-f", "qemu-system-x86_64.*holyred_fat_v4.img"], check=False)
    subprocess.run(["mcopy", "-o", "-i", f"{IMG}@@512", str(ROOT / "fat_root" / "GBCPUX.HC"), "::GB3.HC"], check=False)
    subprocess.run(["mcopy", "-o", "-i", f"{IMG}@@512", str(ROOT / "fat_root" / "MP.HC"), "::MP.HC"], check=False)
    subprocess.run(["mcopy", "-o", "-i", f"{IMG}@@512", str(ROOT / "fat_root" / "RED.HC"), "::RED.HC"], check=False)
    if rom_src.exists():
        subprocess.run(["mcopy", "-o", "-i", f"{IMG}@@512", str(rom_src), "::POKEMON.GB"], check=False)
    else:
        print(f"ROM not found at {rom_src}. Using existing ::POKEMON.GB in image.")

    qemu = subprocess.Popen(
        [
            "qemu-system-x86_64",
            "-m",
            "512",
            "-vga",
            "std",
            "-display",
            "none",
            "-vnc",
            "127.0.0.1:1,password=on",
            "-k",
            "en-us",
            "-monitor",
            f"tcp:{MON_HOST}:{MON_PORT},server,nowait",
            "-drive",
            f"file={IMG},format=raw,if=ide,index=0",
            "-cdrom",
            str(ISO),
            "-boot",
            "d",
        ]
    )

    if not wait_monitor(12.0):
        raise RuntimeError("QEMU monitor did not become available")
    sock = socket.create_connection((MON_HOST, MON_PORT), timeout=2)
    try:
        sock.settimeout(0.2)
        try:
            sock.recv(4096)
        except OSError:
            pass
        sock.sendall(b"set_password vnc holyred\n")
    finally:
        sock.close()

    time.sleep(14.0)
    sendkey("n")
    sendkey("ret")
    time.sleep(4.0)
    sendkey("n")
    sendkey("ret")
    time.sleep(1.4)

    sendtext("Mount;\n")
    time.sleep(1.4)
    sendkey("c")
    sendkey("ret")
    time.sleep(0.8)
    sendkey("s")
    time.sleep(0.8)
    sendtext("0x1f0\n")
    time.sleep(0.6)
    sendtext("0x3f4\n")
    time.sleep(0.6)
    sendtext("0\n")
    time.sleep(0.9)
    for k in ["ret", "ret", "ret", "esc", "esc", "ret", "ret"]:
        sendkey(k, 0.09)
    time.sleep(1.0)

    for line in [
        "U8 p[9];\n",
        "p[0]=67;\n",
        "p[1]=58;\n",
        "p[2]=82;\n",
        "p[3]=69;\n",
        "p[4]=68;\n",
        "p[5]=46;\n",
        "p[6]=72;\n",
        "p[7]=67;\n",
        "p[8]=0;\n",
        "ExeFile(p);\n",
    ]:
        sendtext(line, 0.028)

    print("TempleOS manual play launched.")
    print("Connect VNC viewer to localhost:5901")
    print("VNC password: holyred")
    print("Game controls in TempleOS: Arrows, Z, X, Enter, Backspace. Shift-Esc exits game script.")
    print(f"Set {ROM_ENV} to override ROM path, or place ROM at {ROM_DEFAULT}")
    print("Press Ctrl+C here to stop QEMU.")

    try:
        while True:
            if qemu.poll() is not None:
                break
            time.sleep(1.0)
    except KeyboardInterrupt:
        try:
            sendkey("shift-esc", 0.1)
            time.sleep(2.5)
        except Exception:
            pass
    finally:
        qemu.kill()
        qemu.wait(timeout=5)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
