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
use MooseX::Types::Moose ':all';
use MooseX::Types::Path::Class ':all';
use namespace::autoclean;
use Path::Class;

extends 'MooseX::App::Cmd::Command';
with 'Fedora::App::MaintainerTools::Role::Plugins';

# classes we need but don't want to load a compile-time
my @CLASSES = qw{
    DateTime
    File::ShareDir
    RPM::Spec
    Template

    Fedora::App::MaintainerTools::SpecData::New
};

our $VERSION = '0.002';

has package => (is => 'ro', isa => Bool, default => 0);

has share_dir => (is => 'ro', isa => Dir, coerce => 1, lazy_build => 1);

sub command_names { 'new-spec' }

sub run {
    my ($self, $opt, $args) = @_;

    $self->app->log->info('Beginning new-spec run.');

    Class::MOP::load_class($_) for @CLASSES;

    for my $pkg (@$args) {

        my $data =
            Fedora::App::MaintainerTools::SpecData::New->new(dist => $pkg);

        my $tmpl = 'perl/spec.tt2';
        my $tt2 = Template->new({ INCLUDE_PATH => $self->share_dir });

        print $tt2->process($tmpl, {
            data      => $data,
            rpm_date  => DateTime->now->strftime('%a %b %d %Y'),
            changelog => join("\n", $data->changelog),

            #old_changelog => join("\n", $data->spec->changelog),

            #middle => join("\n", $data->all_middle),

            # FIXME
            packager => 'Chris Weyl <cweyl@alumni.drew.edu>',
        }) || die $tt2->error . "\n";

    }

    return;
}

sub _build_share_dir {
    my $self = shift @_;

    my $dir = dir qw{ .. share };

    return $dir->absolute if $dir->stat;
    return File::ShareDir::dist_dir('Fedora-App-MaintainerTools');
}

__PACKAGE__->meta->make_immutable;

__END__

=head1 NAME

Fedora::App::MaintainerTools::Command::updatespec - Update a spec to latest GA version from the CPAN

=head1 DESCRIPTION

Updates a spec file with metadata from the CPAN.


=head1 SEE ALSO

L<Fedora::App::MaintainerTools>

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



