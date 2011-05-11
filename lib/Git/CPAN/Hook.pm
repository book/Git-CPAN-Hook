package Git::CPAN::Hook;

use strict;
use warnings;
use CPAN ();
use Git::Repository;


# the list of CPAN.pm methods we will replace
my %cpan;
my @hooks = (
    [ 'CPAN::Distribution::install'   => \&_install ],
    [ 'CPAN::HandleConfig::neatvalue' => \&_neatvalue ],
);
my @keys = qw( __HOOK__ __REPO__ );

# actually replace the code in CPAN.pm
_replace(@$_) for @hooks;

# install our keys in CPAN.pm's config
$CPAN::HandleConfig::keys{$_} = undef for @keys;

#
# some private utilities
#

sub _replace {
    my ( $fullname, $meth ) = @_;
    my $name = ( split /::/, $fullname )[-1];
    no strict 'refs';
    no warnings 'redefine';
    $cpan{$name} = \&{$fullname};
    *$fullname = $meth;
}

sub import {
    my ($class) = @_;
    my $pkg = caller;

    # always export everything
    no strict 'refs';
    *{"$pkg\::$_"} = \&$_ for qw( install uninstall );
}

#
# exported methods
#

sub install {
    my ($path) = @_ ? @_ : @ARGV;

    # will die if not a Git repository
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
# our replacements for some CPAN.pm methods
#

# commit after a successful install
sub _install {
    my $dist = $_[0];
    my @rv   = $cpan{install}->(@_);

    # do something after a successful install
    if ( !$dist->{install}{FAILED} ) {
        for my $repo ( @{ $CPAN::Config->{__REPO__} } ) {
            my $r = Git::Repository->new( work_tree => $repo );

            # commit step
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
    my $nv = $cpan{neatvalue}->(@_);

    # CPAN's neatvalue just stringifies coderefs, which we then replace
    # with some code to hook us back in CPAN for next time
    return $nv =~ /^CODE/
        ? 'do { require Git::CPAN::Hook; sub { } }'
        : $nv;
}

1;

