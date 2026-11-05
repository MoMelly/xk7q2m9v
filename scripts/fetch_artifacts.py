#!/usr/bin/env python3
"""从 artifacts 分支取回最新构建产物。

用法：
    python scripts/fetch_artifacts.py

只用 git 就能拿到产物，不需要打开 GitHub 网页或下载 artifact。
全程按 bytes 读写：Windows PowerShell 的 `>` 会把二进制重编码成 UTF-16，
ipa 一旦经过它就会损坏，所以这里不用任何 shell 重定向。
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "_artifacts" / "latest"
INSTALLER_IPA = ROOT / "_artifacts" / "MiniPhone-unsigned.ipa"

ALWAYS = ["STATUS.txt", "build.log", "sim-build.log"]
ON_SUCCESS = [
    "MiniPhone-unsigned.ipa",
    "shots/lock.png",
    "shots/home.png",
    "shots/chat.png",
    "shots/moments.png",
    "shots/settings.png",
]


def git(*args: str) -> bytes:
    return subprocess.check_output(["git", "-C", str(ROOT), *args])


def fetch_blob(name: str) -> bytes | None:
    try:
        return git("show", f"FETCH_HEAD:{name}")
    except subprocess.CalledProcessError:
        # 构建在打包或截图之前就失败时，这些文件不会出现在产物分支上。
        return None


def write(name: str, data: bytes) -> int:
    path = OUT / name
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return len(data)


def main() -> int:
    subprocess.run(
        ["git", "-C", str(ROOT), "fetch", "origin", "artifacts", "--force"],
        check=True,
        stdout=subprocess.DEVNULL,
    )

    status_bytes = fetch_blob("STATUS.txt")
    if status_bytes is None:
        print("artifacts 分支上没有 STATUS.txt，产物不完整")
        return 1

    status = dict(
        line.split("=", 1)
        for line in status_bytes.decode("utf-8").splitlines()
        if "=" in line
    )
    print(
        f"run={status.get('run_id', '?')} sha={status.get('sha', '?')[:7]} "
        f"status={status.get('status', '?')} built_at={status.get('built_at', '?')}"
    )

    write("STATUS.txt", status_bytes)
    for name in ALWAYS[1:]:
        data = fetch_blob(name)
        if data:
            write(name, data)

    if status.get("status") != "success":
        print("构建未成功，只取回日志；装机用的 ipa 保持原样")
        return 1

    success = True
    for name in ON_SUCCESS:
        data = fetch_blob(name)
        if data is None:
            print(f"  缺少 {name}")
            success = False
            continue
        print(f"  {len(data):9d}  {name}")
        write(name, data)

    if success:
        INSTALLER_IPA.write_bytes((OUT / "MiniPhone-unsigned.ipa").read_bytes())
        print(f"\n装机文件：{INSTALLER_IPA}")
        print(f"截图：{OUT / 'shots'}")
    return 0 if success else 1


if __name__ == "__main__":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except AttributeError:
        pass
    sys.exit(main())
