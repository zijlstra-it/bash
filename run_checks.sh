#!/bin/bash
set -m # enable job control
maxforks=$(($(getconf _NPROCESSORS_ONLN) * 2))  # no "nproc" on macOS and this works on Linux too
usage() { echo "usage: $0 -e error_fifo -c errcount_fifo [-v] [-d start_dir]" >&2; exit 1; }

conflicts_check() {
    if [ -n "$1" ] && [ -n "$2" ]; then
        local srcfile="$1"
        local pipe="$2"

        if [ ! -p "$pipe" ] ; then
            echo "conflicts_check: $pipe is not initialised; exiting" >&2
            exit 1
        fi

        if grep -q '<<<<<<<  *[a-zA-Z0-9]' "$srcfile" 2>/dev/null; then
            local conflict=$(nl -nrn -ba -s'  ' "$srcfile" | pr -e4 -t -o6 | sed -n '/<<<<<<</,/>>>>>>>/{s/ /\\ /g;p;}' | head -5)
            (
                echo "\ \ [>>>>ERRNUM<<<<] *** Found unresolved merge conflict in ${srcfile} ***"
                echo "\ \ \ \ \ \ Showing first 5 lines:"
                echo "$conflict"
                echo
            ) >"$pipe"
        fi
    else
        echo "$FUNCNAME requires 2 arguments" >&2
        exit 1
    fi
}

syntax_check() {
    if [ -n "$1" ] && [ -n "$2" ]; then
        local phpfile="$1"
        local pipe="$2"

        # check for conflicts
        conflicts_check "$phpfile" "$pipe"

        # check for syntax errors
        local sc_output=$(php -l "$phpfile" 2>&1 >/dev/null)
        local rc=$?
        if [ $rc -ne 0 ] ; then     # check result of syntax check
            if [[ ! -p "$pipe" ]] ; then
                echo "syntax_check: $pipe is not initialised; exiting"
                exit 1
            fi
            (
                echo "\ \ [>>>>ERRNUM<<<<] *** Found syntax error in ${phpfile} ***"
                echo "\ \ \ \ \ \ *** $sc_output ***"
                echo
            ) >"$pipe"
        fi
    else
        echo "$FUNCNAME requires 2 arguments" >&2
        exit 1
    fi
}

verbose=0
dirfilter=''
OPTIND=1
while getopts 'd:ve:c:' opt; do
    case "$opt" in
        e)  errpipe="$OPTARG"
            ;;
        c)  errcountpipe="$OPTARG"
            ;;
        d)  dirfilter="${OPTARG/\.\//}"
            ;;
        v)  verbose=1
            ;;
        *)  usage
            ;;
    esac
done

if [ ! -p "$errpipe" ] || [ ! -p "$errcountpipe" ]; then
    usage
fi

echo "Detecting file types..."

searched=0
phpfiles=()
nonphpfiles=()

src_files=($(git ls-files | sed -e '/\.svg$/d;/\.gif$/d;/\.png$/d;/\.jpe*g$/d;/_ide_helper.php/d' \
                                -e "/$(basename $0)/d" | grep "$dirfilter"))
for src_file in "${src_files[@]}"; do
    if [ "${src_file: -4}" == '.php' ]; then
        phpfiles+=("${src_file}")
    else
        nonphpfiles+=("${src_file}")
    fi
done
echo "Checking for syntax errors and unresolved merge conflicts..."

j=0
for srcfile in "${nonphpfiles[@]}"; do
    if [ "$verbose" -eq 1 ]; then
        echo "Checking ${srcfile}..."
    fi
    conflicts_check "$srcfile" "$errpipe" &
    ((++searched))
    ((++j))
    if [ $(($j % ($maxforks * 3))) -eq 0 ]; then
        wait
    fi
done

k=0
for phpfile in "${phpfiles[@]}"; do
    if [ "$verbose" -eq 1 ]; then
        echo "Checking ${phpfile}..."
    fi
    syntax_check "$phpfile" "$errpipe" &
    ((++searched))
    ((++k))
    if [ $(($k % $maxforks)) -eq 0 ]; then
        wait
    fi
done

wait    # wait for any remaining syntax checks to complete
# signal end of input to fifo listener so it can compile error report and clean up
echo 'chk_syntax_END_ERRORS' >$errpipe
echo

errcount=0
while [ 1 ]; do
    if read line; then
        errcount=$line
        break
    fi
done <$errcountpipe

echo "Checked $searched files and found $errcount errors"
wait    # make sure pipe listeners have finished before bailing

exit $errcount