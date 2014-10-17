#!/usr/bin/perl

use strict;
use warnings;
use feature ':5.10';
use autodie;
use FindBin '$Bin';
use IPC::Run 'run';

# if [ ! -f debian/defaults ]; then
#     echo "ERROR: Run ./debian/update-defaults.sh first" >&2
#     exit 1
# fi



my $target_list_str = $ENV{TARGET_LIST} || `cat $Bin/targetlist` || ' ';
my @target_list = split / /, $target_list_str or
  die "Couldn't get target list from the TARGET_LIST env var, or from the file '$Bin/targetlist'";

say "Generating debian/control for arches '@target_list'";

my @progs;
open my $fd_progs, '<', "$Bin/defaults";
while(<$fd_progs>)
{
    my ($prog,$ver) = split;
    next unless length($prog) && length($ver);

    push @progs, {prog => $prog,
                  ver  => $ver};
}
close $fd_progs;


open my $fd_control_out, '>', "$Bin/control";

{
    open my $fd_control_head, '<', "$Bin/control.head.in";
    local $/ = undef;
    my $head = <$fd_control_head>;
    print $fd_control_out $head;
    close $fd_control_head;
}

for my $DEB_TARGET_ARCH (@target_list)
{
    my $DEB_TARGET_GNU_TYPE;
    {
        my ($in,$out,$err) = ('','','');
        run [qw(dpkg-architecture -qDEB_HOST_GNU_TYPE -f), "-a$DEB_TARGET_ARCH"], \$in, \$out, \$err
          or die "Error running dpkg-architecture. STDERR: '$err'";

        $DEB_TARGET_GNU_TYPE = $out;
        chomp $DEB_TARGET_GNU_TYPE;

        if( !length($DEB_TARGET_GNU_TYPE))
        {
            die "Couldn't get the gnu type for arch '$DEB_TARGET_ARCH'";
        }
    }

    say $fd_control_out "";

    for my $progver (@progs)
    {
        say $fd_control_out "";

        open my $fd_control_in, '<', "$Bin/control.pkg.in";
        while(<$fd_control_in>)
        {
            s/\$DEB_TARGET_GNU_TYPE/$DEB_TARGET_GNU_TYPE/;
	    s/\$DEB_TARGET_ARCH/$DEB_TARGET_ARCH/;
	    s/\$prog/$progver->{prog}/;
	    s/\$ver/$progver->{ver}/;


            print $fd_control_out $_;
        }
    }
}
