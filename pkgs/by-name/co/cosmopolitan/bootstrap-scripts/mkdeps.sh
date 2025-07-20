#!/usr/bin/env bash

# mkdeps.sh - Generate makefile dependencies using gcc -M
# A simplified bash version of the cosmopolitan mkdeps tool

VERSION="mkdeps.sh v1.0
A bash reimplementation using gcc -M"

MANUAL="Usage: $0 -r o// -o OUTPUT INPUT...

DESCRIPTION

  Generates header file dependencies for your makefile

  This script uses gcc -M to compute dependencies for each source
  file and formats them for use in makefiles.

FLAGS

  -h         show usage
  -o OUTPUT  set output path
  -g ROOT    set generated path [default: o/]
  -r ROOT    set build output path, e.g. o/\$(MODE)/
  -S PATH    isystem include path [default: libc/isystem/]
  -s         hermetically sealed mode [use -MM instead of -M]

ARGUMENTS

  OUTPUT     shall be makefile code
  INPUT      should be source files or @args.txt"

# Default values
genroot="o/"
buildroot=""
systempath=""
outpath=""
hermetic=0
inputs=()

# Parse command line arguments
while getopts "hso:g:r:S:" opt; do
    case $opt in
        h)
            echo "$VERSION"
            echo "$MANUAL"
            exit 0
            ;;
        o)
            outpath="$OPTARG"
            ;;
        g)
            genroot="$OPTARG"
            ;;
        r)
            buildroot="$OPTARG"
            ;;
        S)
            systempath="$OPTARG"
            ;;
        s)
            ((hermetic++))
            ;;
        *)
            echo "$MANUAL" >&2
            exit 1
            ;;
    esac
done

shift $((OPTIND-1))

# Validate arguments
if [ $# -eq 0 ]; then
    echo "Error: missing input argument" >&2
    exit 1
fi

if [ -z "$buildroot" ]; then
    echo "Error: need build output path (-r option)" >&2
    exit 1
fi

if [[ ! "$buildroot" =~ /$ ]]; then
    echo "Error: build output path must end with slash" >&2
    exit 1
fi

if [[ ! "$genroot" =~ /$ ]]; then
    echo "Error: generated output path must end with slash" >&2
    exit 1
fi

if [[ ! "$buildroot" =~ ^"$genroot" ]]; then
    echo "Error: build output path must start with generated output path" >&2
    exit 1
fi

# Collect input files
for arg in "$@"; do
    if [[ "$arg" =~ ^@ ]]; then
        # Handle @args.txt files
        argfile="${arg:1}"
        if [ -f "$argfile" ]; then
            while IFS= read -r line || [ -n "$line" ]; do
                [ -n "$line" ] && inputs+=("$line")
            done < "$argfile"
        else
            echo "Error: cannot read $argfile" >&2
            exit 1
        fi
    else
        inputs+=("$arg")
    fi
done

# Prepare output
if [ -n "$outpath" ]; then
    exec > "$outpath"
fi

# Function to get the compiler for a given file
get_compiler() {
    local file="$1"
    case "${file##*.}" in
        c) echo "gcc" ;;
        cc|cpp|C) echo "g++" ;;
        s|S) echo "gcc" ;;
        m) echo "gcc" ;;
        *) echo "gcc" ;;
    esac
}

# Function to process dependencies output from gcc -M
process_deps() {
    local srcfile="$1"
    local deps="$2"
    local objfile

    # Skip if source is in generated directory
    if [[ "$srcfile" =~ ^"$genroot" ]]; then
        return
    fi

    # Determine object file path
    objfile="${buildroot}${srcfile%.*}.o"

    # Process the dependencies
    # gcc -M output format: target.o: source.c header1.h header2.h \
    #                                  header3.h header4.h

    # First, normalize the output (join continued lines)
    deps=$(echo "$deps" | tr '\n' ' ' | sed 's/\\//g' | sed 's/  */ /g')

    # Extract the dependency list (everything after the first colon)
    deps="${deps#*:}"

    # Print in the expected format
    echo ""
    echo -n "$objfile:"

    local first=1
    for dep in $deps; do
        # Skip empty entries
        [ -z "$dep" ] && continue

        echo -n " \\"
        echo ""
        echo -n "	$dep"
    done
    echo ""
}

# Process each source file
for srcfile in "${inputs[@]}"; do
    # Skip if file doesn't exist
    if [ ! -f "$srcfile" ]; then
        echo "Error: cannot open $srcfile" >&2
        exit 1
    fi

    # Check if it's a source file that produces an object
    case "${srcfile##*.}" in
        c|cc|cpp|C|s|S|m|cu)
            ;;
        *)
            continue
            ;;
    esac

    # Get the appropriate compiler
    compiler=$(get_compiler "$srcfile")

    # Build gcc -M command
    gcc_cmd=("$compiler")

    # Use -MM for hermetic mode (exclude system headers)
    if [ "$hermetic" -gt 0 ]; then
        gcc_cmd+=("-MM")
    else
        gcc_cmd+=("-M")
    fi

    # Add system include path if specified
    if [ -n "$systempath" ]; then
        gcc_cmd+=("-isystem" "$systempath")
    fi

    # For assembly files, we might need special handling
    if [[ "${srcfile##*.}" =~ ^[sS]$ ]]; then
        # For assembly, we might need to use -x assembler-with-cpp
        gcc_cmd+=("-x" "assembler-with-cpp")
    fi

    # Add the source file
    gcc_cmd+=("$srcfile")

    # Run gcc -M and capture output
    if deps=$("${gcc_cmd[@]}" 2>/dev/null); then
        process_deps "$srcfile" "$deps"
    else
        # If gcc -M fails, just output the source file itself as a dependency
        objfile="${buildroot}${srcfile%.*}.o"
        if [[ ! "$srcfile" =~ ^"$genroot" ]]; then
            echo ""
            echo "$objfile: \\"
            echo "	$srcfile"
        fi
    fi
done

# Add final newline
echo ""
