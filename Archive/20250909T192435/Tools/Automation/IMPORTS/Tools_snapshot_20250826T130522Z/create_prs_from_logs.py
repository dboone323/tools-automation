"""Create draft PRs from *_snapshot.log files with batching and delay to avoid terminal overload.

Usage:
  GITHUB_PAT=... python3 create_prs_from_logs.py --outdir /path/to/outdir --batch 1 --sleep 3

This script:
 - scans for *_snapshot.log in OUTDIR
 - extracts repo owner/name and snapshot branch
 - creates a draft PR via GitHub API
 - requests reviewers ['github-copilot','dboone323']
 - appends PR URL to the log file
 - processes files in batches with a delay between PR creations
"""

import argparse
import glob
import json
import os
import re
import time
import urllib.error
import urllib.request


def find_logs(outdir):
    return sorted(glob.glob(os.path.join(outdir, "*_snapshot.log")))


def extract_repo_and_branch(text):
    m = re.search(r"https://github.com/([^/\s]+/[^/\s]+)(?:\.git)?", text)
    if not m:
        m = re.search(r"git@github.com:([^/\s]+/[^/\s]+)\.git", text)
    if not m:
        return None, None
    repo = m.group(1)
    b = re.search(r"(snapshot/[0-9T:\-]+)", text)
    if not b:
        b = re.search(r"(snapshot/[0-9A-Za-z_\-:]+)", text)
    branch = b.group(1) if b else None
    return repo, branch


def create_pr(repo, branch, pat):
    headers = {
        "Authorization": "token " + pat,
        "Accept": "application/vnd.github+json",
        "User-Agent": "automation-script",
    }
    payload = {
        "title": f'[snapshot] commit all local changes before automation run ({branch.split("/")[-1]})',
        "head": branch,
        "base": "main",
        "body": "Automated deterministic snapshot commit. Please review and resolve conflicts.",
        "draft": True,
    }
    url = f"https://api.github.com/repos/{repo}/pulls"
    req = urllib.request.Request(
        url, data=json.dumps(payload).encode("utf-8"), headers=headers, method="POST"
    )
    with urllib.request.urlopen(req, timeout=60) as resp:
        jr = json.loads(resp.read().decode("utf-8"))
    return jr


def request_reviewers(repo, pr_number, pat, reviewers):
    headers = {
        "Authorization": "token " + pat,
        "Accept": "application/vnd.github+json",
        "User-Agent": "automation-script",
    }
    url = f"https://api.github.com/repos/{repo}/pulls/{pr_number}/requested_reviewers"
    payload = {"reviewers": reviewers}
    req = urllib.request.Request(
        url, data=json.dumps(payload).encode("utf-8"), headers=headers, method="POST"
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        return json.loads(resp.read().decode("utf-8"))


def append_log(path, line):
    with open(path, "a", encoding="utf-8") as f:
        f.write("\n" + line + "\n")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--outdir", required=True)
    p.add_argument("--batch", type=int, default=1)
    p.add_argument("--sleep", type=int, default=2)
    p.add_argument("--reviewers", nargs="+", default=["github-copilot", "dboone323"])
    args = p.parse_args()
    pat = os.environ.get("GITHUB_PAT")
    if not pat:
        print("GITHUB_PAT environment variable is required")
        return 1
    logs = find_logs(args.outdir)
    if not logs:
        print("No *_snapshot.log files found in", args.outdir)
        return 0
    to_process = []
    for path in logs:
        try:
            text = open(path, "r", encoding="utf-8", errors="ignore").read()
        except Exception as e:
            print("READ ERROR", path, e)
            continue
        repo, branch = extract_repo_and_branch(text)
        if not repo or not branch:
            print("SKIP", os.path.basename(path), "missing repo or branch")
            continue
        to_process.append((path, repo, branch))
    print(
        "Will create PRs for",
        len(to_process),
        "logs (batch=",
        args.batch,
        "sleep=",
        args.sleep,
        ")",
    )
    idx = 0
    for path, repo, branch in to_process:
        idx += 1
        print(
            f"[{idx}/{len(to_process)}] Processing {os.path.basename(path)} -> {repo} [{branch}]"
        )
        try:
            jr = create_pr(repo, branch, pat)
        except urllib.error.HTTPError as e:
            err = e.read().decode("utf-8")
            print("ERROR_CREATING_PR", repo, "HTTP", e.code, err[:300])
            append_log(path, f"PR_CREATE_ERROR_HTTP_{e.code}: {err[:200]}")
            continue
        except Exception as e:
            print("ERROR_CREATING_PR", repo, e)
            append_log(path, f"PR_CREATE_ERROR: {e}")
            continue
        pr_url = jr.get("html_url")
        pr_number = jr.get("number")
        if pr_url:
            append_log(path, "PR_CREATED: " + pr_url)
            print("CREATED", pr_url)
        if pr_number:
            try:
                request_reviewers(repo, pr_number, pat, args.reviewers)
            except urllib.error.HTTPError as e:
                err = e.read().decode("utf-8")
                print("WARN_REQUEST_REVIEWERS", repo, "HTTP", e.code, err[:200])
                append_log(path, f"WARN_REQUEST_REVIEWERS_HTTP_{e.code}: {err[:200]}")
            except Exception as e:
                print("WARN_REQUEST_REVIEWERS", repo, e)
                append_log(path, "WARN_REQUEST_REVIEWERS: " + str(e))
        # delay to avoid overwhelming API/terminal
        if idx % args.batch == 0:
            print("Sleeping", args.sleep, "seconds before next batch...")
            time.sleep(args.sleep)
    print("Done")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
