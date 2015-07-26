#!/usr/bin/env bats

load test_helper
export TCL_BUILD_CACHE_PATH="$TMP/cache"
export MAKE=make
export MAKE_OPTS="-j 2"
export CC=cc
export -n TCL_CONFIGURE_OPTS

setup() {
  mkdir -p "$INSTALL_ROOT"
  stub md5 false
  stub curl false
}

resolve_link() {
  $(type -p greadlink readlink | head -1) "$1"
}

executable() {
  local file="$1"
  mkdir -p "${file%/*}"
  cat > "$file"
  chmod +x "$file"
}

cached_tarball() {
  mkdir -p "$TCL_BUILD_CACHE_PATH"
  pushd "$TCL_BUILD_CACHE_PATH" >/dev/null
  tarball "$@"
  popd >/dev/null
}

tarball() {
  local name="$1"
  local path="$PWD/$name"
  local configure="$path/unix/configure"
  shift 1

  executable "${configure}" <<OUT
#!$BASH
echo "$name: \$@" \${TCLOPT:+TCLOPT=\$TCLOPT} >> build.log
OUT

  for file; do
    mkdir -p "$(dirname "${path}/${file}")"
    touch "${path}/${file}"
  done

  tar czf "${path}.tar.gz" -C "${path%/*}" "$name"
}

stub_make_install() {
  local bin_name="$1"

  stub "$MAKE" \
    " : echo \"$MAKE \$@\" >> build.log && mkdir '$INSTALL_ROOT/bin' && touch '$INSTALL_ROOT/bin/$bin_name'" \
    "install : echo \"$MAKE \$@\" >> build.log && cat build.log >> '$INSTALL_ROOT/build.log'"
}

assert_build_log() {
  run cat "$INSTALL_ROOT/build.log"
  assert_output
}

@test "number of CPU cores defaults to 2" {
  cached_tarball "tcl-8.6.4"

  stub uname '-s : echo Darwin'
  stub sysctl false
  stub_make_install "tclsh8.6"

  export -n MAKE_OPTS
  run_inline_definition <<DEF
install_package "tcl-8.6.4" "http://prdownloads.sourceforge.net/tcl/tcl8.6.4-src.tar.gz#d7cbb91f1ded1919370a30edd1534304"
DEF
  assert_success

  unstub uname
  unstub make

  assert_build_log <<OUT
tcl-8.6.4: --prefix=$INSTALL_ROOT
make -j 2
make install
OUT
}

@test "number of CPU cores is detected on Mac" {
  cached_tarball "tcl-8.6.4"

  stub uname '-s : echo Darwin'
  stub sysctl '-n hw.ncpu : echo 4'
  stub_make_install "tclsh8.6"

  export -n MAKE_OPTS
  run_inline_definition <<DEF
install_package "tcl-8.6.4" "http://prdownloads.sourceforge.net/tcl/tcl8.6.4-src.tar.gz#d7cbb91f1ded1919370a30edd1534304"
DEF
  assert_success

  unstub uname
  unstub sysctl
  unstub make

  assert_build_log <<OUT
tcl-8.6.4: --prefix=$INSTALL_ROOT
make -j 4
make install
OUT
}

@test "number of CPU cores is detected on FreeBSD" {
  cached_tarball "tcl-8.6.4"

  stub uname '-s : echo FreeBSD'
  stub sysctl '-n hw.ncpu : echo 1'
  stub_make_install "tclsh8.6"

  export -n MAKE_OPTS
  run_inline_definition <<DEF
install_package "tcl-8.6.4" "http://prdownloads.sourceforge.net/tcl/tcl8.6.4-src.tar.gz#d7cbb91f1ded1919370a30edd1534304"
DEF
  assert_success

  unstub uname
  unstub sysctl
  unstub make

  assert_build_log <<OUT
tcl-8.6.4: --prefix=$INSTALL_ROOT
make -j 1
make install
OUT
}

@test "setting TCL_MAKE_INSTALL_OPTS to a multi-word string" {
  cached_tarball "tcl-8.6.4"

  stub_make_install "tclsh8.6"

  export TCL_MAKE_INSTALL_OPTS="DOGE=\"such wow\""
  run_inline_definition <<DEF
install_package "tcl-8.6.4" "http://prdownloads.sourceforge.net/tcl/tcl8.6.4-src.tar.gz#d7cbb91f1ded1919370a30edd1534304"
DEF
  assert_success

  unstub make

  assert_build_log <<OUT
tcl-8.6.4: --prefix=$INSTALL_ROOT
make -j 2
make install DOGE="such wow"
OUT
}

@test "setting MAKE_INSTALL_OPTS to a multi-word string" {
  cached_tarball "tcl-8.6.4"

  stub_make_install "tclsh8.6"

  export MAKE_INSTALL_OPTS="DOGE=\"such wow\""
  run_inline_definition <<DEF
install_package "tcl-8.6.4" "http://prdownloads.sourceforge.net/tcl/tcl8.6.4-src.tar.gz#d7cbb91f1ded1919370a30edd1534304"
DEF
  assert_success

  unstub make

  assert_build_log <<OUT
tcl-8.6.4: --prefix=$INSTALL_ROOT
make -j 2
make install DOGE="such wow"
OUT
}

@test "custom relative install destination" {
  export TCL_BUILD_CACHE_PATH="$FIXTURE_ROOT"

  cd "$TMP"
  install_fixture definitions/without-checksum ./here
  assert_success
  assert [ -x ./here/bin/package ]
}

@test "make on FreeBSD 9 defaults to gmake" {
  cached_tarball "tcl-8.6.4"

  stub uname "-s : echo FreeBSD" "-r : echo 9.1"
  MAKE=gmake stub_make_install "tclsh8.6"

  MAKE= install_fixture definitions/vanilla-tcl
  assert_success

  unstub gmake
  unstub uname
}

@test "make on FreeBSD 10" {
  cached_tarball "tcl-8.6.4"

  stub uname "-s : echo FreeBSD" "-r : echo 10.0-RELEASE"
  stub_make_install "tclsh8.6"

  MAKE= install_fixture definitions/vanilla-tcl
  assert_success

  unstub uname

  resolve_link $INSTALL_ROOT/bin/tclsh
  assert_success
}

@test "can use TCL_CONFIGURE to apply a patch" {
  cached_tarball "tcl-8.6.4"

  executable "${TMP}/custom-configure" <<CONF
#!$BASH
apply -p1 -i /my/patch.diff
exec ./configure "\$@"
CONF

  stub apply 'echo apply "$@" >> build.log'
  stub_make_install "tclsh8.6"

  export TCL_CONFIGURE="${TMP}/custom-configure"
  run_inline_definition <<DEF
install_package "tcl-8.6.4" "http://prdownloads.sourceforge.net/tcl/tcl8.6.4-src.tar.gz#d7cbb91f1ded1919370a30edd1534304"
DEF
  assert_success

  unstub make
  unstub apply

  assert_build_log <<OUT
apply -p1 -i /my/patch.diff
tcl-8.6.4: --prefix=$INSTALL_ROOT
make -j 2
make install
OUT
}

@test "copy strategy forces overwrite" {
  export TCL_BUILD_CACHE_PATH="$FIXTURE_ROOT"

  mkdir -p "$INSTALL_ROOT/bin"
  touch "$INSTALL_ROOT/bin/package"
  chmod -w "$INSTALL_ROOT/bin/package"

  install_fixture definitions/without-checksum
  assert_success

  run "$INSTALL_ROOT/bin/package" "world"
  assert_success "hello world"
}

@test "Tk build" {
  cached_tarball "tk-8.6.4"

  stub_make_install "wish8.6"

  run_inline_definition <<DEF
install_package "tk-8.6.4" "http://downloads.sourceforge.net/project/tcl/Tcl/8.6.4/tk8.6.4-src.tar.gz#261754d7dc2a582f00e35547777e1fea" "tk"
DEF
  assert_success

  unstub make

  assert_build_log <<OUT
tk-8.6.4: --prefix=$INSTALL_ROOT
make -j 2
make install
OUT
  resolve_link $INSTALL_ROOT/bin/wish
  assert_success
}

@test "non-writable TMPDIR aborts build" {
  export TMPDIR="${TMP}/build"
  mkdir -p "$TMPDIR"
  chmod -w "$TMPDIR"

  touch "${TMP}/build-definition"
  run tcl-build "${TMP}/build-definition" "$INSTALL_ROOT"
  assert_failure "tcl-build: TMPDIR=$TMPDIR is set to a non-accessible location"
}

@test "non-executable TMPDIR aborts build" {
  export TMPDIR="${TMP}/build"
  mkdir -p "$TMPDIR"
  chmod -x "$TMPDIR"

  touch "${TMP}/build-definition"
  run tcl-build "${TMP}/build-definition" "$INSTALL_ROOT"
  assert_failure "tcl-build: TMPDIR=$TMPDIR is set to a non-accessible location"
}
