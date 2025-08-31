# PR create template

Use the provided PAT with repo scope. Example:

```bash
curl -X POST \
  -H "Authorization: token <TOKEN>" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/<owner>/<repo>/pulls \
  -d '{"title":"<TITLE>","head":"<HEAD>","base":"main","body":"<BODY>","draft":true}'
```

Then request reviewers in order:

```bash
curl -X POST \
  -H "Authorization: token <TOKEN>" \
  -H "Accept: application/vnd.github+json" \
  https://api.github.com/repos/<owner>/<repo>/pulls/<PR_NUMBER>/requested_reviewers \
  -d '{"reviewers":["github-copilot","dboone323"]}'
```

Notes:

- Create PRs in small batches (1-3) with a 3s delay between batches to avoid rate limits and terminal instability.
