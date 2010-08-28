use strict;

my (%canon, %nonac);

sub canonize_nick
{
    my ($nick) = shift;
    my ($id);

    do {
	$id = sprintf ("%4.4lx", int (rand (65536)));
    } while (exists ($nonac{$id}));

    $canon{$nick} = $id;
    $nonac{$id} = $nick;
}

sub change_nick
{
    my ($old, $new) = @_;
    my ($id) = $canon{$old};

    delete $canon{$old};
    $nonac{$id} = $new;
    $canon{$new} = $id;
}

sub remove_nick
{
    my ($nick) = shift;
    my ($id) = $canon{$nick};

    delete ($canon{$nick});
    delete ($nonac{$id});
}
    
1;
