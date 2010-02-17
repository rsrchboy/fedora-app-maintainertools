#############################################################################
#
# Simple role to provide access to Bugzilla
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

package Fedora::App::MaintainerTools::Role::SpecUtils;

use Moose::Role;
use namespace::autoclean;
use MooseX::Types::Moose ':all';

use MooseX::Traits::Util 'new_class_with_traits';

# debugging
#use Smart::Comments '###', '####';

our $VERSION = '0.002';

requires '_specdata_base_class';

has _specdata_class =>  (is => 'rw', isa => Str, lazy_build => 1);
has _specdata_traits => (is => 'rw', isa => 'ArrayRef[Str]', lazy_build => 1);

sub _build__specdata_traits {
    my $self = shift @_;

    Class::MOP::load_class('Module::Find');

    #my $class = 'Fedora::App::MaintainerTools::SpecData::New';
    my $class = $self->_specdata_base_class;
    my @traits = Module::Find::findsubmod($class.'::Traits');

    ### $class
    ### @traits
    return \@traits;
}

sub _build__specdata_class {
    my $self = shift @_;

    return
        new_class_with_traits(
            $self->_specdata_base_class,
            @{ $self->_specdata_traits },
        )
        ->name
        ;
}

1;

__END__

=head1 NAME

Fedora::App::MaintainerTools::Role::SpecUtils - Command role to get our data
class

=head1 DESCRIPTION

This is a L<Moose::Role> that command classes should consume in order to
properly create other classes with traits (that is, create certain classes of
ours with plugins/extensions pulled in dynamically).

=head1 AUTHOR

Chris Weyl  <cweyl@alumni.drew.edu>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2010 <cweyl@alumni.drew.edu>

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

