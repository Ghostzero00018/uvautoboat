# Wiki Sync Workflow

Source of truth: the `wiki/` folder in this repo.
Published copy: `github.com/Ghostzero00018/uvautoboat/wiki`.

The two are kept in sync **automatically** via a GitHub Action that runs whenever `wiki/**` changes on `main`. The helper script and manual steps below exist as fallbacks for when the Action is unavailable or for disaster recovery.

---

## Automatic (normal path)

1. Edit any file under `wiki/*.md`.
2. Commit and push the main repo.
3. The workflow at `.github/workflows/sync-wiki.yml` fires on the push (only when `wiki/**` changed), copies every `wiki/*.md` into the wiki repo, and commits as `github-actions[bot]`.
4. Verify at `github.com/Ghostzero00018/uvautoboat/wiki` within ~30 s.

The workflow skips `UPLOAD_INSTRUCTIONS.md` — this meta file stays in the main repo and does not become a wiki page.

---

## Manual sync (fallback)

Run the helper script from the main repo root:

```bash
scripts/sync_wiki.sh "Commit message describing what changed"
```

What it does:

- Clones `git@github.com:Ghostzero00018/uvautoboat.wiki.git` to `../uvautoboat.wiki/` (sibling to the main repo) on first run.
- Pulls latest with rebase.
- Copies every `wiki/*.md` into the clone, strips `UPLOAD_INSTRUCTIONS.md`.
- Bails cleanly if nothing changed; otherwise commits and pushes.

Prerequisite: SSH access to `git@github.com`. If port 22 is blocked on your network, the SSH-over-443 config in `~/.ssh/config` handles it transparently.

---

## Manual step-by-step (for disaster recovery)

If both the Action and the script are unusable, do it by hand:

```bash
# 1. Clone (first time only)
git clone git@github.com:Ghostzero00018/uvautoboat.wiki.git ~/seal_ws/uvautoboat.wiki

# 2. Sync
cd ~/seal_ws/uvautoboat.wiki
git pull --rebase origin master
cp ~/seal_ws/src/uvautoboat/wiki/*.md .
rm -f UPLOAD_INSTRUCTIONS.md

# 3. Commit and push
git add -A
git commit -m "Sync wiki"
git push origin master
```

---

## GitHub Wiki conventions (cheat sheet)

- **Branch**: the wiki repo uses `master`, not `main`.
- **Page title from filename**: `System_Overview.md` becomes the page titled `System Overview` (underscores render as spaces).
- **Home** is the landing page (must exist at the root).
- **Inter-page links** use `[Title](Page_Name)` — no `.md` suffix, underscores in the target.
- **Sidebars/footers**: create `_Sidebar.md` or `_Footer.md` at the root. These are not currently used by this project.
- **Deletions are manual**: if a page is removed from `wiki/`, the sync scripts do not delete it from the published wiki. Delete it directly in the wiki clone (or via the GitHub UI) and push.

---

## Troubleshooting

| Symptom | Likely cause | Fix |
|:--|:--|:--|
| Workflow didn't run | Push didn't touch `wiki/**` | Expected — only changes under `wiki/` trigger the sync |
| Workflow failed with permission error | `contents: write` permission missing or default token scope tightened | Check `permissions:` block in the workflow file; re-grant in repo Settings → Actions → Workflow permissions |
| Script push rejected (non-fast-forward) | Wiki edited via GitHub UI after last local sync | Script does `git pull --rebase` first; if rebase conflicts, resolve by hand in `~/seal_ws/uvautoboat.wiki/` |
| Wiki tab invisible on repo page | Wikis disabled in repo Settings | Repo Settings → Features → tick Wikis |
| Page renders as "Not Found" | Link target uses `.md` suffix or spaces | GitHub Wiki URLs drop `.md` and replace spaces with dashes or underscores depending on the page title |
