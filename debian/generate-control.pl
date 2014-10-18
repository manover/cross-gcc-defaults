#!/usr/bin/perl

use strict;
use warnings;
use feature ':5.10';
use autodie;
use FindBin '$Bin';
use IPC::Run 'run';


my $description_cpp = <<'EOF';
GNU C preprocessor (cpp)
 The GNU C preprocessor is a macro processor that is used automatically
 by the GNU C compiler to transform programs before actual compilation.
 .
 This package has been separated from gcc for the benefit of those who
 require the preprocessor but not the compiler.
 .
 This is a dependency package providing the default GNU C preprocessor.
EOF

my $description_gcc = <<'EOF';
GNU C compiler
 This is the GNU C compiler, a fairly portable optimizing compiler for C.
 .
 This is a dependency package providing the default GNU C compiler.
EOF

my $description_gpp = <<'EOF';
GNU C++ compiler
 This is the GNU C++ compiler, a fairly portable optimizing compiler for C++.
 .
 This is a dependency package providing the default GNU C++ compiler.
EOF

my $description_gfortran = <<'EOF';
GNU Fortran 95 compiler
 This is the GNU Fortran 95 compiler, which compiles Fortran 95 on platforms
 supported by the gcc compiler. It uses the gcc backend to generate optimized
 code.
 .
 This is a dependency package providing the default GNU Fortran 95 compiler.
EOF

my %base_descriptions = ( 'cpp'      => $description_cpp,
                          'gcc'      => $description_gcc,
                          'g++'      => $description_gpp,
                          'gfortran' => $description_gfortran);







my $target_list_str = $ENV{TARGET_LIST} || `cat $Bin/targetlist` || ' ';
my @target_list = split / /, $target_list_str or
  die "Couldn't get target list from the TARGET_LIST env var, or from the file '$Bin/targetlist'";

say "Generating debian/control for arches '@target_list'";

my @progs   = split(/ /, runchild(qw(make -f), "$Bin/rules", 'say_progs_release'));
my $release = pop @progs;

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

    for my $prog (@progs)
    {
        my $description = description($prog, $DEB_TARGET_ARCH);

        open my $fd_control_in, '<', "$Bin/control.pkg.in";
        while(<$fd_control_in>)
        {
            s/\$DEB_TARGET_GNU_TYPE/$DEB_TARGET_GNU_TYPE/;
	    s/\$DEB_TARGET_ARCH/$DEB_TARGET_ARCH/;
	    s/\$prog/$prog/;
	    s/\$ver/$release/;
	    s/\$description/$description/;


            print $fd_control_out $_;
        }
    }
}




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
