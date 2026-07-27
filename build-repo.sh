#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
export GIT_AUTHOR_NAME="Diff Tester" GIT_AUTHOR_EMAIL="test@example.com"
export GIT_COMMITTER_NAME="Diff Tester" GIT_COMMITTER_EMAIL="test@example.com"
D="2020-01-01T00:00:00"
commit() { export GIT_AUTHOR_DATE="$D" GIT_COMMITTER_DATE="$D"; git add fixtures && git commit -q -m "$1"; }
line() { printf 'filler line %06d aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\n' "$1"; }
rm -rf fixtures && mkdir fixtures
: > fixtures.env
mkdir -p fixtures/base && echo base > fixtures/base/marker.txt
commit "fixture-base"
echo "BASE=$(git rev-parse HEAD)" >> fixtures.env
mkfiles() { mkdir -p "$1"; for i in $(seq 1 "$2"); do printf 'f%04d\n' "$i" > "$1/file_$(printf '%04d' "$i").txt"; done; }
record() { echo "$1=$(git rev-parse HEAD~1)...$(git rev-parse HEAD)" >> fixtures.env; }
mkfiles fixtures/fc299 299; commit "fc: 299 files"; record FC299
mkfiles fixtures/fc300 300; commit "fc: 300 files"; record FC300
mkfiles fixtures/fc301 301; commit "fc: 301 files"; record FC301
mkdir -p fixtures/lines_under; for i in $(seq 1 19999); do line "$i"; done > fixtures/lines_under/f.txt
commit "lines: 19999 total"; record LINES_UNDER
mkdir -p fixtures/lines_over; for i in $(seq 1 20001); do line "$i"; done > fixtures/lines_over/f.txt
commit "lines: 20001 total"; record LINES_OVER
python3 -c "import os;os.makedirs('fixtures/size_under',exist_ok=True);r=('x'*99)+chr(10);open('fixtures/size_under/f.txt','w').write(r*9000)"
commit "size: ~0.9MB total"; record SIZE_UNDER
python3 -c "import os;os.makedirs('fixtures/size_over',exist_ok=True);r=('x'*99)+chr(10);open('fixtures/size_over/f.txt','w').write(r*11000)"
commit "size: ~1.1MB total"; record SIZE_OVER
python3 -c "import os;os.makedirs('fixtures/sf_under',exist_ok=True);r=('y'*99)+chr(10);open('fixtures/sf_under/f.txt','w').write(r*4800)"
commit "single-file: ~480KB (under 500KB)"; record SF_UNDER
python3 -c "import os;os.makedirs('fixtures/sf_over',exist_ok=True);r=('y'*99)+chr(10);open('fixtures/sf_over/f.txt','w').write(r*5300)"
commit "single-file: ~530KB (over 512KB)"; record SF_OVER
mkdir -p fixtures/sfl_under; for i in $(seq 1 19999); do line "$i"; done > fixtures/sfl_under/f.txt
commit "single-file: 19999 lines"; record SFL_UNDER
mkdir -p fixtures/sfl_over; for i in $(seq 1 20001); do line "$i"; done > fixtures/sfl_over/f.txt
commit "single-file: 20001 lines"; record SFL_OVER
echo "=== fixtures.env ==="; cat fixtures.env
