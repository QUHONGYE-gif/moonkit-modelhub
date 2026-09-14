#!/usr/bin/env python3
"""Parity test: modelhub (MoonBit) vs huggingface_hub (Python) against the same mock.

Run inside the `moonbit` conda env (provides huggingface_hub + moon toolchain):
    conda run -n moonbit python scripts/parity_test.py
"""

import difflib
import os
import shutil
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PORT = os.environ.get("MOCK_PORT", "8765")
MOCK_ENDPOINT = f"http://127.0.0.1:{PORT}"
WORK = os.environ.get("PARITY_WORK", "/tmp/modelhub-parity")
PY_CACHE = os.path.join(WORK, "py")
MBT_CACHE = os.path.join(WORK, "mbt")
REAL_ENDPOINT = os.environ.get("PARITY_ENDPOINT")
REPO = os.environ.get("PARITY_REPO", "gpt2")


def cache_tree(root):
    entries = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames.sort()
        for name in sorted(filenames):
            path = os.path.join(dirpath, name)
            rel = os.path.relpath(path, root)
            if os.path.islink(path):
                entries.append(f"{rel} -> {os.readlink(path)}")
            else:
                entries.append(rel)
    return entries


server = None
try:
    endpoint = REAL_ENDPOINT
    shutil.rmtree(WORK, ignore_errors=True)
    os.makedirs(WORK)
    if endpoint is None:
        endpoint = MOCK_ENDPOINT
        server = subprocess.Popen(
            [sys.executable, os.path.join(ROOT, "scripts", "mock_hub_server.py")],
            env={**os.environ, "MOCK_PORT": PORT},
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        time.sleep(0.5)

    py = subprocess.run(
        [
            sys.executable,
            "-c",
            "import os\n"
            "from huggingface_hub import hf_hub_download, snapshot_download\n"
            "hf_hub_download(os.environ['PARITY_REPO'], 'config.json')\n"
            "snapshot_download(os.environ['PARITY_REPO'])\n",
        ],
        env={
            **os.environ,
            "PARITY_REPO": REPO,
            "HF_ENDPOINT": endpoint,
            "HF_HUB_CACHE": PY_CACHE,
            "HF_HUB_DISABLE_PROGRESS_BARS": "1",
            "HF_HUB_DISABLE_TELEMETRY": "1",
            "HF_HUB_OFFLINE": "0",
        },
        capture_output=True,
        text=True,
        cwd=ROOT,
    )
    if py.returncode != 0:
        print("python reference failed:")
        print(py.stdout)
        print(py.stderr)
        sys.exit(1)

    conda_prefix = os.environ.get("CONDA_PREFIX")
    if not conda_prefix:
        print("run this script inside the `moonbit` conda env")
        sys.exit(1)
    moon_bin = os.path.join(conda_prefix, "moon", "bin", "moon")
    moon_env = {
        **os.environ,
        "MOON_HOME": os.path.join(conda_prefix, "moon"),
    }
    mbt = subprocess.run(
        [
            moon_bin,
            "run",
            "cmd/main",
            "--target",
            "native",
            "--",
            "snapshot",
            REPO,
            "--endpoint",
            endpoint,
            "--cache-dir",
            MBT_CACHE,
        ],
        capture_output=True,
        text=True,
        cwd=ROOT,
        env=moon_env,
    )
    if mbt.returncode != 0:
        print("moonbit client failed:")
        print(mbt.stdout)
        print(mbt.stderr)
        sys.exit(1)

    py_tree = cache_tree(PY_CACHE)
    mbt_tree = cache_tree(MBT_CACHE)
    if py_tree == mbt_tree:
        print("PARITY OK: cache trees identical")
        for line in mbt_tree:
            print("  " + line)
        sys.exit(0)

    print("PARITY FAILED")
    diff = difflib.unified_diff(
        py_tree, mbt_tree, fromfile="python", tofile="moonbit", lineterm=""
    )
    sys.stdout.write("\n".join(diff) + "\n")
    sys.exit(1)
finally:
    if server is not None:
        server.terminate()
        server.wait(timeout=5)
