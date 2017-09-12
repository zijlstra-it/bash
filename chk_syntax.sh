#!/bin/bash
################################################################################
# chk_syntax.sh - Check for syntax errors (PHP) and unresolved merge conflicts
#                 in any files under source control.  Run as part of our deploy
#                 script, failing the build if any problems are detected.
# Example:
#      $ ./chk_syntax.sh
################################################################################
usage() { echo "usage: $0 [-v] [-d start_dir]" >&2; exit 1; }
MP_CHECKER='./run_checks.sh'
verbose=0
dirfilter=''

if [ ! -x $MP_CHECKER ]; then
    echo "${0} requires ${MP_CHECKER}, which was not found or is not executable" >&2;
    exit 1
fi

OPTIND=1
while getopts 'd:v' opt; do
    case "$opt" in
        d)  dirfilter="${OPTARG/\.\//}" # ignore ./ in input, if present
            dopt="-d $dirfilter"
            ;;
        v)  verbose=1
            vflag='-v'
            ;;
        *)  usage
            ;;
    esac
done

set -m # enable job control

# Set up our fifos and get this party started
nowtime=$(date +%s)
errpipe="/tmp/chk_syntax_errfifo.$$.$nowtime"
errcountpipe="/tmp/chk_syntax_cntfifo.$$.$nowtime"
mkfifo $errpipe
mkfifo $errcountpipe
trap "rm -f $errpipe $errcountpipe" EXIT

# Create error listener and fork it
(
    errors=()
    while [ 1 ]; do
        if read line; then
            if [ "$line" == "chk_syntax_END_ERRORS" ]; then
                break
            fi
            errors+=("$line")
        fi
    done <$errpipe

    errcount=0
    for err in "${errors[@]}"; do
        if [[ "$err" = *'ERRNUM'* ]]; then
            ((++errcount))
            err="${err/>>>>ERRNUM<<<</$errcount}"
        fi
        echo "$err"
    done
    echo "$errcount" >$errcountpipe
) &

# Run the syntax checker, which gives us our error report via the named
# pipe (fifo) and pipe listener that is now running in the background.
# When the error report is complete, signal the listener to exit by echoing
# a string it will treat as a command rather than normal input (see above.)
# The checker exits with the number of failed checks (zero thus indicating
# success, non-zero a failure state.)
$MP_CHECKER -e $errpipe -c $errcountpipe $vflag $dopt
checkstat=$?
wait
exit $checkstat