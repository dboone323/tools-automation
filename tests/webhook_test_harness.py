#!/usr/bin/env python3
"""Simple harness to POST a signed webhook to the local MCP server.

Usage:
  export GITHUB_WEBHOOK_SECRET=secret123
  python Automation/tests/webhook_test_harness.py --event repository_dispatch --payload '{"client_payload": {"command": "ci-check", "head_branch": "main", "execute": true}}'
"""
import os
import sys
import json
import hmac
import hashlib
import requests
import argparse

def make_sig(secret, payload_bytes, algo='sha256'):
    if algo == 'sha256':
        mac = hmac.new(secret.encode('utf-8'), msg=payload_bytes, digestmod=hashlib.sha256)
        return 'sha256=' + mac.hexdigest()
    raise SystemExit('unsupported algo')

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--event', default='repository_dispatch')
    p.add_argument('--payload', required=True)
    p.add_argument('--url', default='http://127.0.0.1:5005/github_webhook')
    args = p.parse_args()
    secret = os.getenv('GITHUB_WEBHOOK_SECRET')
    if not secret:
        print('Set GITHUB_WEBHOOK_SECRET in env')
        sys.exit(2)
    try:
        payload_obj = json.loads(args.payload)
    except Exception:
        print('payload must be JSON')
        sys.exit(2)
    payload_bytes = json.dumps(payload_obj).encode('utf-8')
    sig = make_sig(secret, payload_bytes)
    headers = {'X-GitHub-Event': args.event, 'X-Hub-Signature-256': sig, 'Content-Type': 'application/json'}
    r = requests.post(args.url, data=payload_bytes, headers=headers)
    print(r.status_code, r.text)

if __name__ == '__main__':
    main()
