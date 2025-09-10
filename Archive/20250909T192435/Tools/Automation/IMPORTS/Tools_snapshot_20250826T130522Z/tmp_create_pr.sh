#!/usr/bin/env bash
set -euo pipefail

GH_OWNER=dboone323
GH_REPO=Quantum-workspace
BRANCH="import/MomentumFinance/snapshot-20250826T130522Z"
BASE=main
TITLE="Import: MomentumFinance snapshot (20250826T130522Z)"
BODY="Import-only snapshot of MomentumFinance under Tools/Projects/MomentumFinance. See Automation/IMPORTS/MomentumFinance.import.md."

TOKEN="${GITHUB_TOKEN-}"
if [[ -z ${TOKEN} ]] && [[ -f "${HOME}/.gh_token" ]]; then
	TOKEN=$(cat "${HOME}/.gh_token")
fi
if [[ -z ${TOKEN} ]]; then
	echo "ERROR: No GITHUB_TOKEN env var and no ~/.gh_token file. Aborting." >&2
	exit 2
fi

create_resp_file=$(mktemp)
http_code=$(curl -s -o "${create_resp_file}" -w "%{http_code}" -X POST \
	-H "Authorization: token ${TOKEN}" \
	-H "Accept: application/vnd.github+json" \
	"https://api.github.com/repos/${GH_OWNER}/${GH_REPO}/pulls" \
	-d "{\"title\": \"${TITLE}\", \"head\": \"${BRANCH}\", \"base\": \"${BASE}\", \"body\": \"${BODY}\", \"draft\": true}")

echo "Create PR HTTP: ${http_code}"
cat "${create_resp_file}" | sed -n '1,200p'

if [[ ${http_code} -ne 201 ]]; then
	echo "PR create failed with HTTP ${http_code}" >&2
	exit 1
fi

pr_number=$(
	python3 - <<PY
import json
print(json.load(open('${create_resp_file}'))['number'])
PY
)
pr_url=$(
	python3 - <<PY
import json
print(json.load(open('${create_resp_file}'))['html_url'])
PY
)

echo "PR #${pr_number} -> ${pr_url}"

req_resp_file=$(mktemp)
req_code=$(curl -s -o "${req_resp_file}" -w "%{http_code}" -X POST \
	-H "Authorization: token ${TOKEN}" \
	-H "Accept: application/vnd.github+json" \
	"https://api.github.com/repos/${GH_OWNER}/${GH_REPO}/pulls/${pr_number}/requested_reviewers" \
	-d '{"reviewers":["github-copilot","dboone323"]}')

echo "Request reviewers HTTP: ${req_code}"
cat "${req_resp_file}" | sed -n '1,200p'

if [[ ${req_code} -ne 201 ]] && [[ ${req_code} -ne 200 ]]; then
	echo "Reviewer request failed with HTTP ${req_code}" >&2
	exit 1
fi

echo "${pr_url}"

exit 0
