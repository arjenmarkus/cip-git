# cip.tcl --
#     For the documentation, see cip.tex
#
#     This program checks its arguments and decides on the basis thereof what
#     needs to be done: report, clean up things, run the program in various
#     case directories.
#
#     TODO:
#     Stop when there are no more calculations to be done and nothing is
#     running anymore - two flags?
#

# reportStatus --
#     Report the status of the cases
#
# Arguments:
#     None
#
# Side effects:
#     Prints a concise status on the standard output
#
proc reportStatus {} {
    foreach dir [glob -types d *] {
        cd $dir
        if { ! [file exists "nocomp.cip"] } {
            puts "Directory: $dir"
            if { [file exists "started.cip"] } {
                puts "    Started: [clock format [file mtime started.cip]]"
            } else {
                puts "    No calculation started yet"
            }

            if { [file exists "done.cip"] } {
                puts "    Finished: [clock format [file mtime done.cip]]"
            } else {
                puts "    Calculation has not finished yet"
            }
        }
        cd ..
    }
}

# cleanDirectories --
#     Remove the CIP specific files
#
# Arguments:
#     None
#
# Side effects:
#     Remove the CIP specific files "started.cip", "output.cip", "done.cip"
#
proc cleanDirectories {} {
    puts "Cleaning up the directories for calculations ..."

    foreach dir [glob -types d *] {
        cd $dir
        if { ! [file exists "nocomp.cip"] } {
            file delete "started.cip"
            file delete "output.cip"
            file delete "done.cip"
            file delete "error.cip"
        }
        cd ..
    }

    puts "Done"
}

# showHelp --
#     Show a short help message
#
# Arguments:
#     None
#
proc showHelp {} {
    puts "Usage:
    cip \[options\] command-with-zero-or-more-arguments

    CIP runs the command (representing a computational program on the various
    subdirectories.

    The options include:
    -help         Show this message
    -clean        Remove the CIP files, so that calculations are started a-fresh
    -status       Print an overview of what calculations have been done
    -path <dir>   Add the given directory to the PATH environment variable
    -procs <N>    Set the number of processors to use (number of simultaneous runs)
    --            End of the options"
}

# determineNumberProcessors --
#     Determine the number of processors
#
# Arguments:
#     None
#
# Returns:
#     Number of processors detected
#
proc determineNumberProcessors {} {
    #
    # On Windows, the environment variable NUMBER_OF_PROCESSORS is the simplest way
    # On Linux, rely on /proc/cpuinfo
    # But we can simply try both
    #

    set number 1

    if { [info exists ::env(NUMBER_OF_PROCESSORS)] } {
        set number $::env(NUMBER_OF_PROCESSORS)
        if { ![string is integer -strict $number] } {
            set number 1
        }
    }

    catch {
        set infile [open "/proc/cpuinfo" r]
        set contents [read $infile]
        close $infile
        set number [regexp -all {processor[ \t]*:} $contents]
    }

    return $number
}

# handleCalculation --
#     Handle the progress of the calculation
#
# Arguments:
#     chan           Channel to the calculation process
#     outfile        File to write the output to
#     workdir        Directory in which the calculation is run
#
proc handleCalculation {chan outfile workdir} {
    global numberActive
    global nomoreCalcs

    puts "In handleCalculation -- $numberActive"
    set line [gets $chan]
    if { [eof $chan] } {
        set rc [catch {
            close $chan
        } msg]
        close $outfile

        set done [open [file join $workdir "done.cip"] w]
        close $done

        incr numberActive -1
        if { $rc == 0 } {
            puts "Calculation finished -- $numberActive"
        } else {
            puts "Calculation failed -- $numberActive - please check! Working directory: $workdir"
        }
    } else {
        puts $outfile $line
    }
}

# startNextCalculation --
#     Start the next calculation
#
# Arguments:
#     cmd            Command to run
#
proc startNextCalculation {cmd} {
    global maxActive
    global numberActive

    #
    # No more processes active than required
    #
    if { $numberActive >= $maxActive } {
        #puts "Wait for a process to finish"
        after 1000 [list startNextCalculation $cmd]
        return
    }

    set started 0

    #puts "Directories: [glob -types d *]"
    foreach dir [glob -types d *] {
        if { $dir == [file tail [info nameofexecutable]] } {
            continue
        }
        cd $dir
        if { ! [file exists "nocomp.cip"] } {
            if { ! [file exists "started.cip"] } {
                #
                # Create the file "started.cip" to signal this directory
                # is already being taken care of
                #
                puts "Calculation started in $dir"
                set error [catch {
                    set outfile [open "started.cip" {WRONLY CREAT EXCL}]
                    close $outfile
                } msg]
                if { ! $error } {
                    set error [catch {
                        set program [open "|$cmd 2>error.cip" r]
                        #puts "All okay - $program"
                        set output  [open "output.cip" w]
                        fconfigure $program -buffering line
                        fileevent $program readable [list handleCalculation $program $output $dir]
                        incr numberActive
                        set started 1
                    } msg]
                }
                if { $error } {
                    set errfile [open "error.cip" a]
                    puts "Error: $msg"
                    puts $errfile "$msg"
                    close $errfile
                }
            }
        }
        cd ..
        if { $started } {
            break
        }
    }

    if { $started } {
        after 1 [list startNextCalculation $cmd]
    } else {
        #puts "No more calculations to be started -- $numberActive"
        if { $numberActive <= 0 } {
            puts "All calculations finished"
            set ::forever 1
        } else {
            after 1000 [list startNextCalculation $cmd]
        }
    }
}

# main --
#     First part: simple tests
#     Second part: analyse the arguments and act on them
#
if {0} {
    showHelp
    puts "Number of processors: [determineNumberProcessors]"
    reportStatus
    #cleanDirectories

    exit
}

#
# Analyse the arguments and act on them
#
set number [determineNumberProcessors]

set number_args [llength $argv]

set index 0
set cmd ""

set path_sep $tcl_platform(pathSeparator)

while { $index < $number_args } {
    switch -glob -- [lindex $argv $index] {
    "-help" {
        showHelp
    }
    "-clean" {
        cleanDirectories
    }
    "-path" {
        incr index
        set newpath [file native [lindex $argv $index]]
        set env(PATH) "$newpath$path_sep$env(PATH)]"
    }
    "-procs" {
        incr index
        set number [lindex $argv $index]
        if { ! [string is integer -strict $number] || $number <= 0 } {
            puts "Number of processors must be an integer number larger than 0"
            exit
        }
    }
    "-run" {
        #
        # This argument is used internally only!
        #
        runProgram [lrange $argv 1 end]
        exit
    }
    "--" {
        incr index
        set cmd [lrange $argv $index end]
        break
    }
    "-*" {
        puts "Unknown option ignored: [lindex $argv $index]"
        incr index
    }
    default {
        set cmd [lrange $argv $index end]
        break
    }
    }
    incr index
}

set env(PATH) "[file native [pwd]]$path_sep.$path_sep$env(PATH)"

if { $cmd != "" } {
    set maxActive   $number
    set numberActive 0
    set nomoreCalcs  0

    puts "Running $number calculations in parallel"
    puts "Command: $cmd"
    puts "Calculations started"
    after 0 [list startNextCalculation $cmd]

    vwait forever

    puts "Done"
}


