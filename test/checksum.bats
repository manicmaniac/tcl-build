#!/usr/bin/env bats

load test_helper
export TCL_BUILD_SKIP_MIRROR=1
export TCL_BUILD_CACHE_PATH=


@test "package URL without checksum" {
  stub shasum true
  stub curl "-q -o * -*S* http://example.com/* : cp $FIXTURE_ROOT/\${5##*/} \$3"

  install_fixture definitions/without-checksum
  [ "$status" -eq 0 ]
  [ -x "${INSTALL_ROOT}/bin/package" ]

  unstub curl
  unstub shasum
}


@test "package URL with valid checksum" {
  stub shasum true "echo ba988b1bb4250dee0b9dd3d4d722f9c64b2bacfc805d1b6eba7426bda72dd3c5"
  stub curl "-q -o * -*S* http://example.com/* : cp $FIXTURE_ROOT/\${5##*/} \$3"

  install_fixture definitions/with-checksum
  [ "$status" -eq 0 ]
  [ -x "${INSTALL_ROOT}/bin/package" ]

  unstub curl
  unstub shasum
}


@test "package URL with invalid checksum" {
  stub shasum true "echo ba988b1bb4250dee0b9dd3d4d722f9c64b2bacfc805d1b6eba7426bda72dd3c5"
  stub curl "-q -o * -*S* http://example.com/* : cp $FIXTURE_ROOT/\${5##*/} \$3"

  install_fixture definitions/with-invalid-checksum
  [ "$status" -eq 1 ]
  [ ! -f "${INSTALL_ROOT}/bin/package" ]

  unstub curl
  unstub shasum
}


@test "package URL with checksum but no shasum support" {
  stub shasum false
  stub curl "-q -o * -*S* http://example.com/* : cp $FIXTURE_ROOT/\${5##*/} \$3"

  install_fixture definitions/with-checksum
  [ "$status" -eq 0 ]
  [ -x "${INSTALL_ROOT}/bin/package" ]

  unstub curl
  unstub shasum
}


@test "package URL with valid md5 checksum" {
  stub md5 true "echo 83e6d7725e20166024a1eb74cde80677"
  stub curl "-q -o * -*S* http://example.com/* : cp $FIXTURE_ROOT/\${5##*/} \$3"

  install_fixture definitions/with-md5-checksum
  [ "$status" -eq 0 ]
  [ -x "${INSTALL_ROOT}/bin/package" ]

  unstub curl
  unstub md5
}


@test "package URL with md5 checksum but no md5 support" {
  stub md5 false
  stub curl "-q -o * -*S* http://example.com/* : cp $FIXTURE_ROOT/\${5##*/} \$3"

  install_fixture definitions/with-md5-checksum
  [ "$status" -eq 0 ]
  [ -x "${INSTALL_ROOT}/bin/package" ]

  unstub curl
  unstub md5
}


@test "package with invalid checksum" {
  stub shasum true "echo invalid"
  stub curl "-q -o * -*S* http://example.com/* : cp $FIXTURE_ROOT/\${5##*/} \$3"

  install_fixture definitions/with-checksum
  [ "$status" -eq 1 ]
  [ ! -f "${INSTALL_ROOT}/bin/package" ]

  unstub curl
  unstub shasum
}

@test "existing tarball in build location is reused" {
  stub shasum true "echo ba988b1bb4250dee0b9dd3d4d722f9c64b2bacfc805d1b6eba7426bda72dd3c5"
  stub curl false
  stub wget false

  export -n TCL_BUILD_CACHE_PATH
  export TCL_BUILD_BUILD_PATH="${TMP}/build"

  mkdir -p "$TCL_BUILD_BUILD_PATH"
  ln -s "${FIXTURE_ROOT}/package-1.0.0.tar.gz" "$TCL_BUILD_BUILD_PATH"

  run_inline_definition <<DEF
install_package "package-1.0.0" "http://example.com/packages/package-1.0.0.tar.gz#ba988b1bb4250dee0b9dd3d4d722f9c64b2bacfc805d1b6eba7426bda72dd3c5" copy
DEF

  assert_success
  [ -x "${INSTALL_ROOT}/bin/package" ]

  unstub shasum
}

@test "existing tarball in build location is discarded if not matching checksum" {
  stub shasum true \
    "echo invalid" \
    "echo ba988b1bb4250dee0b9dd3d4d722f9c64b2bacfc805d1b6eba7426bda72dd3c5"
  stub curl "-q -o * -*S* http://example.com/* : cp $FIXTURE_ROOT/\${5##*/} \$3"

  export -n TCL_BUILD_CACHE_PATH
  export TCL_BUILD_BUILD_PATH="${TMP}/build"

  mkdir -p "$TCL_BUILD_BUILD_PATH"
  touch "${TCL_BUILD_BUILD_PATH}/package-1.0.0.tar.gz"

  run_inline_definition <<DEF
install_package "package-1.0.0" "http://example.com/packages/package-1.0.0.tar.gz#ba988b1bb4250dee0b9dd3d4d722f9c64b2bacfc805d1b6eba7426bda72dd3c5" copy
DEF

  assert_success
  [ -x "${INSTALL_ROOT}/bin/package" ]

  unstub shasum
}
