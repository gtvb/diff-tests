# GitHub Compare API — raw `.diff` reliability study

> Starting-point context for an AI/engineer picking this up. Read this first.

## 1. Why this repo exists (the goal)

We are building a **secret scanner**. It scans the **added lines (`+`)** in the
diff between two points A -> B of a repo. Two data streams:

1. **Incremental (steady state):** we receive `before` + `head` commit SHAs on a
   push and scan `before...head`. Normal pushes = a handful of commits.
2. **First-seen repo (backfill):** first time we see a repo we scan
   `initial_commit...HEAD` (potentially the whole history).

We fetch the diff from GitHub's Compare API in **raw unified-diff format**:

```
GET /repos/{owner}/{repo}/compare/{base}...{head}
Accept: application/vnd.github.diff
X-GitHub-Api-Version: 2022-11-28
```

**The one question this repo answers:** *given a VALID A->B range, does the raw
compare API reliably return the COMPLETE diff, and where does it truncate?*
We want a **safe operating envelope** — a boundary below which the diff is
trustworthy for scanning.

**Out of scope:** whether the A/B SHAs are valid/correct (that's a separate
pipeline problem). We only study completeness of the returned diff for a valid range.

## 2. What we found (short version)

- The six limits people quote (300 files, 20k lines total, 1 MB total, 500 KB/file,
  20k lines/file) are **web-UI / JSON limits, NOT raw-diff limits.** Every
  over-threshold artificial fixture returned complete. See `results-artificial-limits.md`.
- **Output size / file count did NOT cause truncation** in what we tested: a single
  1-commit diff of **106 MB / 25,000 files** came back complete and byte-identical 5x.
- **The thing that broke it was commit-span.** Ranges at/over GitHub's documented
  **10,000-commit compare window** truncated **silently and non-deterministically**
  (HTTP 200, but different partial content each fetch), even for small (~1.4 MB) output.
- A pinned **7,381-commit / 65 MB / 7,062-file** real range fetched 3x = all complete
  (only a cosmetic index-hash abbreviation jitter, no missing content).
  See `results-reach-envelope.md`.

## 3. Honesty: fact vs finding vs inference

- **Documented fact:** Compare is commit-range based and capped at **10,000 commits**;
  GitHub says large `.diff`/`.patch` "may time out" and publishes **no** completeness threshold.
- **Our empirical finding (NOT documented by GitHub):** at the 10k-commit cap the raw
  diff body clips **silently** (200 + missing content, non-deterministic).
- **Inference (well-supported, not guaranteed):** it clips because the diff is derived
  from the capped commit walk, not from a pure two-tree compare.

There is **no contractual guarantee** that "under 10k commits => complete diff."
What we have is reproducible measurement of where the *silent* break happens.

## 4. Two failure modes — keep them separate

| failure | how it shows | danger | seen? |
|---|---|---|---|
| timeout on huge diff | **5xx (loud)** | low — detectable, retry/split | not hit up to 106 MB |
| silent truncation | **200 + missing content** | HIGH — you scan a partial diff unknowingly | only at >=10k commits |

The dangerous one is silent truncation. Loud 5xx is safe because you can react.

## 5. Detection we recommend (200 is not enough)

1. HTTP 200 (necessary, not sufficient).
2. Trailing-newline check (catches mid-line cut).
3. `git apply --stat` parses clean.
4. Treat JSON `total_commits >= 10000` as a **hard red flag** -> split range or fall back.

## 6. Fallback for unsafe ranges

Split into sub-ranges each < 10k commits (A...M, M...B, ...) and concatenate, or go
out-of-band with **local git** (`git diff A B`) — local git has no commit-walk cap.

## 7. Known open questions / untested tail risk (good next tests)

- **Pathological single diffs** not characterized: one multi-GB file, heavy
  rename/copy detection, binary-heavy trees. Our "size doesn't matter" claim is only
  honest **up to ~106 MB / 25k files of ordinary text.**
- **Tree-diff semantics (architectural, not truncation):** `base...head` is a *net*
  tree diff. A secret added in commit B and removed in commit Y *inside* the range does
  NOT appear even in a perfect complete diff (file absent in both endpoints). Per-push
  `before...head` catches each secret in the push that introduced it; a first-seen
  `initial...HEAD` backfill would MISS secrets introduced-and-removed before we saw the
  repo. Decide if the scanner needs full-history coverage or only tree-delta coverage.
- Real-repo date-based rows were characterized without pinning every base/head SHA;
  re-run with pinned SHAs if you want every row byte-reproducible.

## 8. How to reproduce

```
bash build-repo.sh          # regenerate deterministic fixtures (fixed author+date => stable SHAs)
git push origin main        # push fixtures so the Compare API can see them
bash run-tests.sh           # fetch raw diffs for each fixture and validate
```

- Auth token lives in `token.txt` (git-ignored, NEVER commit or print it). Load with:
  `TOKEN=$(tr -d ' \t\r\n' < token.txt)`
- `fixtures.env` maps fixture name -> `parent...child` SHAs.
- Fetched diffs land in `out/` (git-ignored, ~2 GB).

## 9. Files

- `SUMMARY.md` — this file (start here).
- `results-artificial-limits.md` — the six quoted limits, all disproven for raw diff.
- `results-reach-envelope.md` — commit-span finding + safe envelope + decisive 7,381-commit test.
- `build-repo.sh` — deterministic fixture generator.
- `run-tests.sh` — fetch + validate raw diffs.
- `fixtures.env` — fixture name -> SHA range map.
- `fixtures/` — committed fixture content (needed for stable SHAs).
- `out/` — fetched diff artifacts (git-ignored, regenerable).
