# Monitoring Refinement via Symbolic Reasoning

This project aims to develop efficient monitoring algorithms for concurrent
data structures, e.g., locks, semaphores, atomic registers, stacks, queues.

## Installation

This project is written in [Ruby], and works “out of the box” without
compilation nor installation. Of course, it does depend the availability of a
[Ruby] interpreter – see below.

## Requirements

In principle, this project works “out of the box” on any system with a
relatively-recent installation of Ruby — modulo the simple installation of a
couple “gems” noted below. That is our experience with OS X and Linux, though
use on Windows is untested. Technically though, we do require the following:

* [Ruby], version 2.0.0 or greater. Linux distributions and OS X generally come
  with [Ruby] preinstalled. Newer versions are easily installed using your
  system’s package manager. On OS X, we recommend using the [Homebrew] package
  manager. On Windows, Ruby can be installed with [RubyInstaller] or [Cygwin].

* The `ffi` and `os` Ruby gems. These are used, e.g., for interfacing with Z3.
  Normally, these are installed by running `gem install ffi os`; this command
  may require root privileges, depending on your configuration. On Linux, you
  may need to install `ffi` using your system’s package manager.

* The [libffi] library. Linux distributions and OS X generally come with
  [libffi] preinstalled. Otherwise, [libffi] is easily installed using your
  system’s package manager.
  
This project also uses [Z3] as a shared library. For convenience we provide the
[Z3] shared library prebuilt for 64bit OS X (Yosemite), Linux (OpenSUSE), and
Windows in the `xxx/` directory. Dependence on the platforms on which it was
built is unclear. In the case that problems involving `FFI` or `Z3` are
encountered, try obtaining [Z3] on your own, and include the appropriate
`libz3.{dylib,so,dll}` in your `LIBRARY_PATH`.

[Ruby]: https://www.ruby-lang.org
[RubyInstaller]: http://rubyinstaller.org
[Homebrew]: http://brew.sh
[Cygwin]: https://www.cygwin.com
[libffi]: https://sourceware.org/libffi
[Z3]: http://z3.codeplex.com

## Contents

Files in this project are organized according to the following directory
structure.

* `bin/` contains executables:
    * `loggenerator.rb` for generating history logs,
    * `logchecker.rb` for checking history logs, and
    * `report.rb` for generating reports.

* `data/` contains various data:
    * `experiments/` contains empirical measurements,
    * `histories/` contains history logs,
        * `generated/` contains history logs generated from actual executions,
        * `simple/` contains hand-crafted history logs,
    * `plots/` contains visualizations of empirical measurements, and
    * `reports/` contains reports benchmarking the performance of each algorithm.

* `lib/` contains the source code of the checking algorithms.

* `pldi-2015-submission.pdf` is a research paper accepted to [PLDI 2015][].

* `xxx/` contains prebuilt external shared-libraries for OSX, Windows, and Linux.

[PLDI 2015]: http://conf.researchr.org/home/pldi2015

## Usage

To try out the history checking algorithms, run, for example

    ./bin/logchecker.rb data/histories/simple/lifo-violation-dhk-2.log -a symbolic -v

To see the list of options, run

    ./bin/logchecker.rb --help
    
To generate benchmarking reports, run

    ./bin/report.rb

And that’s about it.
