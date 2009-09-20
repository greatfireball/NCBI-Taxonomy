use strict;
use warnings;

my %data = ();
my %names = ();
my @nested_set_data = ();
my %parent2index = ();
my %id2index = ();

my $names_filename = '/bio/data/NCBI/taxonomy/download/names.dmp';
my $data_filename = '/bio/data/NCBI/taxonomy/download/nodes.dmp';

print "Starting import of names...\n";

open(FH, $names_filename) || die "Can not open $names_filename";
while (<FH>)
{
    my @tmp = split(/\t\|\t/, $_);
    next if ($tmp[3] !~ /scientific name/);
    $tmp[1] =~ s/^\s+|\s+$//g;
    $names{int($tmp[0])} = $tmp[1];
}
close(FH) || die "Can not close $names_filename";

print "Finished import of ".(keys %names)." scientific names\nStarting import of tree-data...\n";

open(FH, $data_filename) || die "Can not open $data_filename";
while (<FH>)
{
    my @tmp = split(/\t\|\t/, $_); 
    $tmp[2] =~ s/^\s+|\s+$//g;
    $data{int($tmp[0])} = {parent => int($tmp[1]), rank => $tmp[2]};
} 
close(FH) || die "Can not close $data_filename";

foreach (keys %data) {
    push(@{$parent2index{$data{$_}->{parent}}}, $_);
}

print "Finished import of ".(keys %data)." node data\n";

# now I want to create the tree! Root is node 1... I can just add it or better... Extract the root node:
my ($rootnode) = grep { $names{$_} eq "root" } (keys %names);
print "Nodenumber for root-node: $rootnode\n";

# set the root to the first element:
push(@nested_set_data, { 
			id        => int($rootnode),
			parent_id => $data{$rootnode}{parent},
			rank      => $data{$rootnode}{rank},
			name      => $names{$rootnode},
			lft       => 1,
			rgt       => 2
		       });
$id2index{$rootnode} = 0;

# next step have to the insertion of the next level so the question
# is, what are the ids for the next number or the other way arount,
# which nodes have the $rootnode as parent

my @nodes2goonwith = grep { ($data{$_}{parent} == $rootnode) && ($_ != $rootnode) } (keys %data);

print "Found ".@nodes2goonwith." nodes in the second level\nStarting tree generation...\n".time()."\n";

while (@nodes2goonwith) {

    if (@nested_set_data % 1000 == 0) {
	print time()."\tNested set contains ".@nested_set_data." Nodes\n";
    }
    my $act_id = shift(@nodes2goonwith);
    insert_taxid( {
		   id        => int($act_id),
		   parent_id => $data{$act_id}{parent},
		   rank      => $data{$act_id}{rank},
		   name      => $names{$act_id},
		   lft       => 0,
		   rgt       => 0
		  } );
}

exit;

sub insert_taxid {
    my ($dataset) = @_;

    my $rgt2search = $nested_set_data[$id2index{$dataset->{parent_id}}]->{rgt};

    foreach (@nested_set_data) {
	if ($_->{rgt} > $rgt2search)
	{
	    $_->{lft} += 2;
	    $_->{rgt} += 2;
	}
	elsif ($_->{rgt} == $rgt2search) {
	    $_->{rgt} += 2;
	}
    }

    $dataset->{rgt} = $rgt2search + 1;
    $dataset->{lft} = $rgt2search;

    push(@nested_set_data, $dataset);
    $id2index{$dataset->{id}} = @nested_set_data - 1;
    push(@nodes2goonwith, @{$parent2index{$dataset->{id}}} ) if (defined $parent2index{$dataset->{id}});

    return;
}
