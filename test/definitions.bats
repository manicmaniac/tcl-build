#!/usr/bin/env bats

load test_helper
NUM_DEFINITIONS="$(ls "$BATS_TEST_DIRNAME"/../share/tcl-build | wc -l)"

@test "list built-in definitions" {
  run tcl-build --definitions
  assert_success
  assert_output_contains "8.6.4"
  assert_output_contains "8.5.15"
  assert [ "${#lines[*]}" -eq "$NUM_DEFINITIONS" ]
}

@test "custom TCL_BUILD_ROOT: nonexistent" {
  export TCL_BUILD_ROOT="$TMP"
  assert [ ! -e "${TCL_BUILD_ROOT}/share/tcl-build" ]
  run tcl-build --definitions
  assert_success ""
}

@test "custom TCL_BUILD_ROOT: single definition" {
  export TCL_BUILD_ROOT="$TMP"
  mkdir -p "${TCL_BUILD_ROOT}/share/tcl-build"
  touch "${TCL_BUILD_ROOT}/share/tcl-build/1.9.3-test"
  run tcl-build --definitions
  assert_success "1.9.3-test"
}

@test "one path via TCL_BUILD_DEFINITIONS" {
  export TCL_BUILD_DEFINITIONS="${TMP}/definitions"
  mkdir -p "$TCL_BUILD_DEFINITIONS"
  touch "${TCL_BUILD_DEFINITIONS}/1.9.3-test"
  run tcl-build --definitions
  assert_success
  assert_output_contains "1.9.3-test"
  assert [ "${#lines[*]}" -eq "$((NUM_DEFINITIONS + 1))" ]
}

@test "multiple paths via TCL_BUILD_DEFINITIONS" {
  export TCL_BUILD_DEFINITIONS="${TMP}/definitions:${TMP}/other"
  mkdir -p "${TMP}/definitions"
  touch "${TMP}/definitions/1.9.3-test"
  mkdir -p "${TMP}/other"
  touch "${TMP}/other/2.1.2-test"
  run tcl-build --definitions
  assert_success
  assert_output_contains "1.9.3-test"
  assert_output_contains "2.1.2-test"
  assert [ "${#lines[*]}" -eq "$((NUM_DEFINITIONS + 2))" ]
}

@test "installing definition from TCL_BUILD_DEFINITIONS by priority" {
  export TCL_BUILD_DEFINITIONS="${TMP}/definitions:${TMP}/other"
  mkdir -p "${TMP}/definitions"
  echo true > "${TMP}/definitions/1.9.3-test"
  mkdir -p "${TMP}/other"
  echo false > "${TMP}/other/1.9.3-test"
  run tcl-build "1.9.3-test" "${TMP}/install"
  assert_success ""
}

@test "installing nonexistent definition" {
  run tcl-build "nonexistent" "${TMP}/install"
  assert [ "$status" -eq 2 ]
  assert_output "tcl-build: definition not found: nonexistent"
}

@test "sorting Tcl versions" {
  export TCL_BUILD_ROOT="$TMP"
  mkdir -p "${TCL_BUILD_ROOT}/share/tcl-build"
  expected="1.9.3-dev
1.9.3-preview1
1.9.3-rc1
1.9.3-p0
1.9.3-p125
2.1.0-dev
2.1.0-rc1
2.1.0
2.1.1
2.2.0-dev
jtcl-1.6.5
jtcl-1.6.5.1
jtcl-1.7.0-preview1
jtcl-1.7.0-rc1
jtcl-1.7.0
jtcl-1.7.1
jtcl-1.7.9
jtcl-1.7.10
jtcl-9000-dev
jtcl-9000"
  for ver in "$expected"; do
    touch "${TCL_BUILD_ROOT}/share/tcl-build/$ver"
  done
  run tcl-build --definitions
  assert_success "$expected"
}

@test "removing duplicate Tcl versions" {
  export TCL_BUILD_ROOT="$TMP"
  export TCL_BUILD_DEFINITIONS="${TCL_BUILD_ROOT}/share/tcl-build"
  mkdir -p "$TCL_BUILD_DEFINITIONS"
  touch "${TCL_BUILD_DEFINITIONS}/1.9.3"
  touch "${TCL_BUILD_DEFINITIONS}/2.2.0"

  run tcl-build --definitions
  assert_success
  assert_output <<OUT
1.9.3
2.2.0
OUT
}
