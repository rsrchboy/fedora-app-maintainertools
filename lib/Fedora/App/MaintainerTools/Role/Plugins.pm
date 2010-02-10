#############################################################################
#
# Simple role to provide access to the plugin system
#
# Author:  Chris Weyl (cpan:RSRCHBOY), <cweyl@alumni.drew.edu>
# Company: No company, personal work
# Created: 06/16/2009
#
# Copyright (c) 2009-2010  <cweyl@alumni.drew.edu>
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
#############################################################################

package Fedora::App::MaintainerTools::Role::Plugins;

use Moose::Role;
use MooseX::Types::Moose ':all';
use namespace::autoclean;

our $VERSION = '0.002';

#use Fedora::App::MaintainerTools::Types ':all';
#sub plugin_pkg { 'Fedora::App::MaintainerTools::Plugins' }

has _plugins => (
    is => 'ro', isa => Object, lazy_build => 1,
    handles => [ qw{ plugins call_plugins } ],
);

sub _build__plugins { Fedora::App::MaintainerTools::Plugins->new }

before run => sub {

    Class::MOP::load_class($_) for qw{
        Fedora::App::MaintainerTools::Plugins
        Fedora::App::MaintainerTools::UpdateData
    };
};

1;

__END__

=head1 NAME

Fedora::App::MaintainerTools::Role::Plugins - Access the plugin system

=head1 SYNOPSIS

use <Module::Name>;
# Brief but working code example(s) here showing the most common usage(s)

# This section will be as far as many users bother reading
# so make it as educational and exemplary as possible.


=head1 DESCRIPTION

This is a L<Moose::Role> that command classes should consume in order to
access the plugin system.

=head1 AUTHOR

Chris Weyl  <cweyl@alumni.drew.edu>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2009  <cweyl@alumni.drew.edu>

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

