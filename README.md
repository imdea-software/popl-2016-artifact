Monitoring Refinement via Symbolic Reasoning
============================================

This project aims to develop efficient monitoring algorithms for concurrent
data structures, e.g., locks, semaphores, atomic registers, stacks, queues.

Contents
--------

- `bin/` contains the executables for generating history logs (`loggenerator.rb`), checking history logs (`logchecker.rb`), and for generating reports (`report.rb`).

- `examples/generated` contains many history logs generated from actual executions.

- `examples/simple` contains a few hand-crafted histories.

- `lib/` contains the source code of the checking algorithms.

- `reports/` contains some previously-generated reports benchmarking the performance of each algorithm.

Usage
-----

To try out the history checking algorithms, run, for example

    ./bin/logchecker.rb examples/simple/lifo-violation-dhk-2.log -a symbolic -v

To see the list of options, run

    ./bin/logchecker.rb --help
    
To generate benchmarking reports, run

    ./bin/report.rb

And that's about it.
