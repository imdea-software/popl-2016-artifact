#!/usr/bin/env bash

caffeinate ./bin/report.rb \
  -s "examples/generated/my-sync-stack.*.log" \
  -a "enumerate -c" \
  -a "symbolic" -a "symbolic -r" \
  -a "saturate" -a "saturate -r" \
  -t 5 -t 25 -t 50 -t 75 -t 100 \
  -d steps-until-timeout,data/avg-steps-until-timeout.csv

gnuplot plots/avg-steps-until-timeout.plot

caffeinate ./bin/report.rb \
  -s "examples/generated/ScalObject-bkq-100-small-histories/*.log" \
  -s "examples/generated/ScalObject-???-1-100-small-histories/*.log" \
  -s "examples/generated/ScalObject-???-2-100-small-histories/*.log" \
  -a "enumerate -c" \
  -a "symbolic" -a "symbolic -r" \
  -a "saturate" -a "saturate -r" \
  -a "counting -b 4" -a "counting -b 2" -a "counting -b 0" \
  -t 5 \
  -d num-violations-covered,data/num-violations-covered.csv

gnuplot plots/num-violations-covered.plot
