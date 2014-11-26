# (gnu)plot comparing scalability of the various algorithms

set terminal pdf
set output 'data/avg-steps-until-timeout.pdf'

set title "Average Steps Until Timeout"
set xlabel "Number of steps completed"
set ylabel "Timeout (s)"

set key box opaque top left
set style data lines

set grid y
set logscale y

set yrange [1:1000]
set tic scale 0
# unset xtics

# set style line 1 lt rgb "#CCCCCC" lw 2
# set style line 2 lt rgb "#555555" lw 2

plot 'data/avg-steps-until-timeout.csv' using 1:0 title "Enumerate"   with lines lt 1, \
  'data/avg-steps-until-timeout.csv' using 2:0 title "Symoblic"    with lines lt 2, \
  'data/avg-steps-until-timeout.csv' using 3:0 title "Symoblic -r" with lines lt 3, \
  'data/avg-steps-until-timeout.csv' using 4:0 title "Saturate"    with lines lt 4, \
  'data/avg-steps-until-timeout.csv' using 5:0 title "Saturate -r" with lines lt 5
