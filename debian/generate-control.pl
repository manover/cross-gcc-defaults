#!/usr/bin/perl

use strict;
use warnings;
use feature ':5.10';
use autodie;
use FindBin '$Bin';
use IPC::Run 'run';

unless( -e 'debian/defaults' )
{
    die "ERROR: Run ./debian/update-defaults.sh first";
}


my $target_list_str = $ENV{TARGET_LIST} || `cat $Bin/targetlist` || ' ';
my @target_list = split / /, $target_list_str or
  die "Couldn't get target list from the TARGET_LIST env var, or from the file '$Bin/targetlist'";

say "Generating debian/control for arches '@target_list'";

my @progvers;
open my $fd_progs, '<', "$Bin/defaults";
while(<$fd_progs>)
{
    my ($prog,$ver) = split;
    next unless length($prog) && length($ver);

    push @progvers, [$prog, $ver];
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

    for my $progver (@progvers)
    {
        my ($prog,$ver) = @$progver;

        my $description = description($prog, $DEB_TARGET_ARCH);
        say $fd_control_out "";

        open my $fd_control_in, '<', "$Bin/control.pkg.in";
        while(<$fd_control_in>)
        {
            s/\$DEB_TARGET_GNU_TYPE/$DEB_TARGET_GNU_TYPE/;
	    s/\$DEB_TARGET_ARCH/$DEB_TARGET_ARCH/;
	    s/\$prog/$prog/;
	    s/\$ver/$ver/;
	    s/\$description/$description/;


            print $fd_control_out $_;
        }
    }
}







my %base_descriptions;
sub description
{
    my $prog = shift;
    my $arch = shift;

    my $base;
    if( $base_descriptions{$prog} )
    {
        $base = $base_descriptions{$prog};
    }
    else
    {
        my ($in,$out,$err) = ('','','');
        run [qw(dpkg-query -f), '${Description}', '-W', $prog], \$in, \$out, \$err
          or die "Error getting description from package '$prog'";

        if( length($out) <= 0)
        {
            die "Error getting description from package '$prog': too short";
        }

        $base_descriptions{$prog} = $base = $out;
    }

    my $description = $base;
    $description =~ s/$/ for architecture $arch/m;
    return $description;
}






