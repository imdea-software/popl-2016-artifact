#!/usr/bin/env bash

caffeinate ./bin/report.rb \
  -s "examples/generated/ScalObject-msq-big/*.log" \
  -a "enumerate -c" \
  -a "counting -b 4" -a "counting -b 4 -r" \
  -a "symbolic" -a "symbolic -r" \
  -a "saturate" -a "saturate -r" \
  -t 5 -t 25 -t 50 -t 75 -t 100 \
  -d steps-until-timeout,data/avg-steps-until-timeout.csv

gnuplot plots/avg-steps-until-timeout.plot


# TODO create better benchmarks
# Scalobject-bkq-small is too hard, and contains too few errors
# bkq-almost-sequential is too obviously errorneous -- even counting-0 gets it

# TODO add more objects...
# -s "examples/generated/ScalObject-xxx-small/*.log"
# -s "examples/generated/ScalObject-yyy-small/*.log"


caffeinate ./bin/report.rb \
  -s "examples/generated/ScalObject-bkq-small/*.log" \
  -a "enumerate -c" \
  -a "counting -b 4" -a "counting -b 4 -r" \
  -a "counting -b 2" -a "counting -b 2 -r" \
  -a "counting -b 0" -a "counting -b 0 -r" \
  -a "symbolic" -a "symbolic -r" \
  -a "saturate" -a "saturate -r" \
  -t 10 \
  -d violations-covered,data/violations-covered.csv

gnuplot plots/violations-covered.plot


caffeinate ./bin/report.rb \
  -s "examples/generated/ScalObject-msq-big/*.log" \
  -a "enumerate -c" \
  -a "counting -b 4" -a "counting -b 4 -r" \
  -a "counting -b 2" -a "counting -b 2 -r" \
  -a "counting -b 0" -a "counting -b 0 -r" \
  -a "symbolic" -a "symbolic -r" \
  -a "saturate" -a "saturate -r" \
  -t 20 \
  -d steps-until-timeout,data/avg-steps-until-fixed-timeout.csv

gnuplot plots/avg-steps-until-fixed-timeout.plot
