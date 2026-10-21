#!/usr/bin/env bats

setup() {
    root="$BATS_TEST_DIRNAME/.."
    real_make=$(command -v make)
    export GIT_CONFIG_NOSYSTEM=1
    export GIT_CONFIG_GLOBAL=/dev/null
    unset GIT_CONFIG_COUNT GIT_DIR GIT_WORK_TREE
    export GIT_AUTHOR_DATE='2026-10-21T00:30:00+0900'
    export GIT_COMMITTER_DATE="$GIT_AUTHOR_DATE"
    cd "$BATS_TEST_TMPDIR" || return
    cp "$root/Makefile" "$root/.gitignore" .
    cp -R "$root/src" "$root/scripts" .
    git init -q --template=
    git config user.name 'adddel tests'
    git config user.email 'adddel-tests@example.invalid'
    git config commit.gpgsign false
    git config core.hooksPath /dev/null
    git add .
    git commit -qm 'initial source'
    commit_id=$(git rev-parse --short=7 HEAD)
}

assert_build() {
    local expected=$1
    run make dist
    [ "$status" -eq 0 ]
    [ -x dist/bin/adddel ]
    [ -s dist/share/man/man1/adddel.1 ]
    run dist/bin/adddel --version
    [ "$status" -eq 0 ]
    [ "$output" = "adddel $expected" ]
    grep -F "adddel $expected (2026-10-20)" dist/bin/adddel
    grep -F "adddel $expected" dist/share/man/man1/adddel.1
    grep -F '2026-10-20' dist/share/man/man1/adddel.1
    grep -F '\-\-version' dist/share/man/man1/adddel.1
    ! grep -F '@VERSION@' dist/bin/adddel
    ! grep -F '@DATE@' dist/bin/adddel
}

@test "builds a clean lightweight tag with UTC commit date and ignores generated files" {
    git tag v0.1.0
    assert_build '0.1.0'
    cp dist/bin/adddel previous-bin
    cp dist/share/man/man1/adddel.1 previous-man
    assert_build '0.1.0'
    cmp previous-bin dist/bin/adddel
    cmp previous-man dist/share/man/man1/adddel.1
    rm previous-bin previous-man
    [ -z "$(git status --porcelain)" ]
    printf 'one\n' >old
    printf 'one\ntwo\n' >new
    run dist/bin/adddel old new
    [ "$status" -eq 0 ]
    [ "$output" = $'1\t0' ]
}

@test "uses HEAD commit ID after an annotated tag and refreshes after a new tag" {
    local next_commit_id
    git tag -a v0.1.0 -m 'release'
    git commit --allow-empty -qm 'next commit'
    next_commit_id=$(git rev-parse --short=7 HEAD)
    assert_build "0.1.0-g$next_commit_id"
    git tag v0.2.0
    assert_build '0.2.0'
}

@test "marks staged and unstaged tracked changes dirty and recovers after restoration" {
    git tag v0.1.0
    printf '\n# changed\n' >>src/adddel
    assert_build "0.1.0-g$commit_id-dirty"
    git add src/adddel
    assert_build "0.1.0-g$commit_id-dirty"
    git reset -q HEAD -- src/adddel
    git checkout -- src/adddel
    assert_build '0.1.0'
}

@test "marks changes after a tag with both commit ID and dirty suffix" {
    local next_commit_id
    git tag v0.1.0
    git commit --allow-empty -qm 'next commit'
    next_commit_id=$(git rev-parse --short=7 HEAD)
    printf '\n' >>src/adddel.1.md
    assert_build "0.1.0-g$next_commit_id-dirty"
}

@test "ignores nonversion tags and tags outside HEAD history" {
    local next_commit_id
    git tag v0.1.0
    git commit --allow-empty -qm 'next commit'
    next_commit_id=$(git rev-parse --short=7 HEAD)
    git tag v9.0.0-rc1
    git tag unrelated
    git checkout -qb side
    git commit --allow-empty -qm 'side release'
    git tag v9.0.0
    git checkout -q -
    assert_build "0.1.0-g$next_commit_id"
}

@test "fails without a reachable version tag and creates no artifacts" {
    git tag v1.0.0-rc1
    run make dist
    [ "$status" -ne 0 ]
    [[ $output == *'no reachable vMAJOR.MINOR.PATCH tag'* ]]
    [ ! -e dist/bin/adddel ]
    [ ! -e dist/share/man/man1/adddel.1 ]
}

@test "fails if Git is unavailable and creates no artifacts" {
    mkdir emptybin
    run env PATH="$PWD/emptybin" "$real_make" dist
    [ "$status" -ne 0 ]
    [[ $output == *'git is not available'* ]]
    [ ! -e dist/bin/adddel ]
    [ ! -e dist/share/man/man1/adddel.1 ]
}

@test "fails if pandoc is missing without replacing a previous distribution" {
    git tag v0.1.0
    assert_build '0.1.0'
    cp dist/bin/adddel previous-bin
    cp dist/share/man/man1/adddel.1 previous-man
    run make dist PANDOC=nonexistent-adddel-pandoc
    [ "$status" -ne 0 ]
    [[ $output == *'pandoc is not available'* ]]
    cmp previous-bin dist/bin/adddel
    cmp previous-man dist/share/man/man1/adddel.1
}

@test "preserves a previous distribution when pandoc conversion fails" {
    git tag v0.1.0
    assert_build '0.1.0'
    cp dist/bin/adddel previous-bin
    cp dist/share/man/man1/adddel.1 previous-man
    printf '#!/bin/sh\nexit 1\n' >failed-pandoc
    chmod +x failed-pandoc
    run make dist PANDOC=./failed-pandoc
    [ "$status" -ne 0 ]
    cmp previous-bin dist/bin/adddel
    cmp previous-man dist/share/man/man1/adddel.1
    run find dist -name '.build.*'
    [ -z "$output" ]
}

@test "generated help and version work without Git or the source repository" {
    git tag v0.1.0
    assert_build '0.1.0'
    mkdir standalone emptybin
    cp dist/bin/adddel standalone/adddel
    ln -s /bin/cat emptybin/cat
    run env PATH="$PWD/emptybin" standalone/adddel --version
    [ "$status" -eq 0 ]
    [ "$output" = 'adddel 0.1.0' ]
    run env PATH="$PWD/emptybin" standalone/adddel --help
    [ "$status" -eq 0 ]
    [[ $output == Usage:* ]]
}
