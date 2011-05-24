use strict;
use warnings;
use Test::More;
use Test::Git;
use File::Temp qw( tempdir );
use Git::CPAN::Hook;

has_git('1.5.0');    # git init

plan tests => my $tests;

#
# repo setup and relation with CPAN client
#
my $dir = tempdir( CLEANUP => 1 );

#
# configuration for Git::CPAN::Hook
#
BEGIN { $tests += 5 }
init($dir);

my $r = eval { Git::Repository->new( work_tree => $dir ) };
isa_ok( $r, 'Git::Repository' );

is( $r->run(qw( config --bool cpan-hook.active )),
    'true', 'repository activated' );

my @log = $r->run(qw( log --pretty=format:%H ));
is( scalar @log, 1, 'Single initial commit' );

my @refs = map { ( split / /, $_, 2 )[1] } $r->run(qw( show-ref ));
is_deeply(
    \@refs,
    [qw( refs/heads/master refs/tags/empty )],
    'Only two refs: master & empty'
);

is( $r->run(qw( rev-list -1 empty )),
    $log[0], 'empty points to the first commit' );

