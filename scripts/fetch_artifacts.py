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

LOGS = ["STATUS.txt", "build.log", "sim-build.log"]


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


def shots_on_branch() -> list[str]:
    """按分支实际内容列截图，而不是写死名单。

    截图状态会随页面增减变化；写死名单会让新页面永远拉不回来，
    还会把上一次残留的旧图当成这次的验收结果。
    """
    listing = git("ls-tree", "-r", "--name-only", "FETCH_HEAD", "shots")
    return [
        line.strip()
        for line in listing.decode("utf-8").splitlines()
        if line.strip().endswith(".png")
    ]


def clear_old_shots() -> None:
    folder = OUT / "shots"
    if not folder.is_dir():
        return
    for path in folder.glob("*.png"):
        path.unlink()


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

    clear_old_shots()
    for name in LOGS:
        data = fetch_blob(name)
        if data:
            write(name, data)

    if status.get("status") != "success":
        print("构建未成功，只取回日志；装机用的 ipa 保持原样")
        return 1

    ipa = fetch_blob("MiniPhone-unsigned.ipa")
    if ipa is None:
        print("缺少 MiniPhone-unsigned.ipa，装机文件保持原样")
        return 1

    print(f"  {len(ipa):9d}  MiniPhone-unsigned.ipa")
    write("MiniPhone-unsigned.ipa", ipa)
    INSTALLER_IPA.parent.mkdir(parents=True, exist_ok=True)
    INSTALLER_IPA.write_bytes(ipa)
    print(f"\n装机文件：{INSTALLER_IPA}")

    shots = shots_on_branch()
    for name in shots:
        data = fetch_blob(name)
        if data is None:
            print(f"  缺少 {name}")
            continue
        print(f"  {len(data):9d}  {name}")
        write(name, data)
    print(f"\n截图 {len(shots)} 张：{OUT / 'shots'}")
    return 0


if __name__ == "__main__":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except AttributeError:
        pass
    sys.exit(main())
