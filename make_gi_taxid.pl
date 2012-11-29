#!/usr/bin/env perl

use strict;
use warnings;
use Fcntl;

my $act_line=0;

my @lines = split(/\s+/, qx(tail -qn 1 gi_taxid_nucl.dmp gi_taxid_prot.dmp | cut -f 1 | tr "\n" " "));

my @files=('gi_taxid_nucl.dmp', 'gi_taxid_prot.dmp');
@files= reverse @files if ($lines[0]<$lines[1]);

open(FH, "<".$files[0]);
open(OUT, ">".'gi_taxid.txt'); # frueher tmp.txt
while (<FH>) {
	if ($act_line != 0 && $act_line%100000==0)
        {
            if ($act_line%1000000==0)
            {
                print STDERR int($act_line/1000000);
            } else {
                print STDERR ".";
            }
        }	 
	my ($gi,$taxid) = $_ =~ /^(\d+)\t(\d+)/; 
	while ($act_line != ($gi-1)) {
		print OUT ((" "x15)."\t".(" "x7)."\n"); 
		$act_line++;
	} 
	printf OUT "%15i\t%7i\n", $gi, $taxid;
	$act_line++
}
close(OUT);
close(FH);

print STDERR "\nFinished first file!\n"; 
$act_line = 0;

open(FH, "<".$files[1]);
sysopen(OUT, 'gi_taxid.txt', O_WRONLY, 0440);
binmode(OUT);
while (<FH>) {
        $act_line++;
        if ($act_line != 0 && $act_line%100000==0)
        {
            if ($act_line%1000000==0)
            {
                print STDERR int($act_line/1000000);
            } else {
                print STDERR ".";
            }
        }
        my ($gi,$taxid) = $_ =~ /^(\d+)\t(\d+)/;
	sysseek(OUT, ($gi-1)*24, 0);
        syswrite(OUT, sprintf("%15i\t%7i\n", $gi, $taxid), 24);
}
close(OUT);
close(FH);


