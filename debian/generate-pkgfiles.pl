#!/usr/bin/perl

use strict;
use warnings;
use feature ':5.10';
use autodie;
use FindBin '$Bin';
use IPC::Run 'run';


my $description_cpp = <<'EOF';
GNU C cross-preprocessor (cpp)
 This is the GNU C preprocessor cpp built for cross-building $DEB_TARGET_ARCH
 binaries/packages. This is actually a metapackage that will bring in the
 correct versioned cpp cross package and symlink to it.
EOF

my $description_gcc = <<'EOF';
GNU C cross-compiler
 This is the GNU C compiler built for cross-building $DEB_TARGET_ARCH
 binaries/packages. This is actually a metapackage that will bring in the
 correct versioned gcc cross package and symlink to it.
EOF

my $description_gpp = <<'EOF';
GNU C++ cross-compiler
 This is the GNU C++ compiler built for cross-building $DEB_TARGET_ARCH
 binaries/packages. This is actually a metapackage that will bring in the
 correct versioned gcc cross package and symlink to it.
EOF

my $description_gfortran = <<'EOF';
GNU Fortran 95 cross-compiler
 This is the GNU Fortran 95 compiler built for cross-building $DEB_TARGET_ARCH
 binaries/packages. This is actually a metapackage that will bring in
 the correct versioned gcc cross package and symlink to it.
EOF

my $description_gobjc = <<'EOF';
GNU objective C cross-compiler
 This is the GNU objective C compiler built for cross-building $DEB_TARGET_ARCH
 binaries/packages. This is actually a metapackage that will bring in the
 correct versioned gcc cross package and symlink to it.
EOF

my $description_gccgo = <<'EOF';
GNU go cross-compiler
 This is the GNU go compiler built for cross-building $DEB_TARGET_ARCH
 binaries/packages. This is actually a metapackage that will bring in the
 correct versioned gcc cross package and symlink to it.
EOF

my %base_descriptions = ( 'cpp'      => $description_cpp,
                          'gcc'      => $description_gcc,
                          'g++'      => $description_gpp,
                          'gfortran' => $description_gfortran,
                          'gobjc'    => $description_gobjc,
                          'gccgo'    => $description_gccgo );







my $target_list_str = $ENV{TARGET_LIST} || `cat $Bin/targetlist` || ' ';
my @target_list = split / /, $target_list_str or
  die "Couldn't get target list from the TARGET_LIST env var, or from the file '$Bin/targetlist'";

say "Generating debian/control for arches '@target_list'";

my @pkgs    = split(/ /, runchild(qw(make --quiet -f), "$Bin/rules", 'say_pkgs_release'));
my $release = pop @pkgs;

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
    my $DEB_TARGET_GNU_TYPE =
      runchild(qw(dpkg-architecture -qDEB_HOST_GNU_TYPE -f), "-a$DEB_TARGET_ARCH");
    $DEB_TARGET_GNU_TYPE =~ s/_/-/g;

    say $fd_control_out "";

    for my $pkg (@pkgs)
    {
        my $description;


        my $subst_into_control = sub
        {
            foreach(@_)
            {
                s/\$DEB_TARGET_GNU_TYPE/$DEB_TARGET_GNU_TYPE/;
                s/\$DEB_TARGET_ARCH/$DEB_TARGET_ARCH/;
                s/\$pkg/$pkg/;
                s/\$ver/$release/;
                s/\$description/$description/;
            }
        };



        $description = description($pkg, $DEB_TARGET_ARCH);
        $subst_into_control->($description);

        open my $fd_control_in, '<', "$Bin/control.pkg.in";
        while(<$fd_control_in>)
        {
            $subst_into_control->($_);
            print $fd_control_out $_;
        }
    }

    generate_alternatives($DEB_TARGET_GNU_TYPE);
}




sub description
{
    my $pkg  = shift;
    my $arch = shift;

    my $base;
    if( $base_descriptions{$pkg} )
    {
        $base = $base_descriptions{$pkg};
    }
    else
    {
        $base_descriptions{$pkg} = $base =
          runchild(qw(dpkg-query -f), '${Description}', '-W', $pkg);
    }

    my $description = $base;
    $description =~ s/$/ for architecture $arch/m;
    return $description;
}

sub runchild
{
    my @args = @_;

    my ($in,$out,$err) = ('','','');
    run \@args, \$in, \$out, \$err
      or die "Error running '@args'. STDERR:\n$err";

    chomp $out;
    if( length($out) <= 0)
    {
        die "Error running '@args': output empty. STDERR:\n$err";
    }

    return $out;
}

sub generate_alternatives
{
    my ($DEB_TARGET_GNU_TYPE) = @_;

    for my $prog (qw(gcc g++ gfortran))
    {
        for my $inputfile (map {"$Bin/$prog.alternatives.$_.in"} qw(prerm postinst))
        {
            my $outputfile = $inputfile;
            $outputfile =~ s/(.*)\.alternatives(.*)\.in/$1-$DEB_TARGET_GNU_TYPE$2/;

            open my $fd_in,  '<', $inputfile;
            open my $fd_out, '>', $outputfile;

            while (<$fd_in>)
            {
                s/\$DEB_TARGET_GNU_TYPE/$DEB_TARGET_GNU_TYPE/g;
                print $fd_out $_;
            }
        }
    }
}
