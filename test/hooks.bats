#!/usr/bin/env bats

load test_helper

setup() {
  export TCLENV_ROOT="${TMP}/tclenv"
  export HOOK_PATH="${TMP}/i has hooks"
  mkdir -p "$HOOK_PATH"
}

@test "tclenv-install hooks" {
  cat > "${HOOK_PATH}/install.bash" <<OUT
before_install 'echo before: \$PREFIX'
after_install 'echo after: \$STATUS'
OUT
  stub tclenv-hooks "install : echo '$HOOK_PATH'/install.bash"
  stub tclenv-rehash "echo rehashed"

  definition="${TMP}/2.0.0"
  cat > "$definition" <<<"echo tcl-build"
  run tclenv-install "$definition"

  assert_success
  assert_output <<-OUT
before: ${TCLENV_ROOT}/versions/2.0.0
tcl-build
after: 0
rehashed
OUT
}

@test "tclenv-uninstall hooks" {
  cat > "${HOOK_PATH}/uninstall.bash" <<OUT
before_uninstall 'echo before: \$PREFIX'
after_uninstall 'echo after.'
rm() {
  echo "rm \$@"
  command rm "\$@"
}
OUT
  stub tclenv-hooks "uninstall : echo '$HOOK_PATH'/uninstall.bash"
  stub tclenv-rehash "echo rehashed"

  mkdir -p "${TCLENV_ROOT}/versions/2.0.0"
  run tclenv-uninstall -f 2.0.0

  assert_success
  assert_output <<-OUT
before: ${TCLENV_ROOT}/versions/2.0.0
rm -rf ${TCLENV_ROOT}/versions/2.0.0
rehashed
after.
OUT

  assert [ ! -d "${TCLENV_ROOT}/versions/2.0.0" ]
}
