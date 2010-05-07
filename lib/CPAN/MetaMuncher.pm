#############################################################################
#
# Digest a META.yml so we can get at the good parts easily :)
#
# Author:  Chris Weyl (cpan:RSRCHBOY), <cweyl@alumni.drew.edu>
# Company: No company, personal work
# Created: 05/11/2009 11:32:18 PM PDT
#
# Copyright (c) 2009 Chris Weyl <cweyl@alumni.drew.edu>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
#############################################################################

package CPAN::MetaMuncher;

use Moose;
use namespace::autoclean;
use MooseX::Types::Moose       ':all';
use MooseX::Types::Path::Class ':all';

use CPAN::Easy;
use Path::Class;

our $VERSION = '0.006';

# debugging
#use Smart::Comments '###', '####';

#############################################################################
# required / buildargs

# we require either module or filename to be passed... since one or the other
# suffices, we forgo the usual "required => 1" and instead check that we have
# at least one of them after BUILDARGS has had a chance to run.

has module   => (is => 'ro', isa => Str, lazy_build => 1);
has filename => (is => 'ro', isa => File, coerce => 1, lazy_build => 1);

after BUILDARGS => sub {
    my $class = shift @_;

    my $args = ref $_[0] ? $_[0] : { @_ };
    die 'We require either module or filename, but neither was passed'
        unless exists $args->{module} || exists $args->{filename};

    return;
};

#############################################################################
# Our parsed META.yml

# pretty simplistic -- CPAN::Easy does most of the work here if we're passed
# a module, otherwise we just load and parse from the filename.

has _meta => (is => 'ro', lazy_build => 1, isa => 'HashRef');

sub _build__meta {
    my $self = shift @_;

    return CPAN::Easy->get_meta_for($self->module)
        if $self->has_module;

    die 'Need to implement loading from filename!';
    return;
}

#############################################################################
# Our scalar data

# we handle all of the items with only one value via one hash, and let Moose
# do the work by generating accessor methods.

# FIXME NOTE here and below, we should probably use a method to return the
# list rather than a lexical variable, so as to make it easier to inherit from
# this class.

my @scalars = qw{
    abstract distribution_type generated_by license name version
};

has _scalars => (
    traits => ['Hash'], is => 'ro', isa => 'HashRef[Str]', lazy_build => 1,
    handles =>
        { sub { map { $_ => [ get => $_ ], "has_$_" => [ exists => $_ ] } @scalars }->() },
);

sub _build__scalars { [ shift->_meta->{@scalars} ] }

#############################################################################
# Our key/value data

# handle all data with one-level key/value pairs; e.g. requires.

my @hashes = qw{
    build_requires configure_requires requires
};

for my $hash (@hashes) {

    has "_$hash" => (
        traits => ['Hash'], is => 'ro', isa => 'HashRef[Str]', lazy => 1,
        default => sub { shift->_meta->{$hash} || { } },
        handles => {
            "has_$hash" => 'count',             # has_foos
            "num_$hash" => 'count',             # num_foos
            $hash       => 'keys',              # foos
            $hash . '_value' => 'get',          # foos_value(x)
            "has_a_$hash" . '_on' => 'exists',  # has_a_foos_on(x)
        },
    );
}

#############################################################################
# "resources"

# Handle the resources section by providing direct exists/get accessors to the
# "official" keywords, as well as more generic access to all keywords that may
# exist.  Note that "license" is handled as "license_resource", so as to avoid
# conflicting with the license accessor above.
#
# Note also that while our values are URI's, we handle them as plain
# strings....  we might want to reevaluate this.

# license handled separately
my @resources = qw{ homepage bugtracker repository };

has _resources => (
    traits => ['Hash'], is => 'ro', isa => 'HashRef[Str]', lazy_build => 1,
    handles => {

        # conflicts otherwise...
        has_license_resource => [ exists => 'license' ],
        license_resource     => [ get    => 'license' ],

        # has_resource, (get) resource for all resources defined
        sub { map { +"has_$_" => [ exists => $_ ], $_ => [ get => $_ ] } @resources }->(),

        # generic
        has_resource   => 'exists',
        resource_value_of => 'get',
        resources      => 'keys',
        num_resources  => 'count',
        has_resources  => 'count',
    },
);

sub _build_resources { shift->_meta->{resources} || { } }

#############################################################################
# author / author info

has _authors => (
    traits => ['Array'], is => 'ro', isa => 'ArrayRef[Str]', lazy_build => 1,
    handles => {
        author  => [ get => 0 ],
        authors => 'elements',
        num_authors => 'count',
        has_authors => 'count',
        grep_authors => 'grep',
        map_authors  => 'map',
        join_authors => 'join',
        all_authors => [ join => ', ' ],
    },
);

sub _build__authors { shift->_meta->{authors} }

#############################################################################
# RPM requires/needs

# NOTE/FIXME we should probably break this out into a TraitFor style role

has _rpm_build_requires => (
    metaclass => 'Collection::ImmutableHash',

    is         => 'ro',
    isa        => 'HashRef[Str]',
    lazy_build => 1,

    provides => {
        #'' => '_rpm_build_requires',
        'count'  => 'num_rpm_build_requires',
        'empty'  => 'has_any_rpm_build_requires',
        'exists' => 'has_rpm_br_on',
        'keys'   => 'rpm_build_requires',
        'get'    => 'rpm_build_require_version',
        'kv'     => 'rpm_build_requires_kv_pairs',

        elements => 'full_rpm_build_requires',
    },
);

sub _build__rpm_build_requires {
    shift->_rpm_requires_from_meta_keys(
        qw(requires configure_requires build_requires)
    );
}

has _rpm_requires => (
    metaclass => 'Collection::ImmutableHash',

    is         => 'ro',
    isa        => 'HashRef[Str]',
    lazy_build => 1,

    provides => {
        #'' => '_rpm_build_requires',
        'count'  => 'num_rpm_requires',
        'empty'  => 'has_rpm_requires',
        'exists' => 'has_rpm_require_on',
        'keys'   => 'rpm_requires',
        'get'    => 'rpm_require_version',
        'kv'     => 'rpm_requires_kv_pairs',

        elements => 'full_rpm_requires',
    },
);

sub _build__rpm_requires {
    shift->_rpm_requires_from_meta_keys('requires')
}

sub _rpm_requires_from_meta_keys {
    my $self = shift @_;
    my @keys = @_;

    my %req = ();
    BR_LOOP:
    for my $key (@keys) {

        next BR_LOOP unless exists $self->_meta->[0]->{$key};
        my %more = %{ $self->_meta->[0]->{$key} };
        $req{"perl($_)"} = $more{$_} foreach keys %more;
        #%req = (%req, %more);
    }

    # until we figure out what to do with this...
    do{ delete $req{"perl($_)"} if exists $req{"perl($_)"} }
        foreach qw{ perl strict warnings overload attributes };

    ### %req
    return \%req;
}

__PACKAGE__->meta->make_immutable;

__END__

=head1 NAME

CPAN::MetaMuncher - Digest a META.yml

=head1 SYNOPSIS

    use CPAN::MetaMuncher;

    # ...
    my $mm = CPAN::MetaMuncher->new(module => $cpanplus_module);


=head1 DESCRIPTION

B<WARNING: This is VERY early code.>

An abstraction layer for META.yml, and possibly others.

=head1 SEE ALSO

L<CPANPLUS::Backend>

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



