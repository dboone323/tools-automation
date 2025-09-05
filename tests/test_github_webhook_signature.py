import hashlib
import hmac
import json

import mcp_server


def make_sig(secret: str, payload: bytes, algo: str = "sha256") -> str:
    if algo == "sha256":
        mac = hmac.new(secret.encode("utf-8"), msg=payload, digestmod=hashlib.sha256)
        return "sha256=" + mac.hexdigest()
    elif algo == "sha1":
        mac = hmac.new(secret.encode("utf-8"), msg=payload, digestmod=hashlib.sha1)
        return "sha1=" + mac.hexdigest()
    else:
        raise ValueError("unsupported")


def test_verify_sha256_valid():
    secret = "secret123"
    payload = json.dumps({"hello": "world"}).encode("utf-8")
    sig = make_sig(secret, payload, "sha256")
    assert mcp_server.verify_github_signature(secret, payload, sig)


def test_verify_sha1_valid():
    secret = "secret123"
    payload = json.dumps({"a": 1}).encode("utf-8")
    sig = make_sig(secret, payload, "sha1")
    assert mcp_server.verify_github_signature(secret, payload, sig)


def test_verify_invalid_signature():
    secret = "secret123"
    payload = b"{}"
    bad_sig = "sha256=deadbeef"
    assert not mcp_server.verify_github_signature(secret, payload, bad_sig)
