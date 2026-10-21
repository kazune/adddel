#!/bin/bash
set -euo pipefail

fail() {
    printf 'make dist: %s\n' "$1" >&2
    exit 1
}

command -v git >/dev/null 2>&1 || fail 'git is not available'
command -v "${PANDOC:-pandoc}" >/dev/null 2>&1 || fail 'pandoc is not available'
head_commit=$(git rev-parse --verify HEAD) || fail 'cannot read HEAD'
tags=$(git tag --merged HEAD --list) || fail 'cannot list reachable tags'
matches=()
while IFS= read -r tag; do
    if [[ $tag =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        matches+=(--match "$tag")
    fi
done <<<"$tags"
[ "${#matches[@]}" -gt 0 ] || fail 'no reachable vMAJOR.MINOR.PATCH tag'
tag=$(git describe --tags --abbrev=0 "${matches[@]}" HEAD) || fail 'cannot select version tag'
tag_commit=$(git rev-parse "$tag^{commit}") || fail 'cannot resolve version tag'
commit_id=$(git rev-parse --short=7 HEAD) || fail 'cannot read commit ID'
build_date=$(TZ=UTC0 git log -1 --date=format-local:%Y-%m-%d --format=%cd HEAD) || fail 'cannot read commit date'

dirty=0
if git diff --quiet HEAD --; then
    :
else
    status=$?
    [ "$status" -eq 1 ] || fail 'cannot inspect working tree'
    dirty=1
fi
version=${tag#v}
if [ "$head_commit" != "$tag_commit" ] || [ "$dirty" -eq 1 ]; then
    version="$version-g$commit_id"
fi
if [ "$dirty" -eq 1 ]; then
    version="$version-dirty"
fi

# Generate both files before replacing any previous distribution.
mkdir -p dist/bin dist/share/man/man1
work_dir=$(mktemp -d dist/.build.XXXXXXXX) || fail 'cannot create temporary directory'
trap 'rm -rf -- "$work_dir"' EXIT
trap 'exit 1' HUP INT TERM
sed -e "s/@VERSION@/$version/g" -e "s/@DATE@/$build_date/g" \
    src/adddel >"$work_dir/adddel"
"${PANDOC:-pandoc}" --from=markdown --to=man --standalone \
    --metadata "title=ADDDEL" --metadata "section=1" \
    --metadata "header=User Commands" --variable "footer=adddel $version" \
    --variable "date=$build_date" src/adddel.1.md -o "$work_dir/adddel.1"
chmod 755 "$work_dir/adddel"
mv -f "$work_dir/adddel" dist/bin/adddel
mv -f "$work_dir/adddel.1" dist/share/man/man1/adddel.1
printf 'Built adddel %s (%s)\n' "$version" "$build_date"
