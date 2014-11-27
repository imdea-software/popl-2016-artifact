# (gnu)plot comparing steps reached of various algorithms on various objects
reset
set terminal pdf size 4, 2.5
set output 'data/avg-steps-until-fixed-timeout.pdf'
set datafile separator ","

set title "Average Steps Until Fixed Timeout"
set xlabel "Object / Algorithm"
set ylabel "Number of steps completed"

set style data histogram
set style histogram clustered
set style fill pattern border

plot for [COL=3:13] 'data/avg-steps-until-fixed-timeout.csv' \
  using COL:2 lt -1 title columnheader(COL)
