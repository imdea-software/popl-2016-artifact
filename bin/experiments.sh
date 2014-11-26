#!/usr/bin/env bash

caffeinate ./bin/report.rb -s "examples/generated/my-sync-stack.*.log" \
  -d steps-until-timeout,data/avg-steps-until-timeout.csv \
  -a "enumerate -c" -a "symbolic" -a "symbolic -r" -a "saturate" -a "saturate -r" \
  -t 5 -t 25 -t 50 -t 75 -t 100

gnuplot plots/avg-steps-until-timeout.plot
