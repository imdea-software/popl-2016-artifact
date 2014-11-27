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

plot for [COL=2:12] 'data/violations-covered.csv' \
  using COL:xticlabels(1) lt -1 title columnheader
