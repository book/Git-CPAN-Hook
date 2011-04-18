package Git::CPAN::Hook;

use strict;
use warnings;
use CPAN;
use Git::Repository;

my %original;
my @hooks = (
    [ 'CPAN::Distribution::install'   => \&_install ],
    [ 'CPAN::HandleConfig::neatvalue' => \&_neatvalue ],
);

# hook into install
_hook(@$_) for @hooks;

# install our keys in the config
$CPAN::HandleConfig::keys{__} = undef;
if ( !exists $CPAN::Config->{__} ) {
    CPAN::HandleConfig->load();
    $CPAN::Config->{__} = sub { };
    CPAN::HandleConfig->commit();
    exit;
}

sub _hook {
    my ( $fullname, $meth ) = @_;
    my $name = ( split /::/, $fullname )[-1];
    no strict 'refs';
    no warnings 'redefine';
    $original{$name} = \&{$fullname};
    *$fullname = $meth;
}

#
sub _install {
    my $dist = $_[0];
    my @rv   = $original{install}->(@_);

    # do something
    if ( !$dist->{install}{FAILED} ) {
    }

    # return what's expected
    return @rv;
}

# make sure we always get loaded
sub _neatvalue {
    my $nv = $original{neatvalue}->(@_);
    return $nv =~ /^CODE/
        ? 'do { $CPAN::Config->{__} = 1; require Git::CPAN::Hook; sub { } }'
        : $nv;
}

1;
