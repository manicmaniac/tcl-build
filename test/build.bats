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
  local configure="$path/configure"
  shift 1

  executable "$configure" <<OUT
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
  stub "$MAKE" \
    " : echo \"$MAKE \$@\" >> build.log" \
    "install : echo \"$MAKE \$@\" >> build.log && cat build.log >> '$INSTALL_ROOT/build.log'"
}

assert_build_log() {
  run cat "$INSTALL_ROOT/build.log"
  assert_output
}

@test "yaml is installed for tcl" {
  cached_tarball "yaml-0.1.6"
  cached_tarball "tcl-2.0.0"

  stub brew false
  stub_make_install
  stub_make_install

  install_fixture definitions/needs-yaml
  assert_success

  unstub make

  assert_build_log <<OUT
yaml-0.1.6: --prefix=$INSTALL_ROOT
make -j 2
make install
tcl-2.0.0: --prefix=$INSTALL_ROOT
make -j 2
make install
OUT
}

@test "apply tcl patch before building" {
  cached_tarball "yaml-0.1.6"
  cached_tarball "tcl-2.0.0"

  stub brew false
  stub_make_install
  stub_make_install
  stub patch ' : echo patch "$@" | sed -E "s/\.[[:alnum:]]+$/.XXX/" >> build.log'

  TMPDIR="$TMP" install_fixture --patch definitions/needs-yaml <<<""
  assert_success

  unstub make
  unstub patch

  assert_build_log <<OUT
yaml-0.1.6: --prefix=$INSTALL_ROOT
make -j 2
make install
patch -p0 --force -i $TMP/tcl-patch.XXX
tcl-2.0.0: --prefix=$INSTALL_ROOT
make -j 2
make install
OUT
}

@test "apply tcl patch from git diff before building" {
  cached_tarball "yaml-0.1.6"
  cached_tarball "tcl-2.0.0"

  stub brew false
  stub_make_install
  stub_make_install
  stub patch ' : echo patch "$@" | sed -E "s/\.[[:alnum:]]+$/.XXX/" >> build.log'

  TMPDIR="$TMP" install_fixture --patch definitions/needs-yaml <<<"diff --git a/script.rb"
  assert_success

  unstub make
  unstub patch

  assert_build_log <<OUT
yaml-0.1.6: --prefix=$INSTALL_ROOT
make -j 2
make install
patch -p1 --force -i $TMP/tcl-patch.XXX
tcl-2.0.0: --prefix=$INSTALL_ROOT
make -j 2
make install
OUT
}

@test "yaml is linked from Homebrew" {
  cached_tarball "tcl-2.0.0"

  brew_libdir="$TMP/homebrew-yaml"
  mkdir -p "$brew_libdir"

  stub brew "--prefix libyaml : echo '$brew_libdir'" false
  stub_make_install

  install_fixture definitions/needs-yaml
  assert_success

  unstub brew
  unstub make

  assert_build_log <<OUT
tcl-2.0.0: --prefix=$INSTALL_ROOT --with-libyaml-dir=$brew_libdir
make -j 2
make install
OUT
}

@test "readline is linked from Homebrew" {
  cached_tarball "tcl-2.0.0"

  readline_libdir="$TMP/homebrew-readline"
  mkdir -p "$readline_libdir"

  stub brew "--prefix readline : echo '$readline_libdir'"
  stub_make_install

  run_inline_definition <<DEF
install_package "tcl-2.0.0" "http://tcl-lang.org/tcl/2.0/tcl-2.0.0.tar.gz"
DEF
  assert_success

  unstub brew
  unstub make

  assert_build_log <<OUT
tcl-2.0.0: --prefix=$INSTALL_ROOT --with-readline-dir=$readline_libdir
make -j 2
make install
OUT
}

@test "readline is not linked from Homebrew when explicitly defined" {
  cached_tarball "tcl-2.0.0"

  stub brew
  stub_make_install

  export TCL_CONFIGURE_OPTS='--with-readline-dir=/custom'
  run_inline_definition <<DEF
install_package "tcl-2.0.0" "http://tcl-lang.org/tcl/2.0/tcl-2.0.0.tar.gz"
DEF
  assert_success

  unstub brew
  unstub make

  assert_build_log <<OUT
tcl-2.0.0: --prefix=$INSTALL_ROOT --with-readline-dir=/custom
make -j 2
make install
OUT
}

@test "number of CPU cores defaults to 2" {
  cached_tarball "tcl-2.0.0"

  stub uname '-s : echo Darwin'
  stub sysctl false
  stub_make_install

  export -n MAKE_OPTS
  run_inline_definition <<DEF
install_package "tcl-2.0.0" "http://tcl-lang.org/tcl/2.0/tcl-2.0.0.tar.gz"
DEF
  assert_success

  unstub uname
  unstub make

  assert_build_log <<OUT
tcl-2.0.0: --prefix=$INSTALL_ROOT
make -j 2
make install
OUT
}

@test "number of CPU cores is detected on Mac" {
  cached_tarball "tcl-2.0.0"

  stub uname '-s : echo Darwin'
  stub sysctl '-n hw.ncpu : echo 4'
  stub_make_install

  export -n MAKE_OPTS
  run_inline_definition <<DEF
install_package "tcl-2.0.0" "http://tcl-lang.org/tcl/2.0/tcl-2.0.0.tar.gz"
DEF
  assert_success

  unstub uname
  unstub sysctl
  unstub make

  assert_build_log <<OUT
tcl-2.0.0: --prefix=$INSTALL_ROOT
make -j 4
make install
OUT
}

@test "number of CPU cores is detected on FreeBSD" {
  cached_tarball "tcl-2.0.0"

  stub uname '-s : echo FreeBSD'
  stub sysctl '-n hw.ncpu : echo 1'
  stub_make_install

  export -n MAKE_OPTS
  run_inline_definition <<DEF
install_package "tcl-2.0.0" "http://tcl-lang.org/tcl/2.0/tcl-2.0.0.tar.gz"
DEF
  assert_success

  unstub uname
  unstub sysctl
  unstub make

  assert_build_log <<OUT
tcl-2.0.0: --prefix=$INSTALL_ROOT
make -j 1
make install
OUT
}

@test "setting TCL_MAKE_INSTALL_OPTS to a multi-word string" {
  cached_tarball "tcl-2.0.0"

  stub_make_install

  export TCL_MAKE_INSTALL_OPTS="DOGE=\"such wow\""
  run_inline_definition <<DEF
install_package "tcl-2.0.0" "http://tcl-lang.org/tcl/2.0/tcl-2.0.0.tar.gz"
DEF
  assert_success

  unstub make

  assert_build_log <<OUT
tcl-2.0.0: --prefix=$INSTALL_ROOT
make -j 2
make install DOGE="such wow"
OUT
}

@test "setting MAKE_INSTALL_OPTS to a multi-word string" {
  cached_tarball "tcl-2.0.0"

  stub_make_install

  export MAKE_INSTALL_OPTS="DOGE=\"such wow\""
  run_inline_definition <<DEF
install_package "tcl-2.0.0" "http://tcl-lang.org/tcl/2.0/tcl-2.0.0.tar.gz"
DEF
  assert_success

  unstub make

  assert_build_log <<OUT
tcl-2.0.0: --prefix=$INSTALL_ROOT
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
  cached_tarball "tcl-2.0.0"

  stub uname "-s : echo FreeBSD" "-r : echo 9.1"
  MAKE=gmake stub_make_install

  MAKE= install_fixture definitions/vanilla-tcl
  assert_success

  unstub gmake
  unstub uname
}

@test "make on FreeBSD 10" {
  cached_tarball "tcl-2.0.0"

  stub uname "-s : echo FreeBSD" "-r : echo 10.0-RELEASE"
  stub_make_install

  MAKE= install_fixture definitions/vanilla-tcl
  assert_success

  unstub uname
}

@test "can use TCL_CONFIGURE to apply a patch" {
  cached_tarball "tcl-2.0.0"

  executable "${TMP}/custom-configure" <<CONF
#!$BASH
apply -p1 -i /my/patch.diff
exec ./configure "\$@"
CONF

  stub apply 'echo apply "$@" >> build.log'
  stub_make_install

  export TCL_CONFIGURE="${TMP}/custom-configure"
  run_inline_definition <<DEF
install_package "tcl-2.0.0" "http://tcl-lang.org/pub/tcl-2.0.0.tar.gz"
DEF
  assert_success

  unstub make
  unstub apply

  assert_build_log <<OUT
apply -p1 -i /my/patch.diff
tcl-2.0.0: --prefix=$INSTALL_ROOT
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

@test "mtcl strategy overwrites non-writable files" {
  cached_tarball "mtcl-1.0" build/host/bin/{mtcl,mirb}

  mkdir -p "$INSTALL_ROOT/bin"
  touch "$INSTALL_ROOT/bin/mtcl"
  chmod -w "$INSTALL_ROOT/bin/mtcl"

  stub gem false
  stub rake '--version : echo 1' true

  run_inline_definition <<DEF
install_package "mtcl-1.0" "http://tcl-lang.org/pub/mtcl-1.0.tar.gz" mtcl
DEF
  assert_success

  unstub rake

  assert [ -w "$INSTALL_ROOT/bin/mtcl" ]
  assert [ -e "$INSTALL_ROOT/bin/tcl" ]
  assert [ -e "$INSTALL_ROOT/bin/irb" ]
}

@test "mtcl strategy fetches rake if missing" {
  cached_tarball "mtcl-1.0" build/host/bin/mtcl

  stub rake '--version : false' true
  stub gem 'install rake -v *10.1.0 : true'

  run_inline_definition <<DEF
install_package "mtcl-1.0" "http://tcl-lang.org/pub/mtcl-1.0.tar.gz" mtcl
DEF
  assert_success

  unstub gem
  unstub rake
}

@test "rbx uses bundle then rake" {
  cached_tarball "rubinius-2.0.0" "Gemfile"

  stub gem false
  stub rake false
  stub bundle \
    '--version : echo 1' \
    ' : echo bundle "$@" >> build.log' \
    '--version : echo 1' \
    " exec rake install : { cat build.log; echo bundle \"\$@\"; } >> '$INSTALL_ROOT/build.log'"

  run_inline_definition <<DEF
install_package "rubinius-2.0.0" "http://releases.rubini.us/rubinius-2.0.0.tar.gz" rbx
DEF
  assert_success

  unstub bundle

  assert_build_log <<OUT
bundle --path=vendor/bundle
rubinius-2.0.0: --prefix=$INSTALL_ROOT TCLOPT=-tclgems
bundle exec rake install
OUT
}

@test "fixes rbx binstubs" {
  executable "${TCL_BUILD_CACHE_PATH}/rubinius-2.0.0/gems/bin/rake" <<OUT
#!rbx
puts 'rake'
OUT
  executable "${TCL_BUILD_CACHE_PATH}/rubinius-2.0.0/gems/bin/irb" <<OUT
#!rbx
print '>>'
OUT
  cached_tarball "rubinius-2.0.0" bin/tcl

  stub bundle false
  stub rake \
    '--version : echo 1' \
    "install : mkdir -p '$INSTALL_ROOT'; cp -fR . '$INSTALL_ROOT'"

  run_inline_definition <<DEF
install_package "rubinius-2.0.0" "http://releases.rubini.us/rubinius-2.0.0.tar.gz" rbx
DEF
  assert_success

  unstub rake

  run ls "${INSTALL_ROOT}/bin"
  assert_output <<OUT
irb
rake
tcl
OUT

  run $(type -p greadlink readlink | head -1) "${INSTALL_ROOT}/gems/bin"
  assert_success '../bin'

  assert [ -x "${INSTALL_ROOT}/bin/rake" ]
  run cat "${INSTALL_ROOT}/bin/rake"
  assert_output <<OUT
#!${INSTALL_ROOT}/bin/tcl
puts 'rake'
OUT

  assert [ -x "${INSTALL_ROOT}/bin/irb" ]
  run cat "${INSTALL_ROOT}/bin/irb"
  assert_output <<OUT
#!${INSTALL_ROOT}/bin/tcl
print '>>'
OUT
}

@test "JTcl build" {
  executable "${TCL_BUILD_CACHE_PATH}/jtcl-1.7.9/bin/jtcl" <<OUT
#!${BASH}
echo jtcl "\$@" >> ../build.log
OUT
  executable "${TCL_BUILD_CACHE_PATH}/jtcl-1.7.9/bin/gem" <<OUT
#!/usr/bin/env jtcl
nice gem things
OUT
  cached_tarball "jtcl-1.7.9" bin/foo.exe bin/bar.dll bin/baz.bat

  run_inline_definition <<DEF
install_package "jtcl-1.7.9" "http://jtcl.org/downloads/jtcl-bin-1.7.9.tar.gz" jtcl
DEF
  assert_success

  assert_build_log <<OUT
jtcl gem install jtcl-launcher
OUT

  run ls "${INSTALL_ROOT}/bin"
  assert_output <<OUT
gem
jtcl
tcl
OUT

  assert [ -x "${INSTALL_ROOT}/bin/gem" ]
  run cat "${INSTALL_ROOT}/bin/gem"
  assert_output <<OUT
#!${INSTALL_ROOT}/bin/jtcl
nice gem things
OUT
}

@test "JTcl+Graal does not install launchers" {
  executable "${TCL_BUILD_CACHE_PATH}/jtcl-9000.dev/bin/jtcl" <<OUT
#!${BASH}
# graalvm
echo jtcl "\$@" >> ../build.log
OUT
  cached_tarball "jtcl-9000.dev"

  run_inline_definition <<DEF
install_package "jtcl-9000.dev" "http://lafo.ssw.uni-linz.ac.at/jtcl-9000+graal-macosx-x86_64.tar.gz" jtcl
DEF
  assert_success

  assert [ ! -e "$INSTALL_ROOT/build.log" ]
}

@test "JTcl Java 7 missing" {
  cached_tarball "jtcl-9000.dev" bin/jtcl

  stub java false

  run_inline_definition <<DEF
require_java7
install_package "jtcl-9000.dev" "http://ci.jtcl.org/jtcl-dist-9000.dev-bin.tar.gz" jtcl
DEF
  assert_failure
  assert_output_contains "ERROR: Java 7 required. Please install a 1.7-compatible JRE."
}

@test "JTcl Java is outdated" {
  cached_tarball "jtcl-9000.dev" bin/jtcl

  stub java '-version : echo java version "1.6.0_21" >&2'

  run_inline_definition <<DEF
require_java7
install_package "jtcl-9000.dev" "http://ci.jtcl.org/jtcl-dist-9000.dev-bin.tar.gz" jtcl
DEF
  assert_failure
  assert_output_contains "ERROR: Java 7 required. Please install a 1.7-compatible JRE."
}

@test "JTcl Java 7 up-to-date" {
  cached_tarball "jtcl-9000.dev" bin/jtcl

  stub java '-version : echo java version "1.7.0_21" >&2'

  run_inline_definition <<DEF
require_java7
install_package "jtcl-9000.dev" "http://ci.jtcl.org/jtcl-dist-9000.dev-bin.tar.gz" jtcl
DEF
  assert_success
}

@test "Java version string not on first line" {
  cached_tarball "jtcl-9000.dev" bin/jtcl

  stub java "-version : echo 'Picked up JAVA_TOOL_OPTIONS' >&2; echo 'java version \"1.8.0_31\"' >&2"

  run_inline_definition <<DEF
require_java7
install_package "jtcl-9000.dev" "http://ci.jtcl.org/jtcl-dist-9000.dev-bin.tar.gz" jtcl
DEF
  assert_success
}

@test "Java version string on OpenJDK" {
  cached_tarball "jtcl-9000.dev" bin/jtcl

  stub java "-version : echo 'openjdk version \"1.8.0_40\"' >&2"

  run_inline_definition <<DEF
require_java7
install_package "jtcl-9000.dev" "http://ci.jtcl.org/jtcl-dist-9000.dev-bin.tar.gz" jtcl
DEF
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
