# Monitoring Refinement via Symbolic Reasoning

This project aims to develop efficient monitoring algorithms for concurrent
data structures, e.g., locks, semaphores, atomic registers, stacks, queues.

## Contents

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

## Requirements

* [Ruby][]: a recent version; we’re using 2.1.2. On OSX, we recommend
  installation via [Homebrew] since the version of [Ruby] packaged with OSX may
  be outdated.

* The `ffi` and `os` Ruby gems. These are used, e.g., for interfacing with Z3.
  Normally, these are installed by running `gem install ffi os`, and may
  require root privileges, depending on your configuration. With [Ruby][]
  installed via [Homebrew][] on OSX root privileges are not necessary. With the
  [Ruby][] that comes with OSX Yosemite, you may need root privileges. On
  Linux, you may need to install the `ffi` gem via the `rpm` or `apt` tools
  rather than the `gem` command.

* [Z3][]: a recent version of `libz3.{dylib,so,dll}`. If such a file exists in
  your `LIBRARY_PATH`, we will attempt to pick it up. If not, we will fall back
  on the corresponding file in the `xxx/` directory. Our prepackaged Z3 shared
  libraries are built for 64bit OSX/Linux, and their dependence on the
  platforms on which they were built (Yosemite, OpenSUSE) is unclear. The
  Windows `.dll` should be compatible with any Windows installation. If you do
  encounter problems involving `FFI` or `Z3`, you may try obtaining/building Z3
  on your system, and adding `libz3.{dylib,so,dll}` to your `LIBRARY_PATH`.

[Homebrew]: http://brew.sh
[Ruby]: https://www.ruby-lang.org
[Z3]: http://z3.codeplex.com

## Installation

No installation required! besides that which is required above, i.e., a recent
version of [Ruby] and the `ffi` and `os` gems.

## Usage

To try out the history checking algorithms, run, for example

    ./bin/logchecker.rb data/histories/simple/lifo-violation-dhk-2.log -a symbolic -v

To see the list of options, run

    ./bin/logchecker.rb --help
    
To generate benchmarking reports, run

    ./bin/report.rb

And that’s about it.
