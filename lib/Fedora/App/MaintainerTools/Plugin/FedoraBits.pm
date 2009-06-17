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

package Fedora::App::MaintainerTools::Plugin::FedoraBits;

use strict;
use warnings;

use autodie qw{ system };

our $VERSION = '0.001';

#############################################################################
# order

sub _order { 90 }

#############################################################################
# event: perl_spec_update 

sub perl_spec_update_order { 90 }

sub perl_spec_update {
    my ($self, $data) = @_;

    # ... we do nothing at the moment
    $data->log->info('In plugin: FedoraBits');

    #if (file('Makefile')->stat) {
    #if (-e 'Makefile') {
    if (0) {

        warn "Copying new tarball over...\n";
        my $tarball = file($m->status->fetch)->basename;
        #my $cmd = "cd $pwd && make new-source FILES=" . $to->basename . ' 1>&2';
        my $cmd = "cd $pwd && make new-source FILES=$tarball 1>&2";
        warn "executing: $cmd\n";
        system $cmd; 
    }

    return;
}    


1;

__END__

=head1 NAME

<Module::Name> - <One line description of module's purpose>

=head1 DESCRIPTION

This plugin handles Fedora-specific bits of updating a spec file.

=head1 PLUGIN ORDER

90.

=head1 SEE ALSO

L<Fedora::App::MaintainerTools>>

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



