# (gnu)plot comparing coverage of the various algorithms
reset
set terminal pdf size 4, 2.5
set output 'data/violations-covered.pdf'
set datafile separator ","

# set title "Number of Violations Covered"
# set xlabel "algorithms and objects"
# set ylabel "Violations"

unset xtics

set grid y
set yrange [-1:]

set style data histogram
set style histogram clustered
set style fill pattern border

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

plot for [COL=2:12] 'data/violations-covered.csv' \
  using COL:xticlabels(1) ls COL-1 title columnheader
