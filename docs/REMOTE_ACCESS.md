# Remote Access / View Remotes

This script helps you quickly add a read-only `view` remote pointing at the GitHub projects under the `dboone323` account (or a different account you specify). It is idempotent and will skip directories that are not a git repository.

The script looks for repositories as subdirectories within the current tools-automation repository root. If a repo is missing, you can use `--clone-if-missing` to clone it there.

Usage:

1. Dry run to see what would be changed (looks for repos in the current repo's parent directory by default):

```bash
bash scripts/add_github_view_remotes.sh --dry-run
```

3. Add remotes in-place (this will add a `view` remote for each repo found):

```bash
bash scripts/add_github_view_remotes.sh
```

4. Clone missing repos and add remotes:

```bash
bash scripts/add_github_view_remotes.sh --clone-if-missing
```

5. Add remotes then open the repo pages in a browser:

```bash
bash scripts/add_github_view_remotes.sh --open
```

- The script assumes the repository folders are in the same workspace root as this project. If your project layout differs, either change the `REPOS` list in the script or run it from your parent directory that contains those projects.
- The remote is named `view` by default — to remove it later: `git remote remove view`.
- For SSH remotes or other naming conventions, modify the `remote_url` variable inside the script.

Notes:
- The script checks for directories within the tools-automation repo and then its parent directory (so sibling folders under `desktop/github-projects` are detected). You can customize the repo list or base folder to match your setup.
- The remote is named `view` by default — to remove it later: `git remote remove view`.
- For SSH remotes or other naming conventions, modify the `remote_url` variable inside the script.
- The script assumes the repository folders are in the same workspace root as this project. If your project layout differs, either change the `REPOS` list in the script or run it from your parent directory that contains those projects.
- The remote is named `view` by default — to remove it later: `git remote remove view`.
- For SSH remotes or other naming conventions, modify the `remote_url` variable inside the script.

If you want a bulk way to open a GitHub project root in a browser, run it with `--open`.

-- end of doc
