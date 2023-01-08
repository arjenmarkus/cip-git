# cip-prepare.tcl --
#     Create a set of directories based on a template so that
#     several calculations can be run. The input files are adjusted
#     according to a given CSV file (if that option is indeed used)
#
#     Options:
#     -templatedir name     The name of the directorry that is to be used as
#                           a template for the input
#     -runs number          Number of runs to prepare (overwritten by the option -csvdata).
#                           required for the mode "random"
#     -groups number        Number of groups of calculations, for the "morris" mode (defaults to 1)
#     -csvdata name         Name of the CSV file that holds the values of parameters
#                           to be substituted. The keywords and the values should be
#                           separated by tabs
#                           For the modes random and morris two rows are used to indicate
#                           the range for the variables.
#     -input name           Name of the input file in which to substitute the values
#                           (any number of such files may be given)
#     -mode  mode           Mode of operation: table (default), morris or random
#     -config name          Name of a configuration file. This may contain the
#                           options (without the leading "-"). It is read first, then
#                           the options may override.
#

# substituteValues --
#     Substitute the actual values into the input file
#
# Arguments:
#     inputFile      Name of the template file to be handled
#     params         List of parameters
#
proc substituteValues {inputFile params} {
    set infile   [open $inputFile]
    set contents [read $infile]
    close $infile

    set outfile  [open $inputFile w]
    puts -nonewline $outfile [string map $params $contents]
    close $outfile
}

# substituteEachFile --
#     Substitute the actual values into each input file
#
# Arguments:
#     casedir        Name of the case directory
#     inputFiles     Names of the files to be handled
#     params         List of parameters
#
proc substituteEachFile {casedir inputFiles params} {

    foreach input $inputFiles {
        substituteValues [file join $casedir $input] $params
    }
}

# generateCSV --
#     Generate a new CSV file based on the mode "morris" or "random"
#
# Arguments:
#     mode           Mode to used
#     orgdata        Name of the original CSV file
#     csvdata        Name of the new CSV file
#
proc generateCSV {mode orgdata csvdata} {
    global runs
    global groups

    #
    # Open the respective CSV files
    #
    set infile [open $orgdata]
    gets $infile line
    set keywords [split $line \t]

    gets $infile line
    set first [split $line \t]

    gets $infile line
    set last [split $line \t]

    close $infile

    set outfile [open $csvdata w]
    puts $outfile [join $keywords \t]

    if { $mode eq "random" } {
        for {set run 0} {$run < $runs} {incr run} {
            set values {}
            foreach min $first max $last {
                set r [expr {$min + ($max-$min) * rand()}]
                lappend values $r
            }
            puts $outfile [join $values \t]
        }
    }

    if { $mode eq "morris" } {
        for {set group 0} {$group < $groups} {incr group} {
            set start {}
            if { $group == 0 } {
                set start $first
            } else {
                foreach min $first max $last {
                    set r [expr {$min + ($max-$min) * 0.99 * rand()}]
                    lappend start $r
                }
            }
            puts $outfile [join $start \t]

            set next $start

            set idx 0
            foreach value $start min $first max $last {
                set value [expr {$value + ($max-$min) * 0.01}]
                lset next $idx $value

                puts $outfile [join $next \t]

                incr idx
            }
        }
    }

    close $outfile
}

# main --
#     Main program:
#     - Interpret the arguments
#     - Copy the files from the template directory
#     - Make sure there is no file "nocomp.cip" in the copied directory
#     - Substitute the values based on the contents of the CSV file
#


set templatedir ""
set csvdata     ""
set runs        0
set groups      1
set mode        "table"
set config      ""
set inputFiles  {}

foreach {option value} $argv {
    switch -- $option {
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

foreach {option value} $argv {
    switch -- $option {
        "-templatedir" {
            set templatedir $value
        }
        "-csvdata" {
            set csvdata $value
        }
        "-runs" {
            set runs $value
        }
        "-groups" {
            set groups $value
        }
        "-config" {
            # Ignore - handled above
        }
        "-mode" {
            set mode $value
        }
        "-input" {
            lappend inputFiles $value
        }
        default {
            puts "Unknown option:  $option"
        }
    }
}

#
# Check the given values
#
if { $templatedir == "" } {
    puts "No template directory given - impossible to continue"
    set exit 1
} elseif { ![file exists $templatedir] || ![file isdirectory $templatedir] } {
    puts "Invalid name for the template directory - it does not exist or is not a directory: $templatedir"
    set exit 1
}
if { $csvdata != "" && ![file exists $csvdata] } {
    puts "Invalid name for the CSV file - it does not exist: $csvdata"
    set exit 1
}
if { $csvdata == "" } {
    if { $runs == "" } {
        puts "No number of runs given nor the name of a CSV file - impossible to continue"
        set exit 1
    } elseif { ![string is integer -strict $runs] } {
        puts "The number of runs should be an integer - given is \"$runs\""
        set exit 1
    }
}
if { $csvdata != "" } {
    if { [llength $inputFiles] == 0 } {
        puts "No name given for an input file where values are to be substituted - impossible to continue"
        set exit 1
    } else {
        foreach input $inputFiles {
            if { ![file exists [file join $templatedir $input]] } {
                puts "Input file does not exist in template directory: $input"
                set exit 1
            }
        }
    }
}

if { $mode ni {table morris random} } {
    puts "Unknown mode of operation: $mode - should be \"table\", \"random\" or \"morris\""
    set exit 1
}

if { $mode in {morris random} && (![string is integer $runs] || ![string is integer $groups]) } {
    puts "The number of runs or groups should be a positive integer"
    set exit 1
}

if { $exit } {
    puts "\nProgram stopped because of one or more errors"
    exit
}

#
# In the modes "morris" and "random", create a new CSV File
#
if { $mode in {morris random} } {
    set orgdata $csvdata
    set csvdata "generated.cip"

    generateCSV $mode $orgdata $csvdata
}

#
# Now:
#     - Create the various directories
#     - Substitute values
#
close [open [file join $templatedir "nocomp.cip"] w]

set count 0

if { $csvdata != "" } {
    set infile [open $csvdata]
    gets $infile line
    set keywords [split $line \t]

    set lineno 0

    while { [gets $infile line] > 0 } {
        set  values [split $line \t]
        incr lineno

        if { [llength $keywords] != [llength $values] } {
            puts "Number of values not equal to the number of keywords - line $lineno"
            puts "Please check!"
            exit
        }

        set params {}
        foreach keyword $keywords value $values {
            lappend params $keyword $value
        }

        while { [file exists "case_$lineno"] } {
            incr lineno
        }

        puts "Case directory: case_$lineno"
        file copy $templatedir "case_$lineno"
        incr count

        if { [file exists [file join "case_$lineno" "nocomp.cip"]] } {
            file delete [file join "case_$lineno" "nocomp.cip"]
        }

        substituteEachFile "case_$lineno" $inputFiles $params
    }
} else {
    for { set lineno 1 } { $lineno <= $runs } { incr lineno } {
        file copy $templatedir "case_$lineno"
    }
}

puts "Case directories created: in total $count cases"
