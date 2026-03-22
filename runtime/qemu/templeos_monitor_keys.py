#!/usr/bin/env python3
"""Send monitor `sendkey` events to a QEMU monitor socket.

Usage examples:
  python templeos_monitor_keys.py --keys n ret n ret
  python templeos_monitor_keys.py --text 'ExeFile(f);\n'
"""

from __future__ import annotations

import argparse
import socket
import time


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
    "{": "shift-bracket_left",
    "}": "shift-bracket_right",
    "=": "equal",
    "'": "apostrophe",
    ".": "dot",
    ",": "comma",
    "<": "shift-comma",
    ">": "shift-dot",
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
    raise ValueError(f"Unsupported character for sendkey mapping: {ch!r}")


def send_keys(host: str, port: int, keys: list[str], delay_s: float) -> None:
    for key in keys:
        sent = False
        attempts = 0
        while (not sent) and attempts < 4:
            attempts += 1
            sock = socket.create_connection((host, port), timeout=2)
            try:
                sock.settimeout(0.2)
                try:
                    sock.recv(4096)
                except OSError:
                    pass
                sock.sendall(f"sendkey {key}\n".encode())
                sent = True
            except OSError:
                pass
            finally:
                sock.close()
            if not sent:
                time.sleep(0.08)
        time.sleep(delay_s)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=55566)
    parser.add_argument("--delay", type=float, default=0.03)
    parser.add_argument("--keys", nargs="*", default=[])
    parser.add_argument("--text", default="")
    args = parser.parse_args()

    keys: list[str] = []
    # Type text first, then explicit key presses (like Enter). This avoids
    # executing partial commands when callers pass both --text and --keys.
    if args.text:
        keys.extend(key_for_char(ch) for ch in args.text)
    keys.extend(args.keys)
    if not keys:
        return 0

    send_keys(args.host, args.port, keys, args.delay)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
