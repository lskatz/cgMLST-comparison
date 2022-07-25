#!/bin/bash

set -e
set -u

RealBin=$(dirname $(realpath $0))
tmpdir=$(mktemp --directory --tmpdir=. benchmark.XXXXXX)
trap ' { rm -rf $tmpdir; } ' EXIT

# Hyperfine parameters
# Locally, just run one time per test but in the cloud, boost it to ten
num_runs=5 # 5
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

#tempdir=

# Version information
colorid_bv --version
singularity exec $chewie_cif chewie -v
EToKi.py configure

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

# compare allele calling, single threaded, single input
hyperfine $hyperfine_opts --export-json=$reportsDir/singleThread_singleQuery.json \
 -n "ColorId" "colorid_bv build -b $campy_colorid_bxi -s 30000000 -n 2 -k 39 -t 1 -r $campy_colorid_fofn 2>&1 && echo 'Created $campy_colorid_bxi' && colorid_bv search -ms -b $campy_colorid_bxi -q $campy_chewiedb/*.fasta 2>&1 > $TMPDIR/alleles.colorid.txt " \
 -n "EToKi"   "EToKi.py MLSType -k sample -i $campy_asm -r $campy_etokirefs -d $campy_etokidb -o $campy_etoki_alleles 2>&1" \
 -n "Chewie"  "singularity exec -B $TMPDIR:$TMPDIR -B $PWD:$PWD -B $chewie_input:/input -B $campy_chewiedb:/schema $chewie_cif chewBBACA.py AlleleCall -i /input --schema-directory /schema -o $TMPDIR/chewie.out --fr --cpu 1 2>&1" 

 #-n "ColorId" "colorid_bv build -b $campy_colorid_bxi -s 30000000 -n 2 -k 39 -t 1 -r $campy_colorid_fofn 2>&1 && echo 'Created $campy_colorid_bxi' && colorid_bv search -ms -b $campy_colorid_bxi -q $campy_chewiedb/*.fasta 2>&1 > $TMPDIR/alleles.colorid.txt" \

# example chewie results
#------------------------------------------------------------------------------------
#Genome                                EXC    INF    LNF   PLOT   NIPH    ALM    ASM
#------------------------------------------------------------------------------------
#SRR11401885_1.shovillSpades.fasta    1156     0    1635     1      2      0      0
#------------------------------------------------------------------------------------

