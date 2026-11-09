"""Same job as fetch_shots_raw.py, but through the authenticated `gh` CLI.

The unauthenticated contents API allows 60 requests an hour and each screenshot
costs one (plus retries), so the second half of the batch starts returning 403.
`gh` carries the CLI token, which has its own much larger budget.
"""

import base64
import json
import pathlib
import subprocess

REPO = "MoMelly/xk7q2m9v"
BRANCH = "artifacts"
OUT = pathlib.Path(__file__).resolve().parent.parent / "_artifacts" / "peek" / "shots"
OUT.mkdir(parents=True, exist_ok=True)


def gh(*args):
    return subprocess.run(
        ["gh", *args], capture_output=True, check=True
    ).stdout


listing = json.loads(gh("api", f"repos/{REPO}/contents/shots?ref={BRANCH}"))
names = sorted(item["name"] for item in listing if item["name"].endswith(".png"))
print("on branch:", len(names))

# contents 接口对超过 1MB 的文件只回空 content。git/blobs 没有这个限制，
# 所以大图改走 blobs：先从 tree 里取 blob sha，再按 sha 拉。
tree = json.loads(gh("api", f"repos/{REPO}/git/trees/{BRANCH}?recursive=1"))
blobs = {
    entry["path"].split("/", 1)[1]: entry["sha"]
    for entry in tree["tree"]
    if entry["type"] == "blob" and entry["path"].startswith("shots/")
}

# 只比「文件在不在」是不够的：上一轮的图会一直留着，
# 页面明明改过，本地看到的还是老截图。所以按 blob sha 存一份索引，
# 内容变了才重下。
index_path = OUT.parent / "shots.sha.json"
try:
    index = json.loads(index_path.read_text(encoding="utf-8"))
except Exception:  # noqa: BLE001
    index = {}

failed = []
refreshed = 0
for name in names:
    target = OUT / name
    sha = blobs.get(name)
    if target.exists() and target.stat().st_size > 10_000 and sha and index.get(name) == sha:
        continue
    try:
        sha = blobs[name]
        raw = gh("api", f"repos/{REPO}/git/blobs/{sha}", "--jq", ".content")
        data = base64.b64decode(b"".join(raw.split()))
        if len(data) < 1024:
            raise RuntimeError(f"too small: {len(data)}")
        target.write_bytes(data)
        if sha:
            index[name] = sha
        refreshed += 1
    except subprocess.CalledProcessError as error:
        failed.append(name)
        print("fail", name, error.returncode)
    except Exception as error:  # noqa: BLE001
        failed.append(f"{name}: {error}")
        print("fail", name, error)

index_path.write_text(json.dumps(index, indent=1, sort_keys=True), encoding="utf-8")
print("on branch", len(names), "refreshed", refreshed, "failed", failed)
