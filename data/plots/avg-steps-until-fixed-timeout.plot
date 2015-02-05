# (gnu)plot comparing steps reached of various algorithms on various objects
reset
set terminal pdf size 4, 2.5
set output 'data/avg-steps-until-fixed-timeout.pdf'
set datafile separator ","

# set title "Average Steps Until Fixed Timeout"
# set xlabel "Object / Algorithm"
# set ylabel "Number of steps completed"

set style data histogram
set style histogram clustered
set style fill pattern border
set logscale y
set grid y
unset xtics
set yrange [10:]

set style line 1 lw 1 lc rgb "black"
set style line 2 lw 1 lc rgb "black"
set style line 3 lw 1 lc rgb "black"
set style line 4 lw 1 lc rgb "black"
set style line 5 lw 1 lc rgb "black"
set style line 6 lw 1 lc rgb "black"
set style line 7 lw 1 lc rgb "black"
set style line 8 lw 1 lc rgb "black"
set style line 9 lw 5 lc rgb "black"
set style line 10 lw 5 lc rgb "black"
set style line 11 lw 5 lc rgb "black"

plot for [COL=3:13] 'data/avg-steps-until-fixed-timeout.csv' \
  using COL:xticlabels(1) ls COL-2 title columnheader(COL)
