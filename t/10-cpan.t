use strict;
use warnings;
use Test::More;

use CPAN ();

my %cpan = (
    'CPAN::Distribution::install'   => 'Git::CPAN::Hook::_install',
    'CPAN::HandleConfig::neatvalue' => 'Git::CPAN::Hook::_neatvalue',
);

plan tests => 2 * keys %cpan;

no strict 'refs';

# pick up the original addresses
my %cpan_orig = map { ( $_ => \&$_ ) } keys %cpan;

# now load the module
require Git::CPAN::Hook;

for ( keys %cpan ) {

    # check the addresses have changed
    isnt( \&$_, $cpan_orig{$_}, "$_ has been modified" );

    # check they point to the replacement code
    is( \&$_, \&{ $cpan{$_} }, "$_ is now $cpan{$_}" );
}

