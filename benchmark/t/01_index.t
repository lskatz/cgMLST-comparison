#!/usr/bin/env perl

use strict;
use warnings;
use lib './lib';
use File::Basename qw/basename dirname/;
use FindBin qw/$RealBin/;
use Data::Dumper;
use List::Util qw/shuffle/;
use File::Temp qw/tempdir/;
use Bio::SeqIO;

use Test::More tests => 1;

$ENV{PATH} = "$RealBin/../scripts:".$ENV{PATH};

my @genus = qw(Campy Listeria Salm);
my @dbName = qw(Campylobacter_jejuni Listeria_monocytogenes Salmonella_enterica);

my @concatFasta = qw(campy.cat.fasta  lmo.cat.fasta  salm.cat.fasta);
my @refsFasta = qw(campy.refs.fasta lmo.refs.fasta salm.refs.fasta);

local $0 = basename($0);
my $tempdir = tempdir("$0.XXXXXX", CLEANUP=>1,TMPDIR=>1);

# Get assemblies
my %asm;
my %asmFofn;
for my $g(@genus){
  my $asmDir = "/scicomp/groups/OID/NCEZID/DFWED/EDLB/projects/validation/mlstComparison/illumina/$g/validation/shovill.out";
  if(!-e $asmDir){
    BAIL_OUT("asmDir does not exist: $asmDir");
  }
  my $files = fastReadDir($asmDir);
  my @allAsm = map {"$asmDir/$_"} shuffle grep {!/\.init\.fasta$/} grep {/\.fasta$/} @$files;
  $asm{$g} = \@allAsm;

  # Full file of filenames
  my $fofn = "$tempdir/$g.asms.fofn";
  open(my $fh, '>', $fofn) or die "ERROR: could not write to $fofn: $!";
  for (@allAsm){
    print $fh join("\t", basename($_), $_)."\n";
  }
  close $fh;

  my $numFiles = 1;
  system("head -n $numFiles $fofn > $tempdir/$g.asms.$numFiles.fofn");
}

sub fastReadDir{
  my($dir) = @_;
  my @file;
  opendir(my $dh, $dir) || BAIL_OUT("Cannot open $dir: $!");
  while(my $file = readdir($dh)){
    push(@file, $file);
  }
  return \@file;
}
  
# Takes a set of assemblies and indexes them
sub colorIdIndex{
  my($fofn, $index) = @_;

  my $cmd = "colorid_bv build -b $index -s 30000000 -n 2 -k 39 -t 1 -r $fofn 2>&1";
  my $stdout = `$cmd`;
  my $exit_code = $? >> 8;
  if($exit_code > 0){
    note "colorid_bv exited with error:";
    note $stdout;
  }
  return $exit_code;
}

sub etokiIndex{
  my($chewie, $refs, $etoki) = @_;
  my $cmd = "EToKi.py MLSTdb -i $chewie -d $etoki -r $refs 2>&1";
  my $stdout = `$cmd`;
  my $exit_code = $? >> 8;
  if($exit_code > 0){
    note "EToKi.py MLSTdb exited with error:";
    note $stdout;
  }
  return $exit_code;
}

subtest 'indexOnce' => sub{
  for(my $i=0; $i<@genus; $i++){
    my $etokiIndex = "$tempdir/$genus[$i].etoki";
    my $etoki_exit_code = etokiIndex($concatFasta[$i], $refsFasta[$i], $etokiIndex);
    is($etoki_exit_code, 0, "Index with EToKi from $concatFasta[$i] and $refsFasta[$i]");

    my $colorIdIndex = "$tempdir/$genus[$i].bxi";
    my $colorid_exit_code = colorIdIndex("$tempdir/$genus[$i].asms.1.fofn", $colorIdIndex);
    is($colorid_exit_code, 0, "Index with ColorID on genus $genus[$i]");
  }
};


# TODO speed comparison




