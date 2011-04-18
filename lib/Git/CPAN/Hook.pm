package Git::CPAN::Hook;

use strict;
use warnings;
use CPAN ();
use Git::Repository;

my %original;
my @hooks = (
    [ 'CPAN::Distribution::install'   => \&_install ],
    [ 'CPAN::HandleConfig::neatvalue' => \&_neatvalue ],
);
my @keys = qw( __HOOK__ __REPO__ );

# hook into install
_replace(@$_) for @hooks;

# install our keys in the config
$CPAN::HandleConfig::keys{$_} = undef for @keys;

sub _replace {
    my ( $fullname, $meth ) = @_;
    my $name = ( split /::/, $fullname )[-1];
    no strict 'refs';
    no warnings 'redefine';
    $original{$name} = \&{$fullname};
    *$fullname = $meth;
}

sub import {
    my ($class) = @_;
    my $pkg = caller;

    # always export everything
    no strict 'refs';
    *{"$pkg\::$_"} = \&$_ for qw( install uninstall );
}

sub install {
    my ($path) = @_ ? @_ : @ARGV;
    my $r = Git::Repository->new( work_tree => $path );

    CPAN::HandleConfig->load();
    $CPAN::Config->{__HOOK__} = sub { };
    my %seen;
    @{ $CPAN::Config->{__REPO__} }
        = grep { defined && length && !$seen{$_}++ }
        @{ $CPAN::Config->{__REPO__} }, $path;
    CPAN::HandleConfig->commit();
}

sub uninstall {
    my ($path) = @_;

    CPAN::HandleConfig->load();

    # just uninstall the given path
    if ( defined $path ) {
        @{ $CPAN::Config->{__REPO__} }
            = grep { $_ != $path } @{ $CPAN::Config->{__REPO__} };
    }

    # uninstall everything
    else {
        delete $CPAN::Config->{$_} for @keys;
    }

    CPAN::HandleConfig->commit();
}

#
# our replacements for some CPAN methods
#

# commit after a successful install
sub _install {
    my $dist = $_[0];
    my @rv   = $original{install}->(@_);

    # do something
    if ( !$dist->{install}{FAILED} ) {
        for my $repo ( @{ $CPAN::Config->{__REPO__} } ) {
            my $r = Git::Repository->new( work_tree => $repo );
            $r->run( add => '.' );
            if ( $r->run( status => '--porcelain' ) ) {
                $r->run( commit => -m => $dist->{ID} );
                print "# committed $dist->{ID} to $r->{work_tree}\n",;
            }
        }
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

