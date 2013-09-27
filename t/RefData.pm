package RefData;

use strict;
use warnings;

## defining the data
our $nodes = {
   1 => {
		ancestor => 1,
		rank => "no rank",
		taxid => 1,
		sciname => "root"
     	},
   2 => {
		ancestor => 1,
		rank => "superkingdom",
		taxid => 2,
		sciname => "superkingdom"
	},
   3 => {
		ancestor => 1,
		rank => "genus",
		taxid => 3,
		sciname => "genus01"
	},
   4 => {
		ancestor => 1,
		rank => "phylum",
		taxid => 4,
		sciname => "phylum"
	},
   5 => {
		ancestor => 3,
		rank => "species",
		taxid => 5,
		sciname => "species 01"
	},
   6 => {
		ancestor => 3,
		rank => "species",
		taxid => 6,
		sciname => "species 02"
	},
   7 => {
		ancestor => 4,
		rank => "family",
		taxid => 7,
		sciname => "family01"
	},
   8 => {
		ancestor => 4,
		rank => "class",
		taxid => 8,
		sciname => "class"
	},
   9 => {
		ancestor => 7,
		rank => "genus",
		taxid => 9,
		sciname => "genus02"
	},
  10 => {
		ancestor => 7,
		rank => "genus",
		taxid => 10,
		sciname => "genus03"
	},
  11 => {
		ancestor => 8,
		rank => "family",
		taxid => 11,
		sciname => "family02"
	},
  12 => {
		ancestor => 8,
		rank => "family",
		taxid => 12,
		sciname => "family03"
	},
  13 => {
		ancestor => 10,
		rank => "species",
		taxid => 13,
		sciname => "species 03"
	},				
  14 => {
		ancestor => 10,
		rank => "species",
		taxid => 14,
		sciname => "species 04"
	},				
  15 => {
		ancestor => 10,
		rank => "species",
		taxid => 15,
		sciname => "species 05"
	},				
  16 => {
		ancestor => 12,
		rank => "genus",
		taxid => 16,
		sciname => "genus04"
	},				
  17 => {
		ancestor => 12,
		rank => "genus",
		taxid => 17,
		sciname => "genus05"
	},				
  18 => {
		ancestor => 12,
		rank => "genus",
		taxid => 18,
		sciname => "genus06"
	},				
  19 => {
		ancestor => 16,
		rank => "species",
		taxid => 19,
		sciname => "species 06"
	},				
  20 => {
		ancestor => 16,
		rank => "species",
		taxid => 20,
		sciname => "species 07"
	},				
  21 => {
		ancestor => 18,
		rank => "species",
		taxid => 21,
		sciname => "species 08"
	},				
  22 => {
		ancestor => 18,
		rank => "species",
		taxid => 22,
		sciname => "species 09"
	},				
  23 => {
		ancestor => 18,
		rank => "species",
		taxid => 23,
		sciname => "species 10"
	}				
};

our $lineage = {
    1 => [
	$nodes->{1}
	],
    2 => [
	$nodes->{2},
	$nodes->{1}
	],
    3 => [
	$nodes->{3},
	$nodes->{1}
	],
    4 => [
	$nodes->{4},
	$nodes->{1}
	],
    5 => [
	$nodes->{5},
	$nodes->{3},
	$nodes->{1}
	],
    6 => [
	$nodes->{6},
	$nodes->{3},
	$nodes->{1}
	],
    7 => [
	$nodes->{7},
	$nodes->{4},
	$nodes->{1}
	],
    8 => [
	$nodes->{8},
	$nodes->{4},
	$nodes->{1}
	],
    9 => [
	$nodes->{9},
	$nodes->{7},
	$nodes->{4},
	$nodes->{1}
	],
    10 => [
	$nodes->{10},
	$nodes->{7},
	$nodes->{4},
	$nodes->{1}
	],
    11 => [
	$nodes->{11},
	$nodes->{8},
	$nodes->{4},
	$nodes->{1}
	],
    12 => [
	$nodes->{12},
	$nodes->{8},
	$nodes->{4},
	$nodes->{1}
	],
    13 => [
	$nodes->{13},
	$nodes->{10},
	$nodes->{7},
	$nodes->{4},
	$nodes->{1}
	],
    14 => [
	$nodes->{14},
	$nodes->{10},
	$nodes->{7},
	$nodes->{4},
	$nodes->{1}
	],
    15 => [
	$nodes->{15},
	$nodes->{10},
	$nodes->{7},
	$nodes->{4},
	$nodes->{1}
	],
    16 => [
	$nodes->{16},
	$nodes->{12},
	$nodes->{8},
	$nodes->{4},
	$nodes->{1}
	],
    17 => [
	$nodes->{17},
	$nodes->{12},
	$nodes->{8},
	$nodes->{4},
	$nodes->{1}
	],
    18 => [
	$nodes->{18},
	$nodes->{12},
	$nodes->{8},
	$nodes->{4},
	$nodes->{1}
	],
    19 => [
	$nodes->{19},
	$nodes->{16},
	$nodes->{12},
	$nodes->{8},
	$nodes->{4},
	$nodes->{1}
	],
    20 => [
	$nodes->{20},
	$nodes->{16},
	$nodes->{12},
	$nodes->{8},
	$nodes->{4},
	$nodes->{1}
	],
    21 => [
	$nodes->{21},
	$nodes->{18},
	$nodes->{12},
	$nodes->{8},
	$nodes->{4},
	$nodes->{1}
	],
    22 => [
	$nodes->{22},
	$nodes->{18},
	$nodes->{12},
	$nodes->{8},
	$nodes->{4},
	$nodes->{1}
	],
    23 => [
	$nodes->{23},
	$nodes->{18},
	$nodes->{12},
	$nodes->{8},
	$nodes->{4},
	$nodes->{1}
	],
};

our $lineageclean = {};
# delete all fields but sciname, taxid, and rank
my %wanted = ( sciname => 1, taxid => 1, rank => 1 );
foreach my $taxid (keys %{$lineage})
{
    foreach my $node (0..@{$lineage->{$taxid}}-1)
    {
	foreach my $key (keys %{$lineage->{$taxid}[$node]})
	{
	    next unless (exists $wanted{$key});
	    $lineageclean->{$taxid}[$node]{$key} = $lineage->{$taxid}[$node]{$key};
	}
    }
}


my %ranks_hash = ();
foreach my $rank (map {$nodes->{$_}{rank}} (keys %{$nodes}))
{
    $ranks_hash{$rank}++;
}
our @ranks = keys (%ranks_hash);

1;
