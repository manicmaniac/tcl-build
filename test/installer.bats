#!/usr/bin/env bats

load test_helper

@test "installs tcl-build into PREFIX" {
  cd "$TMP"
  PREFIX="${PWD}/usr" run "${BATS_TEST_DIRNAME}/../install.sh"
  assert_success ""

  cd usr

  assert [ -x bin/tcl-build ]
  assert [ -x bin/tclenv-install ]
  assert [ -x bin/tclenv-uninstall ]

  assert [ -e share/tcl-build/8.6.4 ]
  assert [ -e share/tcl-build/8.0.2 ]
}

@test "build definitions don't have the executable bit" {
  cd "$TMP"
  PREFIX="${PWD}/usr" run "${BATS_TEST_DIRNAME}/../install.sh"
  assert_success ""

  run $BASH -c 'ls -l usr/share/tcl-build | tail -2 | cut -c1-10'
  assert_output <<OUT
-rw-r--r--
-rw-r--r--
OUT
}

@test "overwrites old installation" {
  cd "$TMP"
  mkdir -p bin share/tcl-build
  touch bin/tcl-build
  touch share/tcl-build/8.6.4

  PREFIX="$PWD" run "${BATS_TEST_DIRNAME}/../install.sh"
  assert_success ""

  assert [ -x bin/tcl-build ]
  run grep "install_package" share/tcl-build/8.6.4
  assert_success
}

@test "unrelated files are untouched" {
  cd "$TMP"
  mkdir -p bin share/bananas
  chmod g-w bin
  touch bin/bananas
  touch share/bananas/docs

  PREFIX="$PWD" run "${BATS_TEST_DIRNAME}/../install.sh"
  assert_success ""

  assert [ -e bin/bananas ]
  assert [ -e share/bananas/docs ]

  run ls -ld bin
  assert_equal "r-x" "${output:4:3}"
}
