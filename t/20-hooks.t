use strict;
use warnings;
use Test::More;
use Test::Git;
use File::Temp qw( tempdir );
use Git::CPAN::Hook;

has_git('1.5.0');    # git init

plan tests => my $tests;

my ($dir, $r, @log, @refs);

#
# configuration for Git::CPAN::Hook
#

# these tests assume an empty directory
BEGIN { $tests += 5 }

$dir = tempdir( CLEANUP => 1 );
init($dir);

$r = eval { Git::Repository->new( work_tree => $dir ) };
isa_ok( $r, 'Git::Repository' );

is( $r->run(qw( config --bool cpan-hook.active )),
    'true', 'repository activated' );

@log = $r->run(qw( log --pretty=format:%H ));
is( scalar @log, 1, 'Single initial commit' );

@refs = map { ( split / /, $_, 2 )[1] } $r->run(qw( show-ref ));
is_deeply(
    \@refs,
    [qw( refs/heads/master refs/tags/empty )],
    'Only two refs: master & empty'
);

is( $r->run(qw( rev-list -1 empty )),
    $log[0], 'empty points to the first commit' );

# local::lib may have installed some files already
BEGIN { $tests += 5 }

$dir = tempdir( CLEANUP => 1 );
open my $fh, '>', File::Spec->catfile( $dir, '.modulebuildrc' );
print $fh "install  --install_base  $dir\n";
close $fh;
init($dir);

$r = eval { Git::Repository->new( work_tree => $dir ) };
isa_ok( $r, 'Git::Repository' );

is( $r->run(qw( config --bool cpan-hook.active )),
    'true', 'repository activated' );

@log = $r->run(qw( log --pretty=format:%H ));
is( scalar @log, 2, 'Two initial commits' );

@refs = map { ( split / /, $_, 2 )[1] } $r->run(qw( show-ref ));
is_deeply(
    \@refs,
    [qw( refs/heads/master refs/tags/empty )],
    'Only two refs: master & empty'
);

is( $r->run(qw( rev-list -1 empty )),
    $log[0], 'empty points to the first commit' );

