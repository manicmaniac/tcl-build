# tcl-build

[![Build Status](https://travis-ci.org/manicmaniac/tcl-build.svg)](https://travis-ci.org/manicmaniac/tcl-build)

tcl-build is an [tclenv](https://github.com/manicmaniac/tclenv) plugin that
provides an `tclenv install` command to compile and install different versions
of Tcl on UNIX-like systems.

You can also use tcl-build without tclenv in environments where you need
precise control over Tcl version installation.

See the [list of releases](https://github.com/manicmaniac/tcl-build/releases)
for changes in each version.


## Installation

### Installing as an tclenv plugin (recommended)

Installing tcl-build as an tclenv plugin will give you access to the `tclenv
install` command.

    git clone https://github.com/manicmaniac/tcl-build.git ~/.tclenv/plugins/tcl-build

This will install the latest development version of tcl-build into the
`~/.tclenv/plugins/tcl-build` directory. From that directory, you can check out
a specific release tag. To update tcl-build, run `git pull` to download the
latest changes.

### Installing as a standalone program (advanced)

Installing tcl-build as a standalone program will give you access to the
`tcl-build` command for precise control over Tcl version installation. If you
have tclenv installed, you will also be able to use the `tclenv install` command.

    git clone https://github.com/manicmaniac/tcl-build.git
    cd tcl-build
    ./install.sh

This will install tcl-build into `/usr/local`. If you do not have write
permission to `/usr/local`, you will need to run `sudo ./install.sh` instead.
You can install to a different prefix by setting the `PREFIX` environment
variable.

To update tcl-build after it has been installed, run `git pull` in your cloned
copy of the repository, then re-run the install script.

### Installing with Homebrew (for OS X users)

Mac OS X users can install tcl-build with the [Homebrew](http://brew.sh)
package manager. This will give you access to the `tcl-build` command. If you
have tclenv installed, you will also be able to use the `tclenv install` command.

*This is the recommended method of installation if you installed tclenv with
Homebrew.*

    brew install tcl-build

Or, if you would like to install the latest development release:

    brew install --HEAD tcl-build


## Usage

Before you begin, you should ensure that your build environment has the proper
system dependencies for compiling the wanted Tcl version (see our [recommendations](https://github.com/manicmaniac/tcl-build/wiki#suggested-build-environment)).

### Using `tclenv install` with tclenv

To install a Tcl version for use with tclenv, run `tclenv install` with the
exact name of the version you want to install. For example,

    tclenv install 2.2.0

Tcl versions will be installed into a directory of the same name under
`~/.tclenv/versions`.

To see a list of all available Tcl versions, run `tclenv install --list`. You
may also tab-complete available Tcl versions if your tclenv installation is
properly configured.

### Using `tcl-build` standalone

If you have installed tcl-build as a standalone program, you can use the
`tcl-build` command to compile and install Tcl versions into specific
locations.

Run the `tcl-build` command with the exact name of the version you want to
install and the full path where you want to install it. For example,

    tcl-build 2.2.0 ~/local/tcl-2.2.0

To see a list of all available Tcl versions, run `tcl-build --definitions`.

Pass the `-v` or `--verbose` flag to `tcl-build` as the first argument to see
what's happening under the hood.

### Custom definitions

Both `tclenv install` and `tcl-build` accept a path to a custom definition file
in place of a version name. Custom definitions let you develop and install
versions of Tcl that are not yet supported by tcl-build.

See the [tcl-build built-in definitions][definitions] as a starting point for
custom definition files.

[definitions]: https://github.com/manicmaniac/tcl-build/tree/master/share/tcl-build

### Special environment variables

You can set certain environment variables to control the build process.

* `TMPDIR` sets the location where tcl-build stores temporary files.
* `TCL_BUILD_BUILD_PATH` sets the location in which sources are downloaded and
  built. By default, this is a subdirectory of `TMPDIR`.
* `TCL_BUILD_CACHE_PATH`, if set, specifies a directory to use for caching
  downloaded package files.
* `TCL_BUILD_MIRROR_URL` overrides the default mirror URL root to one of your
  choosing.
* `TCL_BUILD_SKIP_MIRROR`, if set, forces tcl-build to download packages from
  their original source URLs instead of using a mirror.
* `TCL_BUILD_ROOT` overrides the default location from where build definitions
  in `share/tcl-build/` are looked up.
* `TCL_BUILD_DEFINITIONS` can be a list of colon-separated paths that get
  additionally searched when looking up build definitions.
* `CC` sets the path to the C compiler.
* `TCL_CFLAGS` lets you pass additional options to the default `CFLAGS`. Use
  this to override, for instance, the `-O3` option.
* `CONFIGURE_OPTS` lets you pass additional options to `./configure`.
* `MAKE` lets you override the command to use for `make`. Useful for specifying
  GNU make (`gmake`) on some systems.
* `MAKE_OPTS` (or `MAKEOPTS`) lets you pass additional options to `make`.
* `MAKE_INSTALL_OPTS` lets you pass additional options to `make install`.
* `TCL_CONFIGURE_OPTS`, `TCL_MAKE_OPTS` and `TCL_MAKE_INSTALL_OPTS` allow
  you to specify configure and make options for buildling MRI. These variables
  will be passed to Tcl only, not any dependent packages (e.g. libyaml).

### Applying patches to Tcl before compiling

Both `tclenv install` and `tcl-build` support the `--patch` (`-p`) flag that
signals that a patch from stdin should be applied to Tcl, JTcl, or Rubinius
source code before the `./configure` and compilation steps.

Example usage:

```sh
# applying a single patch
$ tclenv install --patch 1.9.3-p429 < /path/to/tcl.patch

# applying a patch from HTTP
$ tclenv install --patch 1.9.3-p429 < <(curl -sSL http://git.io/tcl.patch)

# applying multiple patches
$ cat fix1.patch fix2.patch | tclenv install --patch 1.9.3-p429
```

### Checksum verification

If you have the `shasum`, `openssl`, or `sha256sum` tool installed, tcl-build will
automatically verify the SHA2 checksum of each downloaded package before
installing it.

Checksums are optional and specified as anchors on the package URL in each
definition. (All bundled definitions include checksums.)

### Package download mirrors

tcl-build will first attempt to download package files from a mirror hosted on
Amazon CloudFront. If a package is not available on the mirror, if the mirror
is down, or if the download is corrupt, tcl-build will fall back to the
official URL specified in the definition file.

You can point tcl-build to another mirror by specifying the
`TCL_BUILD_MIRROR_URL` environment variable--useful if you'd like to run your
own local mirror, for example. Package mirror URLs are constructed by joining
this variable with the SHA2 checksum of the package file.

If you don't have an SHA2 program installed, tcl-build will skip the download
mirror and use official URLs instead. You can force tcl-build to bypass the
mirror by setting the `TCL_BUILD_SKIP_MIRROR` environment variable.

The official tcl-build download mirror is sponsored by
[Basecamp](https://basecamp.com/).

### Package download caching

You can instruct tcl-build to keep a local cache of downloaded package files
by setting the `TCL_BUILD_CACHE_PATH` environment variable. When set, package
files will be kept in this directory after the first successful download and
reused by subsequent invocations of `tcl-build` and `tclenv install`.

The `tclenv install` command defaults this path to `~/.tclenv/cache`, so in most
cases you can enable download caching simply by creating that directory.

### Keeping the build directory after installation

Both `tcl-build` and `tclenv install` accept the `-k` or `--keep` flag, which
tells tcl-build to keep the downloaded source after installation. This can be
useful if you need to use `gdb` and `memprof` with Tcl.

Source code will be kept in a parallel directory tree `~/.tclenv/sources` when
using `--keep` with the `tclenv install` command. You should specify the
location of the source code with the `TCL_BUILD_BUILD_PATH` environment
variable when using `--keep` with `tcl-build`.


## Getting Help

Please see the [tcl-build wiki][wiki] for solutions to common problems.

[wiki]: https://github.com/manicmaniac/tcl-build/wiki

If you can't find an answer on the wiki, open an issue on the [issue
tracker](https://github.com/manicmaniac/tcl-build/issues). Be sure to include
the full build log for build failures.


### License

(The MIT License)

Copyright (c) 2015 Ryosuke Ito
Copyright (c) 2012-2013 Sam Stephenson

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
