# cip-statistics.tcl --
#     Determine simple statistical parameters (as a timeseries) for the
#     cases that were run

# main --
#     Run the program
#

set output ""
set config ""

foreach {option value} $argv {
    switch -- $option {
        "-output" {
             set output $value
        }
        "-config" {
             set config $value
        }
        default {
             # Ignore
        }
    }
}

if { $config ne "" } {
    source $config
}

set exit 0

if { $output eq "" } {
    puts "no name given for the files that hold the result in CSV form"
    set exit 1
}

if { $exit } {
    puts "\nThe program stopped because the errors in the input"
    exit
}

#
# Now determine the mean and standard deviation over the various runs
#
set avgfile [open "average.cip" w]
set stdfile [open "stddev.cip" w]

set columnNames {}
set average     {}
set stddev      {}

set count       0

foreach dir [glob -type d *] {
    cd $dir

    if { ! [file exists $output] || [file exists "nocomp.cip"]  } {
        puts "Skipping $dir ..."
    } else {
        puts "Reading result from $dir ..."

        if { [llength $columnNames] == 0 } {
            set resultFile [open $output]
            gets $resultFile columnNames

            while { [gets $resultFile line] >= 0 } {
                set avg {}
                foreach v $line {
                    lappend avg [expr {$v}]
                }
                lappend average $avg

                set squared {}
                foreach v $line {
                    lappend squared [expr {$v**2}]
                }

                lappend stddev $squared
            }

            close $resultFile

        } else {

            set resultFile [open $output]
            gets $resultFile dummy

            set lineno 0
            while { [gets $resultFile line] >= 0 } {
                set avg [lindex $average $lineno]

                set column 0
                foreach v $line avg [lindex $average $lineno] std [lindex $stddev $lineno] {

                    lset average $lineno $column [expr {$avg + $v}]
                    lset stddev  $lineno $column [expr {$std + $v**2}]
                    incr column
                }

                incr lineno
            }

            close $resultFile
        }

        incr count
    }

    #
    # Always return to the parent directory
    #
    cd ..
}

# Now calculate the average and the standard deviation

set lineno 0
foreach avgRow $average stdRow $stddev {
    set column 0

    foreach avg $avgRow std $stdRow {
        set avg [expr {$avg / $count}]
        set std [expr {sqrt( max(0.0, ($std - $count * $avg ** 2) ) / ($count - 1) )}]

        lset average $lineno $column $avg
        lset stddev  $lineno $column $std

        incr column
    }

    incr lineno
}

puts "Writing results ..."
puts $avgfile $columnNames
puts $stdfile $columnNames

foreach avg $average std $stddev {
    puts $avgfile $avg
    puts $stdfile $std
}

puts "Done"
