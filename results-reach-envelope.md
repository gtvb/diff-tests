# Raw diff reach & completeness — the safe envelope

Format: `application/vnd.github.diff`, API version pinned `2022-11-28`, token auth.
Question tested: given a valid A->B range, does the raw compare API return the
COMPLETE diff, and when does it truncate?

Completeness = HTTP 200 + trailing newline + `git apply --stat` clean
+ (artificial only) all expected filenames present. Determinism = same range
fetched N times returns identical, complete bytes.

## Key finding: truncation is driven by COMMIT-SPAN, not output size

| case | repo | commits in range | output | fetches | result |
|---|---|---|---|---|---|
| single huge commit | artificial | 1 | 25,000 files / 106 MB | 5 | COMPLETE, byte-identical all 5 (deterministic) |
| under 10k commits | linux | 5,508 | 6,107 files / 13.4 MB | 1 | complete |
| under 10k commits | linux | 2,530 | 3,607 files / 4.4 MB | 1 | complete |
| under 10k commits | vscode | 3,442 | 4,495 files / 37 MB | 1 | complete |
| >= 10k commits | linux | 10,000 (capped) | varied | 5 | TRUNCATED, non-deterministic: 2.6/67/69/75/59 MB |
| >= 10k commits | vscode | 10,000 (capped) | ~199 MB | 3 | NON-DETERMINISTIC: 2 looked complete, 1 truncated |

- A **single commit of 106 MB / 25,000 files** returns complete and identical every
  time. So neither raw size nor file count causes truncation.
- Ranges whose commit span reaches **GitHub's 10,000-commit compare window** truncate
  **non-deterministically** (same request -> different partial sizes each call),
  regardless of output size (even a 1.4 MB result truncated) and regardless of repo.
- vscode's large ranges *appeared* complete on single fetches but the 3x repeat
  exposed one truncated fetch -> they are non-deterministic too, just closer to full.

## Decisive isolation test: large output UNDER the 10k-commit cap

To separate "commit span" from "output size" cleanly, we pinned a real vscode
range that is BIG in output but well UNDER the commit cap, and fetched it 3x.

- head = `c5447dfca411576afb129053f80cbc1b7322692e`
- base = `47a66928de78dbef372305f26bd2de69220b01c7`
- JSON `total_commits` = **7,381** (sub-10k), output ~65 MB / 7,062 files

| fetch | bytes | files | trailing NL | git apply --stat |
|---|---|---|---|---|
| 1 | 65,195,972 | 7,062 | yes | clean |
| 2 | 65,181,878 | 7,062 | yes | clean |
| 3 | 65,195,972 | 7,062 | yes | clean |

Result: **all 3 complete**. Identical file sets (same 7,062 files every time),
trailing newline present, git-apply clean. So a 65 MB output under the cap is
complete and content-deterministic.

The only byte difference (fetch 2, ~14 KB smaller, different md5) is **cosmetic**:
the abbreviated blob SHAs on `index <old>..<new>` lines are rendered a character
or two shorter in that response (e.g. `index 2b564d812bb397..0992f5e3e90759` vs
`index 2b564d812bb39..0992f5e3e9075`). No hunk, `+`/`-` line, or file is missing.
For an additions scanner this is irrelevant (index lines are not scanned content).

Conclusion: this confirms **commit-span is the truncation trigger, not size**. A
65 MB / 7,062-file diff at 7,381 commits stays complete across repeats; only the
>= 10k-commit ranges truncate. The index-abbreviation jitter is the only
non-determinism seen below the cap, and it changes zero scanned content.

## Safe envelope (for the secret scanner)

- SAFE: any range with **< ~10,000 commits** returns a complete raw diff, at any
  size we tested (up to ~106 MB / 25k files complete). Output size and file count
  are NOT the limiting factor.
- UNSAFE: ranges at/over the **10,000-commit** compare window -> silently truncated
  and non-deterministic. HTTP 200 lies; content-length matches the partial body.

## Detection (must-have, since 200 is not trustworthy)
1. HTTP 200 (necessary, not sufficient).
2. trailing newline (catches mid-line cut; caught cases git-apply missed).
3. `git apply --stat` clean.
4. cross-check: JSON `total_commits` == 10,000 is a red flag the range hit the cap.
   Best practice: if `total_commits >= 10000`, split the range and never trust the
   single diff.

## Fallback for unsafe ranges
Split the range into sub-ranges each under the 10k-commit window
(A...M, M...B, ...) and concatenate; or go out-of-band (local git). Public REST
limits are not user-configurable.

## Reproducibility caveats (honesty)
- Artificial fixtures (incl. the 106 MB huge case): fully reproducible via
  build-repo.sh + fixtures.env SHAs; verified from saved out/*.diff.
- Real-repo runs (linux/vscode): base SHAs were resolved by date at run time and
  the exact base/head SHAs + HTTP codes were NOT persisted. The determinism
  conclusion is solid (repeats saved: huge_*, linux1yr_*, vscR_*), but the
  individual date-based rows are characterization, not byte-reproducible. To make
  them reproducible, re-run with pinned SHAs recorded (next step).
