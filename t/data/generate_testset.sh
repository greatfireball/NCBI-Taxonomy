#!/bin/bash

perl -e '
   print join("\t", qw(accession accession.version taxid gi)), "\n";

   @header=("A".."G");

   srand(20181012);

   my $max_number = 20;

   for(my $i = 2; $i<2+$max_number; $i++)
   {
      $acc=$header[rand(int(@header))].sprintf("%0".int(rand(13)+3)."d", $i);

      print join("\t", ($acc, $acc.".".int(1+rand(10)), int(rand($max_number/5)+1), $i)),"\n";
   }' | gzip --best >test.accession2taxid.gz
