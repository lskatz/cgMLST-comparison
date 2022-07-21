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

die "Usage: $0 chewiedir outfile.fasta refs.fasta" if(!@ARGV);
my($chewiedir, $outfile, $refs) = @ARGV;

$ENV{PATH} = "$RealBin/../scripts:".$ENV{PATH};

local $0 = basename($0);
my $tempdir = tempdir("$0.XXXXXX", CLEANUP=>1,TMPDIR=>1);

# Get chewie database
if(!-e $chewiedir){
  die("chewieDir does not exist: $chewiedir");
}

my $files = fastReadDir($chewiedir);
my @fasta = map {"$chewiedir/$_"} grep{!/\/short/} grep{/\.fasta$/} @$files;

my %seen; # keep track of which refs we have seen
open(my $outFh, ">", $outfile) or die "ERROR: could not write to $outfile: $!";
open(my $outFhRef, ">", $refs) or die "ERROR could not write to $refs: $!";
for my $fasta(@fasta){
  my $inseq = Bio::SeqIO->new(-file=>$fasta);
  while(my $seq = $inseq->next_seq){
    my $id = $seq->id;
    $id =~ s/Pasteur_|INNUENDO_//;

    # Don't accept more than one underscore in the defline
    my $numUnderscores = () = $id=~/_/g;
    next if($numUnderscores > 1);
    # Don't accept "new" alleles
    next if($id =~ /\*/);

    my($locus, $allele) = split(/_/, $id);
    if(!$seen{$locus}++){
      print $outFhRef ">$id\n".$seq->seq."\n";
    }

    print $outFh ">$id\n".$seq->seq."\n";
  }
}
close $outFh;
close $outFhRef;


sub fastReadDir{
  my($dir) = @_;
  my @file;
  opendir(my $dh, $dir) || die("Cannot open $dir: $!");
  while(my $file = readdir($dh)){
    push(@file, $file);
  }
  return \@file;
}

