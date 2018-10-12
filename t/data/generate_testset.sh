#!/bin/bash

perl -e '
   print join("\t", qw(accession accession.version taxid gi)), "\n";

   @header=("A".."G");

   srand(20181012);

   for(my $i = 2; $i<1000; $i++)
   {
      $acc=$header[rand(int(@header))].sprintf("%04d", $i);

      print join("\t", ($acc, $acc.".".int(1+rand(10)), int(rand(100)+1), $i)),"\n";
   }' | gzip --best >test.accession2taxid.gz
