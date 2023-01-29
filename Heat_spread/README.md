### Simplified simulation of linear heat spread in time, using several parallel threads (works only on linux). 

C programm gets number of threads, number of segments and observation time in arguments of main() and writes sequence 
of system thermal states to the output file. Using gettimeofday function we also print how long it works and plot time 
to number of segments in python (hear_threads.ipynb) for 1-16 number of threads to see if parallelizing works well.
