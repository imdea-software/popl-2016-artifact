# POPL 2016 Artifact

This is the artifact for the accepted POPL 2016 submission *Abstract Data Type
Inference*.

## Instructions

The following steps ensure that the artifact can be run on any machine that
satisfy following simple requirements.

### Step 0: Requirements

To ensure uniform results across platforms, this artifact is run through a
custom [VirtualBox] virtual machine configured through [Vagrant]. The following
requirements must be installed:

* [VirtualBox], version 4.3.20 or greater
* [Vagrant], version 1.7.2 or greater

### Step 1: Clone this Git repository

This artifact is obtained simply by cloning this repository:

    git clone https://github.com/imdea-software/popl-2016-artifact.git

This should create the artifact’s root directory `popl-2016-artifact` in your
current working directory.

### Step 2: Fire up the virtual machine

First, start [Vagrant] in this project’s root directory (containing
`Vagrantfile`):

    vagrant up

This can take a few minutes the first time around, since it includes the
download of a virtual machine image. When this step finishes, our virtual
machine should be up and running — verify this with the `vagrant status`
command. Open a shell to the running virtual machine via ssh:

    vagrant ssh

and follow the instructions below. When finished, simply close the SSH
session, and halt, suspend, or destroy the virtual machine:

    vagrant destroy

### Step 3: Run the artifact

Once inside the virtual machine run the command:

    ./bin/pattern_reporter.rb

This invokes the algorithm developed in the submission to calculate the
minimal negative history (patterns) for several ADT implementations. The
console output first draws a dot `.` for each explored history, and a hash
symbol `#` for each history which corresponds to a new pattern. When the
history-lenght bound is reached, the list of found patterns is printed
to the console, followed by the list of first-order formulas corresponding
to each pattern. For example, this is the output for the first implementation:

````
Generating negative patterns for My Register
.
Length 1 histories:
..#.
Length 2 histories:
.....#.#........
Length 3 histories:
..#...............................................................
Length 4 histories:
..............................................................................................................................................................................................................................................................................................
[pattern-finder] found 4 patterns
[1:X] read => 1 (RO)  #
--
[1:1] write(1)            #
[2:2] read => empty (RO)    #
--
[1:2] read => 1 (RO)  #
[2:2] write(1)          #
--
[1:1] write(1)        #
[2:2] write(2)          #
[3:1] read => 1 (RO)      #
--
(exists x1 ::
  c(x1) && f(x1) == read && um(x1)
)
--
(exists x1, x2 ::
  c(x1) && f(x1) == write && !um(x1) && m(x1) == x1 && x1 < x2 &&
  c(x2) && f(x2) == read && !um(x2) && m(x2) == x2 &&
  (forall x :: m(x) == x1 ==> x == x1) &&
  (forall x :: m(x) == x2 ==> x == x2)
)
--
(exists x1, x2 ::
  c(x1) && f(x1) == read && !um(x1) && m(x1) == x2 && x1 < x2 &&
  c(x2) && f(x2) == write && !um(x2) && m(x2) == x2 &&
  (forall x :: m(x) == x2 ==> x == x1 || x == x2)
)
--
(exists x1, x2, x3 ::
  c(x1) && f(x1) == write && !um(x1) && m(x1) == x1 && x1 < x2 &&
  c(x2) && f(x2) == write && !um(x2) && m(x2) == x2 && x2 < x3 &&
  c(x3) && f(x3) == read && !um(x3) && m(x3) == x1 &&
  (forall x :: m(x) == x1 ==> x == x1 || x == x3) &&
  (forall x :: m(x) == x2 ==> x == x2)
)
````

### Step 4: Evaluate the artifact

This artifact can be evaluated by examining the console output of the
`./bin/pattern_reporter.rb` command. The patterns output on the console should
correspond to those reported in Section 9 of the submission. This is simple to
verify visually, since the the patterns reported in the submission were captured
directly from this console output.

## Contents

Files in this project are organized according to the following directory
structure.

* `bin/` contains the `pattern_reporter.rb` script for generating the empirical
data used in our submission.

* `lib/` contains the source code of our pattern-finding algorithm. All source
is written in [Ruby], using a foreign-function interface for invoking [Scal]’s
C++ data-structure implementations.

* `popl-2016-submission.pdf` is the corresponding POPL 2016 submission.

* `xxx/` contains prebuilt external shared-libraries.

[Ruby]: https://www.ruby-lang.org
[RubyInstaller]: http://rubyinstaller.org
[Homebrew]: http://brew.sh
[Cygwin]: https://www.cygwin.com
[libffi]: https://sourceware.org/libffi
[Z3]: http://z3.codeplex.com

[Vagrant]: https://www.vagrantup.com
[VirtualBox]: https://www.virtualbox.org

[Scal]: http://scal.cs.uni-salzburg.at
