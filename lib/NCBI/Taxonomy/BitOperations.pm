package Taxonomy::BitOperations;

use POSIX;

sub _get_value_from_fh_by_position_and_with
{
    my ($fh, $width, $pos, $offset) = @_;

}

sub _get_pos_width
{
    my ($pos, $width) = @_;
    
    # calculate the position in bytes
    my $bit_inside = $pos & 7;     # lower three bits are the start bit
    my $byte_pos   = $pos>>3;      # pos/8 returns byte position

    my $number_of_bytes = ceil($width/8);
    my $shift_to_left   = 8-$bit_inside;
    my $mask            = (2**$width)-1;
    my $mask_delete     = 0;
    my $mask_extract    = 0;

    return ($bit_inside, $byte_pos, $number_of_bytes);
}

1;
