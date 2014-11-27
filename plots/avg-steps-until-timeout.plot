# (gnu)plot comparing scalability of the various algorithms
reset
set terminal pdf size 3, 2
set output 'data/avg-steps-until-timeout.pdf'
set datafile separator ","
set termoption dash

set title "Average Steps Until Timeout"
set xlabel "Number of steps completed"
set ylabel "Timeout, in seconds"

set key out horiz center bottom

set grid y
set grid x
set yrange [0:100]
set xrange [10:5000]
set ytics 0, 25, 100
set logscale x

set style line 1 lt 3 lw 3 lc rgb "black" pt 4 pi -1 ps 1.2
set style line 2 lt 3 lw 3 lc rgb "black" pt 5 pi -1 ps 1.2
set style line 3 lt 4 lw 3 lc rgb "black" pt 6 pi -1 ps 1.2
set style line 4 lt 4 lw 3 lc rgb "black" pt 7 pi -1 ps 1.2
set style line 5 lt 5 lw 3 lc rgb "black" pt 8 pi -1 ps 1.2
set style line 6 lt 5 lw 3 lc rgb "black" pt 9 pi -1 ps 1.2
set pointintervalbox 3

plot for [COL=3:7] 'data/avg-steps-until-timeout.csv' \
   using COL:2 with linespoints ls COL-1 title columnheader(COL)