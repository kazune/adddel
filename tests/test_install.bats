#!/usr/bin/env bats

setup() {
    root="$BATS_TEST_DIRNAME/.."
    real_make=$(command -v make)
    cd "$BATS_TEST_TMPDIR" || return
    cp "$root/Makefile" .
    mkdir -p dist/bin dist/share/man/man1
    cp "$root/src/adddel" dist/bin/adddel
    printf '.TH ADDDEL 1\n' >dist/share/man/man1/adddel.1
    # Installation sets permissions independently of source permissions.
    chmod 644 dist/bin/adddel
    chmod 755 dist/share/man/man1/adddel.1
}

mode() {
    local result
    if result=$(stat -c %a "$1" 2>/dev/null); then
        printf '%s\n' "$result"
    else
        stat -f %Lp "$1"
    fi
}

assert_installed() {
    local prefix=$1
    cmp dist/bin/adddel "$prefix/bin/adddel"
    cmp dist/share/man/man1/adddel.1 "$prefix/share/man/man1/adddel.1"
    [ "$(mode "$prefix/bin/adddel")" = 755 ]
    [ "$(mode "$prefix/share/man/man1/adddel.1")" = 644 ]
    [ "$(mode "$prefix/bin")" = 755 ]
    [ "$(mode "$prefix/share/man/man1")" = 755 ]
}

@test "installs to the default prefix under DESTDIR" {
    run make install DESTDIR="$PWD/stage"
    [ "$status" -eq 0 ]
    assert_installed "$PWD/stage/usr/local"
}

@test "supports a custom prefix and paths with spaces" {
    run make install PREFIX="$PWD/local tools"
    [ "$status" -eq 0 ]
    assert_installed "$PWD/local tools"
}

@test "combines DESTDIR and PREFIX" {
    run make install DESTDIR="$PWD/stage dir" PREFIX=/opt/adddel
    [ "$status" -eq 0 ]
    assert_installed "$PWD/stage dir/opt/adddel"
}

@test "overwrites installed files and resets their permissions" {
    run make install PREFIX="$PWD/local"
    [ "$status" -eq 0 ]
    printf 'old program\n' >local/bin/adddel
    printf 'old manual\n' >local/share/man/man1/adddel.1
    chmod 600 local/bin/adddel local/share/man/man1/adddel.1
    run make install PREFIX="$PWD/local"
    [ "$status" -eq 0 ]
    assert_installed "$PWD/local"
}

@test "checks both artifacts before changing the destination" {
    local artifact
    for artifact in dist/bin/adddel dist/share/man/man1/adddel.1; do
        mv "$artifact" saved
        run make install PREFIX="$PWD/local"
        [ "$status" -ne 0 ]
        [[ $output == *'run make dist first'* ]]
        [ ! -e local ]
        mv saved "$artifact"
    done
}

@test "rejects unreadable artifacts before changing the destination" {
    chmod 000 dist/share/man/man1/adddel.1
    [ ! -r dist/share/man/man1/adddel.1 ] || skip 'current user can read files without read permissions'
    run make install PREFIX="$PWD/local"
    [ "$status" -ne 0 ]
    [[ $output == *'run make dist first'* ]]
    [ ! -e local ]
}

@test "installs without Git, Pandoc or source files" {
    mkdir tools
    ln -s "$(command -v install)" tools/install
    run env PATH="$PWD/tools" "$real_make" install PREFIX="$PWD/local" PANDOC=unavailable
    [ "$status" -eq 0 ]
    assert_installed "$PWD/local"
}

@test "reports destination creation failures" {
    printf 'not a directory\n' >blocked
    run make install PREFIX="$PWD/blocked"
    [ "$status" -ne 0 ]
    [ ! -e blocked/bin/adddel ]
}

@test "reports file installation failures" {
    mkdir tools
    # Arguments are expanded by the generated script.
    # shellcheck disable=SC2016
    printf '#!/bin/bash\nif [ "$1" = -d ]; then exec "%s" "$@"; fi\nexit 1\n' "$(command -v install)" >tools/install
    chmod +x tools/install
    run make install PREFIX="$PWD/local" INSTALL="$PWD/tools/install"
    [ "$status" -ne 0 ]
    [ ! -e local/bin/adddel ]
}
