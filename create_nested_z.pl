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

print "Finished import of ".(keys %data)." node data\n";

# now I want to create the tree! Root is node 1... I can just add it or better... Extract the root node:
my ($rootnode) = grep { $names{$_} eq "root" } (keys %names);
print "Nodenumber for root-node: $rootnode\nStarting nested set generation...\n";

foreach (keys %data) {
    push(@{$parent2index{$data{$_}->{parent}}}, $_) if ($_ != $rootnode);
    push(@nested_set_data, { 
			id        => int($_),
			parent_id => $data{$_}{parent},
			rank      => $data{$_}{rank},
			name      => $names{$_},
			lft       => 0,
			rgt       => 0
		       });
    $id2index{$_} = @nested_set_data - 1;
}

print "Nodes of nested set were generated\nStarting walk through the tree...\n";
# now create the nested set using a recursive approach

our $runnumber = 0;

make_node($rootnode);

print "Finished nested set generation!\nNumber of leaf-nodes: ".(grep {$_->{lft} + 1 == $_->{rgt}} @nested_set_data)."\n";

# just a Test: Tardigrada:
my ($searchset) = grep {$_->{name} eq "Tardigrada"} @nested_set_data;
print Dumper(grep {$_->{lft} >= $searchset->{lft} && $_->{rgt} <= $searchset->{rgt}} @nested_set_data);
use Data::Dumper;

# another test with Milnesium tardigradum
($searchset) = grep {$_->{name} eq "Milnesium tardigradum"} @nested_set_data;
my @result = map {$_->{name}} sort {$a->{lft} <=> $b->{lft}} grep {$_->{lft} <= $searchset->{lft} && $_->{rgt} >= $searchset->{lft}} @nested_set_data;
print Dumper(\@result);

exit;

sub make_node ($) {
    my ($nodenumber) = @_;
    
    $runnumber++;
    $nested_set_data[$id2index{$nodenumber}]{lft} = $runnumber;

    if (defined $parent2index{$nodenumber}) {
	# es sind noch unterliegende Knoten vorhanden
	foreach (@{$parent2index{$nodenumber}}) { make_node($_); }
    }
    # wir sind am Blatt angekommen... rgt setzten und zurück
    $runnumber++;
    $nested_set_data[$id2index{$nodenumber}]{rgt} = $runnumber;
    #	print "Found leaf... RGT: $runnumber\n";
    return;
}

# # set the root to the first element:


# # next step have to the insertion of the next level so the question
# # is, what are the ids for the next number or the other way arount,
# # which nodes have the $rootnode as parent

# my @nodes2goonwith = grep { ($data{$_}{parent} == $rootnode) && ($_ != $rootnode) } (keys %data);

# print "Found ".@nodes2goonwith." nodes in the second level\nStarting tree generation...\n".time()."\n";

# while (@nodes2goonwith) {

#     if (@nested_set_data % 1000 == 0) {
# 	print time()."\tNested set contains ".@nested_set_data." Nodes\n";
#     }
#     my $act_id = shift(@nodes2goonwith);
#     insert_taxid( {
# 		   id        => int($act_id),
# 		   parent_id => $data{$act_id}{parent},
# 		   rank      => $data{$act_id}{rank},
# 		   name      => $names{$act_id},
# 		   lft       => 0,
# 		   rgt       => 0
# 		  } );
# }

# exit;

# sub insert_taxid {
#     my ($dataset) = @_;

#     my $rgt2search = $nested_set_data[$id2index{$dataset->{parent_id}}]->{rgt};

#     foreach (@nested_set_data) {
# 	if ($_->{rgt} > $rgt2search)
# 	{
# 	    $_->{lft} += 2;
# 	    $_->{rgt} += 2;
# 	}
# 	elsif ($_->{rgt} == $rgt2search) {
# 	    $_->{rgt} += 2;
# 	}
#     }

#     $dataset->{rgt} = $rgt2search + 1;
#     $dataset->{lft} = $rgt2search;

#     push(@nested_set_data, $dataset);
#     $id2index{$dataset->{id}} = @nested_set_data - 1;
#     push(@nodes2goonwith, @{$parent2index{$dataset->{id}}} ) if (defined $parent2index{$dataset->{id}});

#     return;
# }
