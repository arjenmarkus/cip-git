# cip-diff.tcl --
#     Make a report on the differences between calculation results.
#     This is part of the senstivity analysis according to the method by Morris
#
#     It uses the file "generated.cip" to examine the output files and compare
#     them to the starting situation(s)
#
#     Options:
#     -output         Name of the CSV output files to be examined
#     -config         Name of a configuration file containing the output information
#                     (may be combined with the configuration for cip-prepare)
#

# reportDifference --
#     Determine the differences between the calucation that used the starting values
#     and a new one.
#
# Arguments:
#     report           Channel to report the findings to
#     parameterNames   Names of the parameters
#     startFile        Name of the CSV file containing the results of the start calculation
#     nextFile         Name of the CSV file containing the results of a subsequent calculation
#     startParameters  List of parameters used for the start calculation
#     nextParameters  List of parameters used for the subsequent calculation
#
# Note:
#     The differences are written to a specific file (indicated by the report argument)
#     and consist of:
#     - average difference
#     - average absolute difference
#     - maximum absolute difference
#     per column found in the  output CSV files
#
proc reportDifference {report parameterNames startFile nextFile startParameters nextParameters} {

    #
    # Open the files and skip the header line
    #
    set inStart [open $startFile]
    set inNext  [open $nextFile]

    gets $inStart line
    gets $inNext  line

    set columns [llength $line]

    #
    # Prepare the calculation
    #
    set meanDiff    [lrepeat $columns 0.0]
    set meanAbsDiff [lrepeat $columns 0.0]
    set maxAbsDiff  [lrepeat $columns 0.0]

    set count 0

    while { [gets $inStart lineStart] > 0 } {
        incr count
        gets $inNext lineNext

        set column 0
        foreach valueStart $lineStart valueNext $lineNext mean $meanDiff meanAbs $meanAbsDiff maxAbs $maxAbsDiff {
            set diff [expr {$valueStart - $valueNext}]

            set mean    [lindex $meanDiff $column]
            set meanAbs [lindex $meanAbsDiff $column]
            set maxAbs  [lindex $maxAbsDiff $column]

            set mean    [expr {$mean + $diff}]
            set meanAbs [expr {$meanAbs + abs($diff)}]
            set maxAbs  [expr {max($maxAbs, abs($diff))}]

            lset meanDiff    $column $mean
            lset meanAbsDiff $column $meanAbs
            lset maxAbsDiff  $column $maxAbs

            incr column
        }
    }

    close $inStart
    close $inNext

    #
    # Scale the differences
    #
    set paramIdx 0
    foreach valueStart $startParameters valueNext $nextParameters {
        incr paramIdx
        if { $valueStart != $valueNext } {
            set paramDiff [expr {$valueNext - $valueStart}]
            break
        }
    }

    set column 0
    foreach mean $meanDiff meanAbs $meanAbsDiff maxAbs $maxAbsDiff {
        set mean    [expr {$mean / $count / $paramDiff}]
        set meanAbs [expr {$meanAbs / $count / $paramDiff}]
        set maxAbs  [expr {$maxAbs / $paramDiff}]

        lset meanDiff    $column $mean
        lset meanAbsDiff $column $meanAbs
        lset maxAbsDiff  $column $maxAbs

        incr column
    }

    #
    # Write the report
    #
    set paramName [lindex $parameterNames [expr {$paramIdx-1}]]

    puts $report "$paramIdx\t$paramName\t[join $meanDiff \t]"
    puts $report "$paramIdx\t$paramName\t[join $meanAbsDiff \t]"
    puts $report "$paramIdx\t$paramName\t[join $maxAbsDiff \t]"
}

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
# Now determine the differences:
# - Check that all calculations have been completed
# - Determine the differences per pair
#
set infile [open "generated.cip"]
gets $infile line

set parameterNames   [split $line \t]
set numberParameters [llength $parameterNames]

set error  0
set lineno 0
while { [gets $infile line] > 0 } {
    incr lineno
    set dirname "case_$lineno"

    if { ![file exists [file join $dirname "done.cip"]] } {
        puts "Case in directory $dirname not done yet"
        set error 1
    }
}

close $infile

if { $error } {
    puts "\nPlease wait until all calculations have been done"
    exit
}

set report [open "report-morris.out" w]

set resultFile [open [file join "case_1" $output]]
gets $resultFile columnNames
close $resultFile

puts $report "No.\tParameter\t[join $columnNames]"

set groups [expr {$lineno / ($numberParameters + 1)}]

set infile [open "generated.cip"]
gets $infile line

set lineno 0
for {set group 0} {$group < $groups} {incr group} {
    incr lineno
    gets $infile line
    set startParameters [split $line  \t]

    for {set param 0} {$param < $numberParameters} {incr param} {
        gets $infile line
        set nextParameters [split $line  \t]

        set startFile [file join case_$lineno $output]
        set nextFile  [file join case_[expr {$lineno + 1}] $output]

        #puts $report "$startFile -- $nextFile"

        reportDifference $report $parameterNames $startFile $nextFile $startParameters $nextParameters

        set startParameters $nextParameters

        incr lineno
    }
}

close $report

# TODO: overall examination!
