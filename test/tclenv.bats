#!/usr/bin/env bats

load test_helper
export TCLENV_ROOT="${TMP}/tclenv"

setup() {
  stub tclenv-hooks 'install : true'
  stub tclenv-rehash 'true'
}

stub_tcl_build() {
  stub tcl-build "--lib : $BATS_TEST_DIRNAME/../bin/tcl-build --lib" "$@"
}

@test "install proper" {
  stub_tcl_build 'echo tcl-build "$@"'

  run tclenv-install 2.1.2
  assert_success "tcl-build 2.1.2 ${TCLENV_ROOT}/versions/2.1.2"

  unstub tcl-build
  unstub tclenv-hooks
  unstub tclenv-rehash
}

@test "install tclenv local version by default" {
  stub_tcl_build 'echo tcl-build "$1"'
  stub tclenv-local 'echo 2.1.2'

  run tclenv-install
  assert_success "tcl-build 2.1.2"

  unstub tcl-build
  unstub tclenv-local
}

@test "list available versions" {
  stub_tcl_build \
    "--definitions : echo 1.8.7 1.9.3-p0 1.9.3-p194 2.1.2 | tr ' ' $'\\n'"

  run tclenv-install --list
  assert_success
  assert_output <<OUT
Available versions:
  1.8.7
  1.9.3-p0
  1.9.3-p194
  2.1.2
OUT

  unstub tcl-build
}

@test "nonexistent version" {
  stub brew false
  stub_tcl_build 'echo ERROR >&2 && exit 2' \
    "--definitions : echo 1.8.7 1.9.3-p0 1.9.3-p194 2.1.2 | tr ' ' $'\\n'"

  run tclenv-install 1.9.3
  assert_failure
  assert_output <<OUT
ERROR

The following versions contain \`1.9.3' in the name:
  1.9.3-p0
  1.9.3-p194

See all available versions with \`tclenv install --list'.

If the version you need is missing, try upgrading tcl-build:

  cd ${BATS_TEST_DIRNAME}/.. && git pull && cd -
OUT

  unstub tcl-build
}

@test "Homebrew upgrade instructions" {
  stub brew "--prefix : echo '${BATS_TEST_DIRNAME%/*}'"
  stub_tcl_build 'echo ERROR >&2 && exit 2' \
    "--definitions : true"

  run tclenv-install 1.9.3
  assert_failure
  assert_output <<OUT
ERROR

See all available versions with \`tclenv install --list'.

If the version you need is missing, try upgrading tcl-build:

  brew update && brew upgrade tcl-build
OUT

  unstub brew
  unstub tcl-build
}

@test "no build definitions from plugins" {
  assert [ ! -e "${TCLENV_ROOT}/plugins" ]
  stub_tcl_build 'echo $TCL_BUILD_DEFINITIONS'

  run tclenv-install 2.1.2
  assert_success ""
}

@test "some build definitions from plugins" {
  mkdir -p "${TCLENV_ROOT}/plugins/foo/share/tcl-build"
  mkdir -p "${TCLENV_ROOT}/plugins/bar/share/tcl-build"
  stub_tcl_build "echo \$TCL_BUILD_DEFINITIONS | tr ':' $'\\n'"

  run tclenv-install 2.1.2
  assert_success
  assert_output <<OUT

${TCLENV_ROOT}/plugins/bar/share/tcl-build
${TCLENV_ROOT}/plugins/foo/share/tcl-build
OUT
}

@test "list build definitions from plugins" {
  mkdir -p "${TCLENV_ROOT}/plugins/foo/share/tcl-build"
  mkdir -p "${TCLENV_ROOT}/plugins/bar/share/tcl-build"
  stub_tcl_build "--definitions : echo \$TCL_BUILD_DEFINITIONS | tr ':' $'\\n'"

  run tclenv-install --list
  assert_success
  assert_output <<OUT
Available versions:
  
  ${TCLENV_ROOT}/plugins/bar/share/tcl-build
  ${TCLENV_ROOT}/plugins/foo/share/tcl-build
OUT
}

@test "completion results include build definitions from plugins" {
  mkdir -p "${TCLENV_ROOT}/plugins/foo/share/tcl-build"
  mkdir -p "${TCLENV_ROOT}/plugins/bar/share/tcl-build"
  stub tcl-build "--definitions : echo \$TCL_BUILD_DEFINITIONS | tr ':' $'\\n'"

  run tclenv-install --complete
  assert_success
  assert_output <<OUT

${TCLENV_ROOT}/plugins/bar/share/tcl-build
${TCLENV_ROOT}/plugins/foo/share/tcl-build
OUT
}

@test "not enough arguments for tclenv-install" {
  stub_tcl_build
  stub tclenv-help 'install : true'

  run tclenv-install
  assert_failure
  unstub tclenv-help
}

@test "too many arguments for tclenv-install" {
  stub_tcl_build
  stub tclenv-help 'install : true'

  run tclenv-install 2.1.1 2.1.2
  assert_failure
  unstub tclenv-help
}

@test "show help for tclenv-install" {
  stub_tcl_build
  stub tclenv-help 'install : true'

  run tclenv-install -h
  assert_success
  unstub tclenv-help
}

@test "tclenv-install has usage help preface" {
  run head "$(which tclenv-install)"
  assert_output_contains 'Usage: tclenv install'
}

@test "not enough arguments tclenv-uninstall" {
  stub tclenv-help 'uninstall : true'

  run tclenv-uninstall
  assert_failure
  unstub tclenv-help
}

@test "too many arguments for tclenv-uninstall" {
  stub tclenv-help 'uninstall : true'

  run tclenv-uninstall 2.1.1 2.1.2
  assert_failure
  unstub tclenv-help
}

@test "show help for tclenv-uninstall" {
  stub tclenv-help 'uninstall : true'

  run tclenv-uninstall -h
  assert_success
  unstub tclenv-help
}

@test "tclenv-uninstall has usage help preface" {
  run head "$(which tclenv-uninstall)"
  assert_output_contains 'Usage: tclenv uninstall'
}
