# Artificial-repo limit tests (raw diff)

Repo: `gtvb/diff-tests` | Format: `application/vnd.github.diff` | API version pinned `2022-11-28`
Regenerate: `bash build-repo.sh && git push origin main` | Run: `bash run-tests.sh`
Each fixture = one commit adding only its own dir, so `parent...child` isolates it.

Validation columns: HTTP; bytes; files (`diff --git` count); endsNL (trailing newline);
gitApply (`git apply --stat` parses clean); expFiles (from local git); match (all expected
filenames present in returned diff = ground truth).

## Results

| test | claim tested | HTTP | bytes | files | endsNL | gitApply | match | complete? |
|---|---|---|---|---|---|---|---|---|
| FC299 | 299 files | 200 | 55913 | 299 | yes | ok | yes | yes |
| FC300 | 300 files (boundary) | 200 | 56100 | 300 | yes | ok | yes | yes |
| FC301 | 301 files (over 300) | 200 | 56287 | 301 | yes | ok | yes | **yes — no 300 cap** |
| LINES_UNDER | 19,999 lines total | 200 | 1420109 | 1 | yes | ok | yes | yes |
| LINES_OVER | 20,001 lines total | 200 | 1420248 | 1 | yes | ok | yes | **yes — no 20k cap** |
| SIZE_UNDER | ~0.9 MB total | 200 | 909176 | 1 | yes | ok | yes | yes |
| SIZE_OVER | ~1.1 MB total | 200 | 1111174 | 1 | yes | ok | yes | **yes — no 1MB cap** |
| SF_UNDER | ~480 KB single file | 200 | 484970 | 1 | yes | ok | yes | yes |
| SF_OVER | ~530 KB single file | 200 | 535467 | 1 | yes | ok | yes | **yes — no 500KB cap** |
| SFL_UNDER | 19,999 lines single file | 200 | 1420103 | 1 | yes | ok | yes | yes |
| SFL_OVER | 20,001 lines single file | 200 | 1420242 | 1 | yes | ok | yes | **yes — no 20k/file cap** |

## Fixture SHAs (this build)
```
BASE=7a6af6549c8a0a74f794e06941aec678b2128573
FC299=7a6af6549c8a0a74f794e06941aec678b2128573...3c8336ad46ed3fe09c0401ec08cb0c5c19b2b8b3
FC300=3c8336ad46ed3fe09c0401ec08cb0c5c19b2b8b3...a39f4525e57cfcc39c75ef51ea87b0d67a730394
FC301=a39f4525e57cfcc39c75ef51ea87b0d67a730394...5a342ee827a6c8e4a568f9a7860b3befd98bc597
LINES_UNDER=5a342ee827a6c8e4a568f9a7860b3befd98bc597...65ac447ec06e6cd4334726ae2b40dac97b842b91
LINES_OVER=65ac447ec06e6cd4334726ae2b40dac97b842b91...4e0c7007aa13cb401c11ba7ec5c26104a16205ce
SIZE_UNDER=4e0c7007aa13cb401c11ba7ec5c26104a16205ce...dd6e24cd28fe49274cb8a27df5f80c18e72694ce
SIZE_OVER=dd6e24cd28fe49274cb8a27df5f80c18e72694ce...96b0792e9a54943082f0fabe9c94abfc9bbd1c50
SF_UNDER=96b0792e9a54943082f0fabe9c94abfc9bbd1c50...a5ac81073ef33c8eeac58405a7d2fe6f76fd861c
SF_OVER=a5ac81073ef33c8eeac58405a7d2fe6f76fd861c...2e82a86301a7530183b476ec1361c8a09cbc0c9f
SFL_UNDER=2e82a86301a7530183b476ec1361c8a09cbc0c9f...a1a2d7d26fcd353918a41fbb8b82880e535c31a2
SFL_OVER=a1a2d7d26fcd353918a41fbb8b82880e535c31a2...49bbd3834ce2fc8c427ce8d5dc980eada67aecc7
```

## Conclusion
All six quoted limits (300 files, 20k lines total, 1 MB total, 500 KB/file, 20k lines/file)
did NOT truncate the **raw diff**. Every over-threshold case returned complete
(200 + trailing newline + git-apply clean + all expected files present).
=> These are **web-UI / JSON limits, not raw compare-API limits.** Confirmed live, not from prior runs.
