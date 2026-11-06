"""Pull the screenshot set off the artifacts branch through the GitHub API.

`git fetch` on that branch keeps dying (it carries every past IPA, so the pack
is huge) and raw.githubusercontent.com is unreachable from here, while
api.github.com answers fine. The contents endpoint returns one file at a time as
base64, which is slower but actually works.
"""

import base64
import json
import pathlib
import time
import urllib.request

REPO = "MoMelly/xk7q2m9v"
BRANCH = "artifacts"
OUT = pathlib.Path(__file__).resolve().parent.parent / "_artifacts" / "peek" / "shots"
HEADERS = {"User-Agent": "Mozilla/5.0", "Accept": "application/vnd.github+json"}


def get(url, tries=4):
    last = None
    for attempt in range(tries):
        try:
            request = urllib.request.Request(url, headers=HEADERS)
            with urllib.request.urlopen(request, timeout=30) as response:
                return response.read()
        except Exception as error:  # noqa: BLE001 - 网络抖动什么都可能抛
            last = error
            time.sleep(1.2 * (attempt + 1))
    raise last


OUT.mkdir(parents=True, exist_ok=True)
for stale in OUT.glob("*.png"):
    stale.unlink()

listing = json.loads(get(f"https://api.github.com/repos/{REPO}/contents/shots?ref={BRANCH}"))
items = [item for item in listing if item["name"].endswith(".png")]
print("files on branch:", len(items))

skipped = []
for item in items:
    name = item["name"]
    try:
        payload = json.loads(
            get(f"https://api.github.com/repos/{REPO}/contents/shots/{name}?ref={BRANCH}")
        )
        data = base64.b64decode(payload["content"])
        (OUT / name).write_bytes(data)
    except Exception as error:  # noqa: BLE001 - 单张断了不该拖死整批
        skipped.append(f"{name}: {type(error).__name__}")

print("downloaded", len(list(OUT.glob('*.png'))), "skipped", skipped)
