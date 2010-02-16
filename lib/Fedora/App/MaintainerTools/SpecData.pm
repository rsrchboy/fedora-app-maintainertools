#############################################################################
#
# Keep track of updates to our spec file...
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

package Fedora::App::MaintainerTools::SpecData;

use Moose;
use MooseX::AttributeHelpers;
use MooseX::Types::Moose ':all';
use MooseX::Types::Path::Class ':all';
use MooseX::Types::URI ':all';

use autodie 'system';
use namespace::autoclean;

use Fedora::App::MaintainerTools::Types ':all';

with 'Fedora::App::MaintainerTools::Role::Template';

use CPAN::MetaMuncher;
use Config::Tiny;
use DateTime;
use File::Copy 'cp';
use List::Util 'first';
use List::MoreUtils 'any';
use Path::Class;
use RPM::VersionSort;
use Software::LicenseUtils;

our $VERSION = '0.002';

# debugging
#use Smart::Comments '###', '####';

#############################################################################
# required

# e.g. "Moose", "Catalyst-Runtime", etc
#has dist => (is => 'ro', isa => 'Str', required => 1);
has dist => (is => 'ro', isa => 'Str', lazy_build => 1);

# we're required for new specs, but not for updates, so I don't want to mark
# the attribute as required, but I do want things to blow up if it hasn't been
# set.  So for descendents that can get it elsewhere can just override
# _build_dist() appropriately.

sub _build_dist { die 'dist is not set, and is required!' }

#############################################################################
# CPAN bits, etc

has conf   => (is => 'rw', isa => 'Config::Tiny', lazy_build => 1);
has mm     => (is => 'ro', isa => 'CPAN::MetaMuncher', lazy_build => 1);
has cpanp  => (is => 'ro', isa => CPBackend, lazy_build => 1);
has module => (is => 'ro', isa => CPModule,  lazy_build => 1);

sub _build_conf   { Config::Tiny->read('auto.ini') || Config::Tiny->new }
sub _build_mm     { CPAN::MetaMuncher->new(module => shift->module)     }
sub _build_cpanp  { require CPANPLUS::Backend; CPANPLUS::Backend->new   }
sub _build_module { my $s = shift; $s->cpanp->parse_module(module => $s->dist) }

#############################################################################
# generated spec data, etc

has packager  => (is => 'rw', lazy_build => 1, isa => Str);
has name      => (is => 'rw', lazy_build => 1, isa => Str);
has version   => (is => 'rw', lazy_build => 1, isa => Str);
has release   => (is => 'rw', lazy_build => 1, isa => Int);
has summary   => (is => 'rw', lazy_build => 1, isa => Str);
has source0   => (is => 'rw', lazy_build => 1, isa => Str);
has epoch     => (is => 'rw', lazy_build => 1, isa => 'Maybe[Int]');
has is_noarch => (is => 'rw', lazy_build => 1, isa => Bool);
has url       => (is => 'rw', lazy_build => 1, isa => Uri, coerce => 1);
has license   => (is => 'rw', lazy_build => 1, isa => Str);

has _changelog => (
    traits => [ 'MooseX::AttributeHelpers::Trait::Collection::Array' ],
    is => 'ro', isa => 'ArrayRef[Str]', lazy_build => 1,

    provides => {
        empty    => 'has_changelog',
        push     => 'add_changelog',
        unshift  => 'prepend_changelog',
        elements => 'changelog',
    },
);

has _build_requires => (
    traits => [ 'MooseX::AttributeHelpers::Trait::Collection::Hash' ],
    is => 'ro', isa => 'HashRef', lazy_build => 1,

    provides => {
        'empty'  => 'has_build_requires',
        'exists' => 'has_build_require',
        'get'    => 'build_require_version',
        'set'    => 'build_require_this',
        'count'  => 'num_build_requires',
        'keys'   => 'build_requires',
        'delete' => 'remove_build_require_on',
        'kv'     => 'build_require_pairs',
    },
);

has _requires => (
    traits => [ 'MooseX::AttributeHelpers::Trait::Collection::Hash' ],
    is => 'ro', isa => 'HashRef', lazy_build => 1,

    provides => {
        'empty'  => 'has_requires',
        'exists' => 'has_require',
        'get'    => 'require_version',
        'count'  => 'num_requires',
        'keys'   => 'requires',
        'set'    => 'require_this',
        'kv'     => 'require_pairs',
    },
);

#############################################################################
# attribute builder methods

sub _build_packager { chomp(my $p = `rpm --eval '%packager'`); $p }
sub _build_release  { 1 }
sub _build_epoch    { undef }
sub _build_url      { 'http://search.cpan.org/dist/' . shift->dist }

sub _build_source0  {
    my $self = shift @_;

    return 'http://search.cpan.org/CPAN/'
        . $self->module->path . '/'
        . $self->dist . '-'
        . $self->version . $self->module->package_extension
        ;
}

sub _build_is_noarch {
    my $self = shift @_;

    my $files = $self->module->status->files;
    return do { first { /\.(c|xs)$/i } @$files } ? 0 : 1;
}

sub _build_license {
    my $self = shift @_;

    warn 'not implemented!';

    return 'CHECK(GPL+ or Artistic)';
}

sub _build_summary         { die 'not implemented' }
sub _build__changelog      { die 'not implemented' }
sub _build__build_requires { die 'not implemented!' }
sub _build__requires       { die 'not implemented!' }

#############################################################################
# template bits

# aka, what we use to generate the spec files

has template => (is => 'rw', isa => File, coerce => 1, lazy_build => 1);
has output   => (is => 'ro', isa => Str, lazy_build => 1);

sub _build_template { 'perl/spec.tt2' }

sub _build_output {
    my $self = shift @_;

    my $output;
    my $res = $self->_tt2->process(
        $self->template->stringify, {
            data      => $self,
            rpm_date  => DateTime->now->strftime('%a %b %d %Y'),
         },
         \$output,
     );

     die $self->_tt2->error . "\n" unless $res;
     return $output;
}

#############################################################################
# srpm/rpm building...


sub build_srpm {

    die "build_srpm not implemented\n";

    my ($dir, $rpmbuild, $spec, $buildrpm);

    # From Fedora CVS Makefile.common.
    system($rpmbuild, "--define", "_sourcedir $dir",
                          "--define", "_builddir $dir",
                          "--define", "_srcrpmdir $dir",
                          "--define", "_rpmdir $dir",
                          #($buildrpm ? "-ba" : ("-bs", "--nodeps")),
                          $spec);

}

__PACKAGE__->meta->make_immutable;

__END__

=head1 NAME

Fedora::App::MaintainerTools::SpecData - Collect the data needed for working
with a spec file

=head1 DESCRIPTION



=head1 ATTRIBUTES

...

=head1 INCOMPATIBILITIES

This class is not meant to be used directly; instead it should be subclassed
as needed.

=head1 SEE ALSO

L<Fedora::App::MaintainerTools>

=head1 AUTHOR

Chris Weyl  <cweyl@alumni.drew.edu>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2010 Chris Weyl <cweyl@alumni.drew.edu>

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



