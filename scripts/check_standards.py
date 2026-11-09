#!/usr/bin/env python3
"""按 docs/STANDARDS.md 检查代码。

只做机械能判断的规则。判断不了「这个组件该不该抽」，那部分只能靠评审。

用法：
    python scripts/check_standards.py

退出码 0 表示通过；1 表示有违规。CI 在生成工程之前跑这一步。
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "MiniPhone"

# 允许出现 DateFormatter 的文件：格式化只在 TimeFormat 里做。
DATE_FORMATTER_ALLOWED = {
    "MiniPhone/Support/TimeFormat.swift",
    "MiniPhone/Data/Persistence/DataBackup.swift",  # ISO8601，机器可读时间戳
}

# 允许直接写 Color(red:...) 的位置：色板本身。
COLOR_LITERAL_ALLOWED = {
    "MiniPhone/DesignSystem/Theme.swift",
    "MiniPhone/DesignSystem/CharacterPalette.swift",
    "MiniPhone/DesignSystem/AppIconPalette.swift",
    "MiniPhone/Shell/AppCatalog.swift",
}

# 状态块标记只允许出现在装配方和解析器里。
META_TAG_ALLOWED = {
    "MiniPhone/Domain/Roleplay/PromptBuilder.swift",
    "MiniPhone/Domain/State/GenerationPlan.swift",
}

WARN_LINES = 400
ERROR_LINES = 600

errors: list[str] = []
warnings: list[str] = []


def rel(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def add_error(path: Path, line: int, message: str) -> None:
    location = f"{rel(path)}:{line}" if line else rel(path)
    errors.append(f"{location}  {message}")


def add_warning(path: Path, line: int, message: str) -> None:
    location = f"{rel(path)}:{line}" if line else rel(path)
    warnings.append(f"{location}  {message}")


def swift_files() -> list[Path]:
    if not SRC.is_dir():
        return []
    return sorted(SRC.rglob("*.swift"))


def check_layer_imports(path: Path, lines: list[str]) -> None:
    """Domain 层不能依赖 UI 框架。"""
    relative = rel(path)
    if "/Domain/" not in f"/{relative}" and not relative.startswith("MiniPhone/Domain/"):
        return

    forbidden = ("SwiftUI", "SwiftData", "UIKit", "AppKit")
    for index, line in enumerate(lines, start=1):
        stripped = line.strip()
        if stripped.startswith("import "):
            module = stripped.split()[1]
            if module in forbidden:
                add_error(path, index, f"Domain 层不允许 import {module}（业务规则不能依赖界面框架）")


def check_duplicate_wheels(path: Path, lines: list[str]) -> None:
    """已经有过唯一入口的东西，不许再实现一遍。"""
    relative = rel(path)

    for index, line in enumerate(lines, start=1):
        if "DateFormatter(" in line and relative not in DATE_FORMATTER_ALLOWED:
            add_error(path, index, "日期格式化统一走 TimeFormat，不要在这里新建 DateFormatter")

        if "Timer.publish" in line:
            add_error(path, index, "定时刷新统一用 TimelineView(.everyMinute)，不要用 Timer.publish")

        if "import Combine" in line:
            add_warning(path, index, "项目里唯一需要 Combine 的地方已改用 TimelineView，确认这个 import 还有用")

        if "glassSurface(cornerRadius: 17)" in line:
            add_warning(path, index, "34×34 玻璃圆按钮统一用 GlassIconButton")

        if "Color(red:" in line and relative not in COLOR_LITERAL_ALLOWED:
            if relative.startswith("MiniPhone/Features/") or relative.startswith("MiniPhone/Shell/"):
                add_warning(path, index, "主题色走 Theme / AvatarTint，视图里不要直接写字面色值")

        # 外壳强制深色模式，Form 的 grouped 单元格会跟着变黑，
        # 叠在深色背景上就是那层「脏灰框」。设置页已改白卡，先守住这一处。
        if relative.startswith("MiniPhone/Features/Settings/") and (
            "Form {" in line or "Form{" in line
        ):
            add_error(path, index, "设置页不用 Form；改 whiteCard 分组")

        if ("WorldStore(" in line) and (
            relative.startswith("MiniPhone/Features/") or relative.startswith("MiniPhone/Shell/")
        ):
            add_error(path, index, "世界状态只用 WorldStore.shared，不要另建实例")

        if "<<<meta>>>" in line and relative not in META_TAG_ALLOWED:
            add_error(path, index, "状态块标记只允许出现在 PromptBuilder 与 ReplyEnvelope")

        # 提示词只允许出现在 PromptBuilder。
        if relative.startswith("MiniPhone/Features/"):
            for marker in ("你在扮演", "你在替一个角色", "只输出正文", "【角色】", "【对话形式】"):
                if marker in line:
                    add_error(path, index, f"提示词必须放在 PromptBuilder（发现「{marker}」）")


def check_launch_permissions(path: Path, lines: list[str]) -> None:
    """App 入口不得申请系统权限。

    首次启动的授权框由系统绘制在 App 之上，SwiftUI 层级里关不掉；
    它会盖住锁屏，也会让模拟器截图全部作废。权限申请只能绑到用户动作
    或真正要用到该能力的那一刻。
    """
    if not rel(path).startswith("MiniPhone/App/"):
        return

    for index, line in enumerate(lines, start=1):
        if line.lstrip().startswith("//"):
            continue
        if "requestAuthorization" in line:
            add_error(
                path,
                index,
                "启动路径不允许申请系统权限；绑定到设置开关或首次真实使用时",
            )


# DESIGN.md §8 的门禁：浅色 App 的页面里不许出现裸视觉值。
DESIGN_GATED = (
    "MiniPhone/Features/Scenes/",
    "MiniPhone/Features/Settings/",
)

CORNER_LITERAL = re.compile(r"cornerRadius:\s*[0-9]")


def check_design_gates(path: Path, lines: list[str]) -> None:
    """浅色 App 的页面按 docs/DESIGN.md §8 卡。

    这三条都踩过：给每行都加阴影，在 #F2F2F7 底上叠出一圈灰边；
    用 whiteCard 包整段列表，八页共用一个形状；圆角各自写数字，
    改了 token 对不齐。判断不了「像不像系统 App」，但能挡住裸值。
    """
    relative = rel(path)
    if not relative.startswith(DESIGN_GATED):
        return

    for index, line in enumerate(lines, start=1):
        if line.strip().startswith("//"):
            continue

        if ".shadow(" in line:
            add_error(path, index, "浅色列表不用阴影；要阴影走 Theme.ShadowStyle，只给浮层")

        if ".whiteCard()" in line:
            add_error(path, index, "列表用 GroupedSection / GroupedRow，不要用 whiteCard 包整段列表")

        if CORNER_LITERAL.search(line):
            add_error(path, index, "圆角走 PhoneMetrics.Radius，不要写字面量")


def check_file_size(path: Path, lines: list[str]) -> None:
    count = len(lines)
    if count > ERROR_LINES:
        add_error(path, 0, f"文件 {count} 行，超过 {ERROR_LINES} 行上限，需要拆分")
    elif count > WARN_LINES:
        add_warning(path, 0, f"文件 {count} 行，超过建议的 {WARN_LINES} 行")


def strip_comments_and_strings(text: str) -> str:
    """把注释和字符串字面量替换成空。

    直接按 `//` 切行会误伤 `"https://..."` 这种字符串（第一版就栽在这），
    所以逐字符扫描：只有不在字符串里时，`//` 才是注释。
    """
    out: list[str] = []
    index = 0
    length = len(text)
    in_string = False
    in_line_comment = False
    in_block_comment = False

    while index < length:
        char = text[index]
        nxt = text[index + 1] if index + 1 < length else ""

        if in_line_comment:
            if char == "\n":
                in_line_comment = False
                out.append(char)
        elif in_block_comment:
            if char == "*" and nxt == "/":
                in_block_comment = False
                index += 1
            elif char == "\n":
                out.append(char)
        elif in_string:
            if char == "\\":
                index += 1
            elif char == '"':
                in_string = False
            elif char == "\n":
                # 未闭合的字符串：保守处理，退出字符串状态
                in_string = False
                out.append(char)
        else:
            if char == "/" and nxt == "/":
                in_line_comment = True
                index += 1
            elif char == "/" and nxt == "*":
                in_block_comment = True
                index += 1
            elif char == '"' and text.startswith('"""', index):
                # 多行字符串整段跳过：里面常有括号和引号，逐字符扫会乱。
                end = text.find('"""', index + 3)
                if end == -1:
                    break
                index = end + 2
            elif char == '"':
                in_string = True
            else:
                out.append(char)

        index += 1

    return "".join(out)


def check_line_endings_and_brackets(path: Path, raw: bytes, text: str) -> None:
    # Windows 上 core.autocrlf=true 会把工作区检出成 CRLF，本地必然触发，
    # 那属于检出的表象而不是提交内容。换行符只在 CI（Linux/macOS）上把关。
    if not sys.platform.startswith("win") and b"\r\n" in raw:
        add_error(path, 0, "文件是 CRLF 换行；仓库统一 LF，CRLF 进 shell 脚本会变成 \\r 报错")

    # 括号平衡：字符串和注释已经剥掉，剩下的才是真正的代码结构。
    pairs = {"(": ")", "[": "]", "{": "}"}
    closers = {value: key for key, value in pairs.items()}
    stack: list[str] = []
    unbalanced = False
    for char in strip_comments_and_strings(text):
        if char in pairs:
            stack.append(char)
        elif char in closers:
            if stack and stack[-1] == closers[char]:
                stack.pop()
            else:
                unbalanced = True
                break
    if unbalanced or stack:
        add_warning(path, 0, "括号看起来不配对，确认一下")


KEY_PATTERN = re.compile(r"sk-[A-Za-z0-9]{20,}")


def check_secrets(path: Path, lines: list[str]) -> None:
    for index, line in enumerate(lines, start=1):
        if KEY_PATTERN.search(line):
            add_error(path, index, "疑似 API Key 明文，密钥只能存 Keychain")


def main() -> int:
    files = swift_files()
    if not files:
        print("找不到 MiniPhone/ 下的 Swift 源码")
        return 1

    for path in files:
        raw = path.read_bytes()
        text = raw.decode("utf-8", errors="replace")
        lines = text.split("\n")

        check_layer_imports(path, lines)
        check_duplicate_wheels(path, lines)
        check_design_gates(path, lines)
        check_launch_permissions(path, lines)
        check_file_size(path, lines)
        check_line_endings_and_brackets(path, raw, text)
        check_secrets(path, lines)

    print(f"检查了 {len(files)} 个 Swift 文件")

    if warnings:
        print(f"\n警告 {len(warnings)} 条：")
        for item in warnings:
            print(f"  {item}")

    if errors:
        print(f"\n违规 {len(errors)} 条：")
        for item in errors:
            print(f"  {item}")
        print("\n规范见 docs/STANDARDS.md")
        return 1

    print("\n通过")
    return 0


if __name__ == "__main__":
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    except AttributeError:
        pass
    sys.exit(main())
