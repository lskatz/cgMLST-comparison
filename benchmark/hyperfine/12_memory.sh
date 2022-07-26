#!/bin/bash

set -e
set -u

RealBin=$(dirname $(realpath $0))
tmpdir=$(mktemp --directory --tmpdir=. benchmark.XXXXXX)
trap ' { rm -rf $tmpdir; } ' EXIT

# Hyperfine parameters
# Locally, just run one time per test but in the cloud, boost it to ten
num_runs=50 # 5
warmup=2   # 2
if [[ ! -z ${CI+""} ]]; then
  # if on continuous integration
  num_runs=10
  warmup=2
fi
echo "Number of runs in hyperfine: $num_runs";

chewie_cif="/scicomp/groups/OID/NCEZID/DFWED/EDLB/projects/validation/mlstComparison/bin/chewbbaca.cif"
campy_chewiedb="/scicomp/groups/OID/NCEZID/DFWED/EDLB/projects/validation/mlstComparison/MLST.db/Campylobacter_jejuni.chewbbaca"
campy_etokidb="$RealBin/etoki/Campy.etoki"
campy_etokirefs="$RealBin/etoki/campy.refs.fasta"
campy_asm_dir="/scicomp/groups/OID/NCEZID/DFWED/EDLB/projects/validation/mlstComparison/illumina/Campy/validation/shovill.out"

# Version information
#colorid_bv --version
#singularity exec $chewie_cif chewie -v
#EToKi.py configure

# Hyperfine options
# Output directory for markdown files
reportsDir="$RealBin/markdown"
mkdir -pv $reportsDir
# Other options, generic for all commands
hyperfine_opts="--warmup $warmup --shell $SHELL --runs $num_runs"

# Set up some variables for the exact commands in hyperfine
campy_asm=`ls -Af1 $campy_asm_dir | shuf | head -n 1`;
campy_asm="$campy_asm_dir/$campy_asm"
echo "Assembly will be $campy_asm";
chewie_input="$tmpdir/chewie.in"
mkdir -pv $chewie_input
cp -v $campy_asm $chewie_input/
campy_etoki_alleles="$tmpdir/etoki.alleles.fasta"
campy_colorid_bxi="$tmpdir/$(basename $campy_asm .fasta).bxi"
campy_colorid_fofn="$tmpdir/samples.fofn"
echo -e "$(basename $campy_asm .fasta)\t$campy_asm" > $campy_colorid_fofn

# Checks the maximum memory of a command
# Replaces 'RUN' with the run number to help make unique files
function maxMemory(){
  cmd=$1
  out=$2
  name=$(echo "$cmd" | sed 's/ .*//');
  mkdir -pv $tmpdir/maxMemory/$name

  for i in `seq 1 $num_runs`; do
    # Replace the word RUN with $i
    thiscmd=$(echo "$cmd" | sed "s/RUN/$i/g")
    # run the command with time and pipe it into qsub
    echo "/usr/bin/time sh -c '$thiscmd' > /dev/null" | \
      qsub -N maxMem_$name -o $tmpdir/maxMemory/$name -j y -cwd -V
  done
  # When those jobs are done, grep for the maxmemory
  echo "
    head -n 100000 $tmpdir/maxMemory/$name/*; exit
    grep -h -o -E '[0-9]+maxresident' $tmpdir/maxMemory/$name/* | \
    sed 's/maxresident//'
  " | qsub -N combineMemory -hold_jid maxMemory_$name -o $out -j y -cwd -V
}

# NOTE: 'RUN' will be replaced with a run integer in any command
maxMemory "hostname" markdown/test.txt
maxMemory "colorid_bv build -b $campy_colorid_bxi.RUN -s 30000000 -n 2 -k 39 -t 1 -r $campy_colorid_fofn && colorid_bv search -ms -b $campy_colorid_bxi.RUN -q $campy_chewiedb/*.fasta" "markdown/colorid.txt"
maxMemory "EToKi.py MLSType -k sample -i $campy_asm -r $campy_etokirefs -d $campy_etokidb -o $campy_etoki_alleles.RUN" "markdown/etoki.txt"
maxMemory "chewie --help; cp -r $campy_chewiedb $tmpdir/$(basename $campy_chewiedb).RUN && singularity exec -B $TMPDIR:$TMPDIR -B $PWD:$PWD -B $chewie_input:/input -B $tmpdir/$(basename $campy_chewiedb).RUN:/schema $chewie_cif chewBBACA.py AlleleCall -i /input --schema-directory /schema -o $TMPDIR/chewie.out.RUN --fr --cpu 1" "markdown/chewie.txt"

# Make the program wait before exiting
echo 'echo -n' | qsub -sync y -N wait_to_exit -o /dev/null -j y -hold_jid combineMemory

