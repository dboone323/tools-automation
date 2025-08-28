#!/usr/bin/env python3
import json
import os
import time

import requests
from flask import Flask, jsonify, render_template, send_from_directory

MCP_URL = os.environ.get("MCP_URL", "http://127.0.0.1:5005")
ART_DIR = os.path.join(os.path.dirname(__file__), "artifacts")
# create Flask app; keep template folder next to this file
app = Flask(__name__, template_folder="templates")
# static dir next to this file
STATIC_DIR = os.path.join(os.path.dirname(__file__), "static")


# serve static assets under /assets with cache headers
@app.route("/assets/<path:filename>")
def assets(filename):
    # serve from the 'static' folder in this package
    resp = send_from_directory(STATIC_DIR, filename)
    # add conservative caching for static assets
    resp.headers["Cache-Control"] = "public, max-age=86400"
    return resp


# reuse a session and identify this proxy to MCP so server-side whitelist can work
session = requests.Session()
session.headers.update({"X-Client-Id": "dashboard"})

# Load asset manifest (optional) so templates can reference hashed filenames
ASSET_MANIFEST = {}
manifest_path = os.path.join(STATIC_DIR, "asset-manifest.json")
if os.path.exists(manifest_path):
    try:
        with open(manifest_path, "r", encoding="utf-8") as f:
            ASSET_MANIFEST = json.load(f)
    except Exception:
        ASSET_MANIFEST = {}


@app.context_processor
def inject_asset_url():
    def asset_url(logical_name: str) -> str:
        mapped = ASSET_MANIFEST.get(logical_name)
        if mapped:
            return f"/assets/{mapped}"
        # fallback to static path
        return f"/static/{logical_name}"

    return dict(asset_url=asset_url)


@app.route("/")
def index():
    return render_template("index.html", mcp_url=MCP_URL)


@app.route("/api/status")
def api_status():
    # attempt with simple exponential backoff if we receive 429 or transient errors
    backoff = 0.2
    for _attempt in range(6):
        try:
            r = session.get(MCP_URL + "/status", timeout=4)
            if r.status_code == 200:
                data = r.json()
                if "controllers" not in data:
                    try:
                        c = session.get(MCP_URL + "/controllers", timeout=2).json()
                        data["controllers"] = c.get("controllers", [])
                    except Exception:
                        data["controllers"] = []
                return jsonify(data)
            elif r.status_code == 429:
                # backoff and retry
                time.sleep(backoff)
                backoff = min(backoff * 2, 2.0)
                continue
            else:
                return jsonify(
                    {
                        "ok": False,
                        "error": f"server_status_{r.status_code}",
                        "agents": [],
                        "tasks": [],
                    }
                )
        except Exception:
            time.sleep(backoff)
            backoff = min(backoff * 2, 2.0)
    return jsonify({"ok": False, "error": "unavailable", "agents": [], "tasks": []})


@app.route("/health")
def api_health():
    try:
        r = session.get(MCP_URL + "/health", timeout=2)
        return (
            r.text,
            r.status_code,
            {"Content-Type": r.headers.get("Content-Type", "application/json")},
        )
    except Exception as e:
        return ({"ok": False, "error": str(e)}, 503)


@app.route("/controllers")
def controllers_page():
    try:
        r = requests.get(MCP_URL + "/controllers", timeout=3)
        data = r.json()
        return render_template(
            "controllers.html", controllers=data.get("controllers", [])
        )
    except Exception:
        return render_template("controllers.html", controllers=[])


@app.route("/artifacts")
def list_artifacts():
    if not os.path.isdir(ART_DIR):
        return jsonify([])
    return jsonify(sorted(os.listdir(ART_DIR)))


@app.route("/artifacts/download/<path:name>")
def download_artifact(name):
    if not os.path.isdir(ART_DIR):
        return ("Not found", 404)
    return send_from_directory(ART_DIR, name, as_attachment=True)


@app.route("/task/<task_id>")
def task_detail(task_id):
    try:
        r = requests.get(MCP_URL + "/status", timeout=3)
        data = r.json()
        task = next((t for t in data.get("tasks", []) if t.get("id") == task_id), None)
        return render_template("task_detail.html", task=task)
    except Exception:
        return render_template("task_detail.html", task=None)


if __name__ == "__main__":
    app.run(port=int(os.environ.get("MCP_WEB_PORT", "8080")))
