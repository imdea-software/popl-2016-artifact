# (gnu)plot comparing coverage of the various algorithms

set terminal pdf
set output 'data/num-violations-covered.pdf'

set title "Number of Violations Covered"
set xlabel "algorithms and objects"
set ylabel "Violations"

# TODO this should be a histogram...

set key box opaque top left
set style data lines

set yrange [1:1000]
set tic scale 0

# set style line 1 lt rgb "#CCCCCC" lw 2
# set style line 2 lt rgb "#555555" lw 2

plot 'data/num-violations-covered.csv' using 1:0 title "Enumerate"   with lines lt 1, \
  'data/num-violations-covered.csv' using 2:0 title "Symbolic"    with lines lt 2, \
  'data/num-violations-covered.csv' using 3:0 title "Symbolic -r" with lines lt 3, \
  'data/num-violations-covered.csv' using 4:0 title "Saturate"    with lines lt 4, \
  'data/num-violations-covered.csv' using 5:0 title "Saturate -r" with lines lt 5, \
  'data/num-violations-covered.csv' using 6:0 title "Counting(4)" with lines lt 6, \
  'data/num-violations-covered.csv' using 7:0 title "Counting(2)" with lines lt 7, \
  'data/num-violations-covered.csv' using 8:0 title "Counting(0)" with lines lt 8
