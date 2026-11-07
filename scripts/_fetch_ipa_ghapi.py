# -*- coding: utf-8 -*-
# Sandbox workaround: git fetch gets SIGTERM-killed here, but gh api works.
# Pull STATUS.txt + ipa from the artifacts branch via gh api, bytes all the way.
import base64
import json
import subprocess
import sys
from pathlib import Path

REPO = "MoMelly/xk7q2m9v"
ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "_artifacts" / "latest"
IPA = ROOT / "_artifacts" / "MiniPhone-unsigned.ipa"


def gh_api_json(url: str) -> dict:
    raw = subprocess.check_output(["gh", "api", url])
    return json.loads(raw.decode("utf-8"))


def blob(path: str) -> bytes:
    tree = gh_api_json(f"repos/{REPO}/git/trees/artifacts?recursive=1")
    sha = next(t["sha"] for t in tree["tree"] if t["path"] == path)
    b64 = gh_api_json(f"repos/{REPO}/git/blobs/{sha}")["content"]
    return base64.b64decode(b64)


status_raw = blob("STATUS.txt").decode("utf-8")
status = dict(
    line.split("=", 1) for line in status_raw.splitlines() if "=" in line
)
print(
    "run=%s sha=%s status=%s built_at=%s"
    % (status.get("run_id"), status.get("sha", "")[:7], status.get("status"), status.get("built_at"))
)

if status.get("status") != "success":
    print("BUILD NOT SUCCESS - keep old ipa")
    sys.exit(1)

data = blob("MiniPhone-unsigned.ipa")
OUT.mkdir(parents=True, exist_ok=True)
(OUT / "MiniPhone-unsigned.ipa").write_bytes(data)
IPA.write_bytes(data)
print("ipa bytes:", len(data))
print("saved:", IPA)
for name in ("STATUS.txt", "build.log"):
    try:
        (OUT / name).write_bytes(blob(name))
    except Exception as exc:  # noqa: BLE001
        print("skip", name, exc)
print("OK")
