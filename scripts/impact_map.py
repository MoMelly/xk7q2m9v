#!/usr/bin/env python3
"""生成「影响面索引」的原始矩阵，供 docs/IMPACT.md 引用。

只做一件机械的事：扫 Features/ 与 Shell/ 下的 Swift 文件，看每个文件引用了
哪些共享面（主题、数据、提示词、桌面、播放器……）。改一个共享面之前先跑一遍，
看会波及多少文件；改完之后再跑一遍，看数字有没有超出预期。

用法：
    python scripts/impact_map.py            # 打印 markdown 表
    python scripts/impact_map.py --top 12   # 只列被引用最多的 12 个共享面
"""

from __future__ import annotations

import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "MiniPhone"

# 共享面：名字 -> 在代码里的识别串。
# 加新的共享面（比如新的全局 store）就补在这里，否则矩阵看不见它。
SHARED = {
    "Theme": "Theme.",
    "AppSurface": "AppSurface",
    "Metrics": "Metrics.",
    "GroupedSection": "GroupedSection",
    "Companion": "Companion",
    "WorldStore/WorldState": "WorldStore",
    "UserProfile": "UserProfile",
    "IdentityScope": "IdentityScope",
    "PromptBuilder": "PromptBuilder",
    "SettingsStore": "SettingsStore",
    "AppCatalog": "AppCatalog",
    "HomeLayout": "HomeLayout",
    "PlayerService": "PlayerService",
    "StoredMessage": "StoredMessage",
    "ChatViewModel": "ChatViewModel",
    "PreviewSeed": "PreviewSeed",
    "DataBackup": "DataBackup",
}


def scanned_files() -> list[Path]:
    out: list[Path] = []
    for folder in ("Features", "Shell"):
        base = SRC / folder
        if base.is_dir():
            out.extend(sorted(base.rglob("*.swift")))
    return out


def main() -> int:
    top: int | None = None
    if "--top" in sys.argv:
        top = int(sys.argv[sys.argv.index("--top") + 1])

    files = scanned_files()
    if not files:
        print("找不到 MiniPhone/Features 或 MiniPhone/Shell")
        return 1

    rows: list[tuple[str, int, list[str]]] = []
    counter: Counter[str] = Counter()
    for path in files:
        text = path.read_text(encoding="utf-8", errors="replace")
        hits = [name for name, needle in SHARED.items() if needle in text]
        for name in hits:
            counter[name] += 1
        rows.append((path.relative_to(SRC).as_posix(), len(text.splitlines()), hits))

    print("| 文件 | 行数 | 依赖的共享面 |")
    print("|---|---|---|")
    for rel, lines, hits in rows:
        print(f"| `{rel}` | {lines} | {', '.join(hits) or '—'} |")

    print()
    print("| 共享面 | 被多少个文件引用 |")
    print("|---|---|")
    for name, count in counter.most_common(top):
        print(f"| {name} | {count} |")

    return 0


if __name__ == "__main__":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except AttributeError:
        pass
    sys.exit(main())
