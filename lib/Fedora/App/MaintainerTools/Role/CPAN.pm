#############################################################################
#
# Update a Perl RPM spec with the latest GA in the CPAN
#
# Author:  Chris Weyl (cpan:RSRCHBOY), <cweyl@alumni.drew.edu>
# Company: No company, personal work
#
# Copyright (c) 2009-2010 Chris Weyl <cweyl@alumni.drew.edu>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
#############################################################################

package Fedora::App::MaintainerTools::Role::CPAN;

use Moose::Role;
use namespace::autoclean;
use MooseX::Types::Path::Class ':all';

use File::Copy 'cp';
use Path::Class;
use List::MoreUtils 'uniq';

use autodie 'system';

use Fedora::App::MaintainerTools::Types ':all';

our $VERSION = '0.006_01';

# debugging
#use Smart::Comments '###';

#############################################################################

before execute => sub {

    # classes we need but don't want to load at compile-time
    Class::MOP::load_class($_) for qw{
        Module::CoreList
        CPAN::Easy
        CPAN::MetaMuncher
    };
    return;
};

#############################################################################

has _cpan_info => (
    is => 'ro', isa => 'Object', lazy_build => 1,
    handles => {
        get_cpan_dist => 'get_dist',
        get_cpan_info => 'get_info',
        get_cpan_meta_for => 'get_meta_for',
        get_cpan_info_for => 'get_info_for',
    },
);

sub _build__cpan_info { CPAN::Easy->new }

has mm_class => (
    traits => ['NoGetopt'], is => 'ro', isa => 'Str', lazy => 1,
    builder => '_build_mm_class',
);

sub _build_mm_class { CPAN::MetaMuncher->with_traits('RPMInfo') }

has corelist => (
    traits => ['NoGetopt', 'Hash'], is => 'ro', isa => 'HashRef', 
    lazy_build => 1, handles => { has_as_core => 'exists' },
);

sub _build_corelist { $Module::CoreList::version{$]} }


#############################################################################
# rpmbuild methods

sub build_srpm { shift->_build_cmd('-bs --nodeps', @_) }
sub build_rpm  { shift->_build_cmd('-ba',          @_) }

sub _build_cmd {
    my ($self, $rpm_opts, $spec) = @_;

    my ($dir, $specfile) = (dir->absolute, $spec->to_file);
    local $ENV{$_} for qw{ PERL5LIB PERL_MM_OPT MODULEBUILDRC };

    cp $spec->tarball, "$dir";

    $rpm_opts .= " --define '$_ $dir'"
        for qw{ _sourcedir _builddir _srcrpmdir _rpmdir };

    # From Fedora CVS Makefile.common.
    $self->log->warn('running rpmbuild...');
    system "rpmbuild $rpm_opts $specfile";

    return;
}

sub _new_spec {
    my ($self, $pkg) = @_;

    # build what our rpm name would be
    my ($dist, $rpm_name) = $self->pkg_to_dist($pkg);
    return if $self->check_if_satisfied($rpm_name, $pkg);

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


#############################################################################
# helper methods

sub strip_rpm_deps { shift; map { s/^perl\(//; s/\)$//; $_ } @_ }

sub pkg_to_dist {
    my ($self, $pkg) = @_;

    $pkg =~ s/::/-/g;
    $pkg =~ s/^perl\(//;
    $pkg =~ s/\)$//;

    my $module = $self->_cpanp->parse_module(module => $pkg);
    my $dist = $module->package_name;
    my $rpm_name = "perl-$dist";
    $self->log->trace("Found dist $dist for $pkg => $rpm_name");

    return ($dist, $rpm_name);
}

sub check_if_satisfied {
    my ($self, $rpm_name, $pkg) = @_;

    $pkg =~ s/-/::/g; # ugh.

    # first (easiest), check to see if we've built it already
    # then if it's core (no need to build srpm)
    # then, check local system
    # then, check yum

    return 1 if $self->has_new_pkg($rpm_name);
    return 1 if $self->has_as_core($pkg);
    return 1 if $self->rpmdb->find_by_name($rpm_name);
    return `repoquery $rpm_name` ? 1 : 0;
}

sub pretty_dep_tree {
    my ($self, $rpm_name, $tree) = @_;

    my $printable = Data::TreeDumper::DumpTree(
        $tree, $rpm_name,
        USE_ASCII => 1,
        DISPLAY_ADDRESS => 0,
    );
    $printable =~ s/= 1//g;

    return $printable;
}

1;

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



