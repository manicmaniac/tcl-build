#!/usr/bin/env bats

load test_helper

@test "not enough arguments for tcl-build" {
  # use empty inline definition so nothing gets built anyway
  local definition="${TMP}/build-definition"
  echo '' > "$definition"

  run tcl-build "$definition"
  assert_failure
  assert_output_contains 'Usage: tcl-build'
}

@test "extra arguments for tcl-build" {
  # use empty inline definition so nothing gets built anyway
  local definition="${TMP}/build-definition"
  echo '' > "$definition"

  run tcl-build "$definition" "${TMP}/install" ""
  assert_failure
  assert_output_contains 'Usage: tcl-build'
}
