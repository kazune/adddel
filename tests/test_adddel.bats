#!/usr/bin/env bats

setup() {
    original_path=$PATH
    app="$BATS_TEST_DIRNAME/../src/adddel"
    shell=${ADDDEL_TEST_BASH:-/bin/bash}
    real_git=$(command -v git)
    real_cmp=$(command -v cmp)
    cd "$BATS_TEST_TMPDIR" || return
    printf 'one\ntwo\n' >old
    printf 'one\ntwo\nthree\n' >new
    export GIT_CONFIG_NOSYSTEM=1
    export GIT_CONFIG_GLOBAL=/dev/null
    unset GIT_EXTERNAL_DIFF GIT_DIFF_OPTS GIT_CONFIG_COUNT
}

teardown() {
    export PATH="$original_path"
}

invoke() {
    "$shell" "$app" "$@" >actual.out 2>actual.err
}

success() {
    local expected=$1
    shift
    run invoke "$@"
    [ "$status" -eq 0 ]
    printf '%s\n' "$expected" >expected.out
    "$real_cmp" expected.out actual.out
    [ ! -s actual.err ]
}

failure() {
    local code=$1 reason=$2
    shift 2
    run invoke "$@"
    [ "$status" -eq "$code" ]
    [ ! -s actual.out ]
    printf 'adddel: %s\n' "$reason" >expected.err
    "$real_cmp" expected.err actual.err
}

fake_git() {
    mkdir -p mockbin
    printf '#!/bin/bash\n%s\n' "$1" >mockbin/git
    chmod +x mockbin/git
    export PATH="$PWD/mockbin:$PATH"
}

@test "counts additions, deletions, replacements and identical files" {
    success '1 0' old new
    success '0 1' new old
    printf 'one\nchanged\n' >new
    success '1 1' old new
    cp old new
    success '0 0' old new
    success '0 0' old old
}

@test "counts whitespace, blank lines and empty files" {
    printf 'one \ntwo\n\n' >new
    success '2 1' old new
    : >old
    success '3 0' old new
    success '0 3' new old
    : >new
    success '0 0' old new
}

@test "preserves missing final newline and CRLF differences" {
    printf 'one' >old
    printf 'one\n' >new
    success '1 1' old new
    printf 'one\r\n' >new
    success '1 1' old new
}

@test "supports labels and repeated options" {
    success 'additions: 1, deletions: 0' -l old new
    success 'additions: 1, deletions: 0' --label old new
    success 'additions: 1, deletions: 0' -l --label -l old new
}

@test "rejects incorrect argument counts and unknown or combined options" {
    failure 2 'expected exactly two file arguments'
    failure 2 'expected exactly two file arguments' old
    failure 2 'expected exactly two file arguments' old new extra
    failure 2 'expected exactly two file arguments' old new --label
    for option in --unknown --lebel -lh -ll; do
        failure 2 'unknown option' "$option" old new
    done
}

@test "help wins throughout option prefix but stops at files and double dash" {
    for flag in -h --help; do
        run invoke --unknown "$flag" missing
        [ "$status" -eq 0 ]
        [ ! -s actual.err ]
        [[ $(<actual.out) == Usage:* ]]
    done
    cp old ./--help
    success '1 0' -- --help new
    failure 2 'expected exactly two file arguments' old new --help
}

@test "handles special path characters and option-like names" {
    local name
    for name in 'with spaces' $'with\ttab' $'with\nnewline\n' '日本語' '-old'; do
        cp old "./$name"
        success '1 0' -- "$name" new
    done
    cp old ./--label
    success '0 0' old --label
    cp old ./-h
    success '0 0' old -h
}

@test "version displays source placeholder and takes priority over invalid arguments" {
    success 'adddel @VERSION@' --version
    success 'adddel @VERSION@' --unknown --version missing
    success 'adddel @VERSION@' --version --unknown missing
    success 'adddel @VERSION@' --version --version
    failure 2 'unknown option' -V
}

@test "help takes priority over version and version stops at files and double dash" {
    run invoke --version --help
    [ "$status" -eq 0 ]
    [[ $(<actual.out) == Usage:* ]]
    [ ! -s actual.err ]
    run invoke --help --version
    [ "$status" -eq 0 ]
    [[ $(<actual.out) == Usage:* ]]
    cp old ./--version
    success '1 0' -- --version new
    success '0 0' old --version
    failure 2 'expected exactly two file arguments' old new --version
}

@test "follows symlinks including targets ending with newline" {
    ln -s old old-link
    ln -s new new-link
    success '1 0' old-link new-link
    success '0 0' old old-link
    mkdir nested
    cp old $'nested/target\n'
    ln -s $'nested/target\n' middle
    ln -s middle chain
    success '1 0' chain new
}

@test "rejects missing files, broken links and nonregular inputs" {
    failure 2 'input file does not exist' missing new
    ln -s missing broken
    failure 2 'input file does not exist' broken new
    mkdir directory
    mkfifo pipe
    failure 2 'input is not a regular file' directory new
    failure 2 'input is not a regular file' pipe new
    failure 2 'input is not a regular file' /dev/null new
}

@test "rejects unreadable files" {
    chmod 000 old
    [ ! -r old ] || skip 'current user can read files without read permissions'
    failure 2 'input file is not readable' old new
}

@test "allows identical binary content and rejects uncountable differences" {
    printf 'a\0b\n' >old
    cp old new
    success '0 0' old new
    printf 'a\0c\n' >new
    failure 2 'cannot count lines for binary input' old new
}

@test "works inside and outside repositories and honors binary attributes" {
    success '1 0' old new
    "$real_git" init -q .
    success '1 0' old new
    printf 'old -diff\nnew -diff\n' >.gitattributes
    failure 2 'cannot count lines for binary input' old new
}

@test "handles unavailable git and still gives help" {
    mkdir emptybin
    ln -s /bin/cat emptybin/cat
    export PATH="$PWD/emptybin"
    failure 1 'git is not available' old new
    run invoke --unknown --help
    [ "$status" -eq 0 ]
    [ ! -s actual.err ]
    success 'adddel @VERSION@' --unknown --version missing
}

@test "rejects failed git even when it emits valid-looking counts" {
    fake_git "printf '1\\t0\\tfile\\0'; echo failure >&2; exit 128"
    failure 1 'git diff failed' old new
}

@test "rejects malformed, incomplete and extra git records" {
    local payload
    for payload in '' '1\t' 'a\t0\tfile\0' '1\t-\tfile\0' '1\t0\tfile' '1\t0\t\0old\0' '1\t0\tfile\0extra' '1\t0\tfile\0extra\0'; do
        fake_git "printf '$payload'; exit 1"
        failure 1 'invalid git diff output' old new
    done
}

@test "parses complete NUL records and empty successful output" {
    fake_git "printf '12\\t5\\tfile\\0'; exit 1"
    success '12 5' old new
    fake_git "printf '12\\t5\\t\\0old\\0new\\0'; exit 1"
    success '12 5' old new
    fake_git 'exit 0'
    success '0 0' old new
}

@test "overrides configured algorithm heuristics and disables external diff and textconv" {
    "$real_git" init -q .
    "$real_git" config diff.algorithm histogram
    "$real_git" config diff.indentHeuristic true
    "$real_git" config diff.renames true
    printf '#!/bin/sh\ntouch "%s/called"\nexit 99\n' "$PWD" >converter
    chmod +x converter
    "$real_git" config diff.test.textconv "$PWD/converter"
    "$real_git" config diff.external "$PWD/converter"
    printf '* diff=test\n' >.gitattributes
    export GIT_EXTERNAL_DIFF="$PWD/converter"
    export REAL_GIT="$real_git" GIT_ARGS="$PWD/arguments"
    # Expansion happens in the generated script, not in the test process.
    # shellcheck disable=SC2016
    fake_git 'printf "%s\n" "$@" >"$GIT_ARGS"; exec "$REAL_GIT" "$@"'
    success '1 0' old new
    [ ! -e called ]
    for option in --diff-algorithm=myers --no-indent-heuristic --no-ext-diff --no-textconv --no-renames; do
        grep -Fx -- "$option" arguments
    done
}
