Asset build and deployment

This folder contains a small asset build helper that hashes static assets to enable long-lived caching.

Usage

1. Build hashed assets and manifest:
   python3 build_assets.py

2. Start the dashboard (it will read static/asset-manifest.json and use hashed filenames):
   python3 mcp_dashboard_flask.py

3. To commit and push changes locally:
   git add static/_ templates/_ mcp_dashboard_flask.py build_assets.py README-ASSETS.md
   git commit -m "Add asset build step and hashed static assets; manifest support"
   git push

Notes

- The Flask app exposes an `asset_url` template helper. Use `{{ asset_url('mcp_dashboard.css') }}` in templates to resolve the current hashed filename or fallback to the static path.
- If you modify CSS/JS/SVG/manifest, re-run `python3 build_assets.py` to regenerate hashed files and the manifest.
