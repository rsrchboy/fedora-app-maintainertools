#############################################################################
#
# Update a Perl RPM spec with the latest GA in the CPAN
#
# Author:  Chris Weyl (cpan:RSRCHBOY), <cweyl@alumni.drew.edu>
# Company: No company, personal work
# Created: 05/12/2009 09:54:18 PM PDT
#
# Copyright (c) 2009 Chris Weyl <cweyl@alumni.drew.edu>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
#############################################################################

package Fedora::App::MaintainerTools::Command::newspec;

use Moose;
use namespace::autoclean;
use MooseX::Types::Moose ':all';
use MooseX::Types::Path::Class ':all';
use File::Copy 'cp';
use List::MoreUtils 'uniq';
use Path::Class;

use autodie 'system';

use Fedora::App::MaintainerTools::Types ':all';

extends 'MooseX::App::Cmd::Command';
with 'Fedora::App::MaintainerTools::Role::Logger';
with 'Fedora::App::MaintainerTools::Role::CPAN';
with 'Fedora::App::MaintainerTools::Role::Template';
with 'Fedora::App::MaintainerTools::Role::RPM';
with 'Fedora::App::MaintainerTools::Role::SpecUtils';

# debugging
#use Smart::Comments '###';

# classes we need but don't want to load at compile-time
my @CLASSES = qw{
    DateTime
};

our $VERSION = '0.006_01';

sub command_names { 'new-spec' }

has recursive => (is => 'ro', isa => Bool, default => 0);

has _new_pkgs => (
    traits => ['Hash'],
    is => 'ro', isa => 'HashRef', default => sub { {} },
    handles => {
        new_pkgs     => 'keys',
        has_new_pkgs => 'count',
        no_new_pkgs  => 'is_empty',
        num_new_pkgs => 'count',
        has_new_pkg  => 'exists',
        add_new_pkg  => 'set',
    },
);

sub execute {
    my ($self, $opt, $args) = @_;

    $self->log->info('Beginning new-spec run.');
    Class::MOP::load_class($_) for @CLASSES;

    for my $module (@$args) {

        #my ($dist, $rpm_name) = $self->_pkg_to_dist($pkg);
        my $mm = $self->mm_class->new(module => $module);
        my $ret = $self->_new_spec($pkg);

        my @new = $self->new_pkgs;

        next unless $self->recursive;

        ### $ret
        ### @new

        my $tree = $self->_pretty_dep_tree($rpm_name, $ret);
        print "For $pkg ($dist), we generated " . @new . " new srpms.\n\n";

        print "These packages are dependent on each other as:\n\n$tree\n\n";
    }

    return;
}

sub _new_spec {
    my ($self, $mm) = @_;

    # build what our rpm name would be
    #my ($dist, $rpm_name) = $self->_pkg_to_dist($pkg);
    my ($dist, $rpm_name) = ($mm->name, $mm->rpm_pkg_name);
    return if $self->_check_if_satisfied($mm);

    $self->log->info("Working on $dist.");
    my $data = $self
        ->_new_spec_class
        ->new(dist => $dist, cpanp => $self->_cpanp)
        ;
    $self->build_srpm($data);
    $self->add_new_pkg($rpm_name);

    return unless $self->recursive;

    my @deps = uniq sort ($data->build_requires, $data->requires);

    my %children = ();
    $self->_strip_rpm_deps(@deps);
    for my $dep (@deps) {

        $self->log->trace("Checking $dep (for $rpm_name)");
        my ($child_dist, $child_rpm_name) = $self->_pkg_to_dist($dep);
        my $ret = $self->_new_spec($dep);
        $children{$child_rpm_name} = $ret if $ret;
    }

    ### %children
    return keys %children ? \%children : 1;
}

sub _check_if_satisfied {
    #my ($self, $rpm_name, $pkg) = @_;
    my ($self, $mm) = @_;

    #$pkg =~ s/-/::/g; # ugh.

    # first (easiest), check to see if we've built it already
    # then if it's core (no need to build srpm)
    # then, check local system
    # then, check yum

    return 1 if $self->has_new_pkg($mm->rpm_pkg_name);
    #return 1 if $self->has_as_core($pkg);
    return 1 if $self->has_as_core($mm->module);
    return 1 if $self->_rpmdb->find_by_name($mm->rpm_pkg_name);
    return `repoquery $rpm_name` ? 1 : 0;
}

__PACKAGE__->meta->make_immutable;

__END__

=head1 NAME

Fedora::App::MaintainerTools::Command::newspec - Generate a srpm/spec

=head1 DESCRIPTION

Generates a spec file with metadata from the CPAN.


=head1 SEE ALSO

L<maintainertool>, L<Fedora::App::MaintainerTools>

=head1 AUTHOR

Chris Weyl  <cweyl@alumni.drew.edu>


=head1 LICENSE AND COPYRIGHT

Copyright (c) 2009 Chris Weyl <cweyl@alumni.drew.edu>

This library is free software; you can redistribute it and/or
modify it under the terms of the GNU Lesser General Public
License as published by the Free Software Foundation; either
version 2.1 of the License, or (at your option) any later version.

This library is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Lesser General Public License for more details.

You should have received a copy of the GNU Lesser General Public
License along with this library; if not, write to the

    Free Software Foundation, Inc.
    59 Temple Place, Suite 330
    Boston, MA  02111-1307  USA

=cut



