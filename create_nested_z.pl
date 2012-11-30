use strict;
use warnings;

use Storable;

use DateTime;

my %data = ();
my %names = ();
my @nested_set_data = ();
my %parent2index = ();
my %id2index = ();
my %ranks = ();
my @ranknames = ();

our $runnumber = 0;

sub make_node($);
sub get_rank($);

print STDERR <<ENDOFWELCOME;
***************************************************************************
*                                                                         *
*       Script for creation of all needed files for the                   *
*       Perl module                                                       *
*                         NCBI::Taxonomy                                  *
*       writen by                                                         *
*                         Frank Förster                                   *
*                                                                         *
***************************************************************************
ENDOFWELCOME

=pod

=head2 get_file_by_ftp

  purpose:      downloads a file to the current directory
  prototyp:     get_files_by_ftp($$$);
  input:        host     <STRING> host of the file, e.g. 'ftp.ncbi.nih.gov'
                dir      <STRING> directory where the file is stored, e.g. '/pub/taxonomy/'
                filename <STRING> filename of the file, e.g. 'taxdump.tar.gz'
  output:       the creation date of the file is returned as a DateTime object
                and the received file is stored in the current working dir

  example:      get_file_by_ftp() returns 

=cut

sub get_file_by_ftp ($$$) {
    my ($host, $dir, $filename) = @_;

    # delete old file with the same filename if it exists:
    if (-e $filename)
    {
	print STDERR "Deleting old $filename\n";
	unlink($filename) || die "Error on deleting file $filename";
    }
    my $url="ftp://$host/$dir/$filename";
    print STDERR "Checking for wget program...\n";
    my $wget_path = qx(which wget);

    die "Error on detecting the wget program!" if ($?);
    chomp($wget_path);
    print STDERR "Found wget on the location $wget_path\nDownloading new file $filename from $url\n";
    qx($wget_path -q -N '$url');
    if ($?)
    {
	unlink($filename) if (-e $filename);
	die "Error at download of $filename";
    }

    my $dt = DateTime->from_epoch( epoch => (stat($filename))[9]);

    return $dt;
}

print STDERR "Taxonomy file was created at ".get_file_by_ftp('ftp.ncbi.nih.gov', '/pub/taxonomy', 'taxdump.tar.gz')."\n";

my $names_filename = 'tar -O -xzf taxdump.tar.gz names.dmp|';
my $data_filename = 'tar -O -xzf taxdump.tar.gz nodes.dmp|';

print STDERR "Starting import of names...\n";

open(FH, $names_filename) || die "Can not open $names_filename";
while (<FH>)
{
    my @tmp = split(/\t\|\t/, $_);
    next if ($tmp[3] !~ /scientific name/);
    $tmp[1] =~ s/^\s+|\s+$//g;
    $names{int($tmp[0])} = $tmp[1];
}
close(FH) || die "Can not close $names_filename";

print STDERR "Finished import of ".(keys %names)." scientific names\nStarting import of tree-data...\n";

open(FH, $data_filename) || die "Can not open $data_filename";
while (<FH>)
{
    my @tmp = split(/\t\|\t/, $_); 
    $tmp[2] =~ s/^\s+|\s+$//g;
    $data{int($tmp[0])} = {parent => int($tmp[1]), rank => $tmp[2]};
} 
close(FH) || die "Can not close $data_filename";

print STDERR "Finished import of ".(keys %data)." node data\n";

# now I want to create the tree! Root is node 1... I can just add it or better... Extract the root node:
my ($rootnode) = grep { $names{$_} eq "root" } (keys %names);
print STDERR "Nodenumber for root-node: $rootnode\nStarting nested set generation...\n";

foreach (keys %data)
{
    push(@{$parent2index{$data{$_}->{parent}}}, $_) if ($_ != $rootnode);
    push(@nested_set_data, { 
			    id        => int($_),
			    parent_id => $data{$_}{parent},
			    rank      => get_rank($data{$_}{rank}),
			    name      => $names{$_},
			    lft       => 0,
			    rgt       => 0
			   });
    $id2index{$_} = @nested_set_data - 1;
}

print STDERR "Nodes of nested set were generated\nStarting walk through the tree...\n";

# now create the nested set using a recursive approach
make_node($rootnode);

print STDERR "Finished nested set generation!\nNumber of leaf-nodes: ".(grep {$_->{lft} + 1 == $_->{rgt}} @nested_set_data)."\n";

# just a test with Milnesium tardigradum
print STDERR "\n".("*" x 75)."\n*     Just a little example with the lineage of Milnesium tardigradum     *\n".("*" x 75)."\n";
my ($searchset) = grep {$_->{name} eq "Milnesium tardigradum"} @nested_set_data;
my @result = map {$_->{name}} sort {$a->{lft} <=> $b->{lft}} grep {$_->{lft} <= $searchset->{lft} && $_->{rgt} >= $searchset->{lft}} @nested_set_data;
print STDERR join(", ", @result)."\n\n";

print STDERR "Valid Ranks are: \n".join(", ", sort keys %ranks)."\n\n";

print STDERR "Storing the nested set in the file nested_set.bin\n";
Storable::nstore(\@nested_set_data, 'nested_set.bin');

foreach (@nested_set_data)
{
    print join("|", ($_->{id}, $_->{parent_id}, "'".$_->{name}."'", "'".$ranknames[$_->{rank}]."'", $_->{lft}, $_->{rgt}))."\n";
}

exit;

sub make_node ($) {
    my ($nodenumber) = @_;
    
    $runnumber++;
    $nested_set_data[$id2index{$nodenumber}]{lft} = $runnumber;

    if (defined $parent2index{$nodenumber})
    {
	# okay... Subnodes are existing and have to be processed!
	foreach (@{$parent2index{$nodenumber}})
	{
	    make_node($_);
	}
    }
    # we reached the leaf node... set rgt and return
    $runnumber++;
    $nested_set_data[$id2index{$nodenumber}]{rgt} = $runnumber;
    return;
}

sub get_rank ($) {
    my ($rank) = @_;
    if (!exists $ranks{$rank})
    {
	push(@ranknames, $rank);
	$ranks{$rank} = @ranknames - 1;
    }
	
    return $ranks{$rank};
}
