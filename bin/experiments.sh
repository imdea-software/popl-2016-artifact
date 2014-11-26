#!/usr/bin/env bash

caffeinate ./bin/report.rb -s "examples/generated/my-sync-stack.*.log" \
  -d steps-until-timeout,data/avg-steps-until-timeout.csv \
  -a "enumerate -c" -a "symbolic" -a "symbolic -r" -a "saturate" -a "saturate -r" \
  -t 1 -t 2 -t 3 -t 4 -t 5
