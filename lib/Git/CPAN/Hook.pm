package Git::CPAN::Hook;

use strict;
use warnings;
use CPAN ();
use Git::Repository;

our $VERSION = '0.01';

# the list of CPAN.pm methods we will replace
my %cpan;
my %hook = (
    'CPAN::Distribution::install'   => \&_install,
    'CPAN::HandleConfig::neatvalue' => \&_neatvalue,
);
my @keys = qw( __HOOK__ );

# actually replace the code in CPAN.pm
_replace( $_ => $hook{$_} ) for keys %hook;

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
    CPAN::HandleConfig->load();
    $CPAN::Config->{__HOOK__} = sub { };
    CPAN::HandleConfig->commit();
}

sub uninstall {
    CPAN::HandleConfig->load();
    delete $CPAN::Config->{$_} for @keys;
    CPAN::HandleConfig->commit();
}

#
# our replacements for some CPAN.pm methods
#

# commit after a successful install
sub _install {
    my $dist = $_[0];
    my @rv   = $cpan{install}->(@_);

    # do something only after a successful install
    if ( !$dist->{install}{FAILED} ) {

        # assume distributions are always installed somewhere in @INC
        for my $inc (grep -e, @INC) {
            my $r = eval { Git::Repository->new( work_tree => $inc ); };
            next if !$r;    # not a Git repository

            # do not commit in random directories!
            next if $r->run(qw( config --bool cpan-hook.active )) ne 'true';

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

__END__

=head1 NAME

Git::CPAN::Hook - Commit each install done by CPAN.pm in a Git repository

=head1 SYNOPSIS

    # put your local::lib under Git control
    $ cd ~/perl5
    $ git init

    # ignore some files
    $ perl -le 'print for qw( .packlist perllocal.pod )' > .gitignore
    $ git add .
    $ git commit -m "initial commit"
    [master (root-commit) a2bf011] initial commit
     2 files changed, 3 insertions(+), 0 deletions(-)
     create mode 100644 .gitignore
     create mode 100644 .modulebuildrc

    # allow Git::CPAN::Hook to commit in this repository
    $ echo > .git/cpan-hook

    # install the hooks in CPAN.pm
    $ perl -MGit::CPAN::Hook -e install

    # use CPAN.pm / cpan as usual
    # every install will create a commit in the current branch

    # uninstall the hooks from CPAN.pm's config
    $ perl -MGit::CPAN::Hook -e uninstall

=head1 DESCRIPTION

C<Git::CPAN::Hook> adds Git awareness to the CPAN.pm module installer.
Once the hooks are installed in CPAN.pm's configuration, each and every
module installation will result in a commit being done in the installation
directory/repository.

This module is a proof of concept.

Then I want to experiment with a repository of installed stuff, especially
several versions of the same distribution. And then start doing fancy
things like uninstalling a single distribution, testing my modules against
different branches (each test environment only a 'git checkout' away!),
creating a full install from scratch by applying "install patches", etc.

If this proves useful in any way, it shouldn't be too hard to port to
CPAN clients that support hooks and plugins. It might be a little more
difficult to use the I<terminate and stay resident> approach I used
on CPAN.pm on other clients, as they probably have a san^Hfer configuration
file format.


=head1 AUTHOR

Philippe Bruhat (BooK), C<< <book at cpan.org> >>

=head1 HISTORY AND ACKNOWLEDGEMENTS

The initial idea for this module comes from a conversation
between Andy Armstrong, Tatsuhiko Miyagawa, brian d foy and myself
(each having his own goal in mind) at the Perl QA Hackathon 2010 in Vienna.

My own idea was that it would be neat to install/uninstall distributions
using Git to store the files, so that I could later develop some tools
to try all kinds of crazy combinations of modules versions and installations.
I already saw myself bisecting on a branch with all versions of a given
dependency...

To do that and more, I needed a module to control Git from within Perl.
So I got distracted into writing C<Git::Repository>.

At the Perl QA Hackathon 2011 in Amsterdam, the discussion came up again
with only Andy Armstrong and myself, this time. He gently motivated me
into "just doing it", and after a day of experimenting, I was able to
force C<CPAN.pm> to create a commit after each individual installation.

=head1 TODO

Here are some of the items on my list:

=over 4

=item

Make it possible for other CPAN installers that have the ability to use
hooks to use Git::CPAN::Hook.

=item

Some command-line tool for easy manipulation of installed distributions.

=item

It would be great to say: "go forth on BackPAN and install all versions
of distribution XYZ, with all its dependencies, and make me a branch
with all these, so that I can bisect my own module to find which is the
oldest version that works with it".

Or something like that.

=item

Turn any installed distribution into a tagged parentless commit that
can be simply "applied" onto any branch (i.e. find a way to create a
minimal C<tree> object for it).

=back


=head1 BUGS

Please report any bugs or feature requests to C<bug-git-cpan-hook at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=GIT-CPAN-Hook>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Git::CPAN::Hook

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Git-CPAN-Hook>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Git-CPAN-Hook>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Git-CPAN-Hook>

=item * Search CPAN

L<http://search.cpan.org/dist/Git-CPAN-Hook/>

=back

=head1 COPYRIGHT

Copyright 2011 Philippe Bruhat (BooK).

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

