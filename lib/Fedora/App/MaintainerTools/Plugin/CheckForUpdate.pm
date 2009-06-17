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

package Fedora::App::MaintainerTools::Plugin::CheckForUpdate;

use strict;
use warnings;

use autodie qw{ system };
use RPM::VersionSort;

use namespace::clean;

our $VERSION = '0.001';

#############################################################################
# order

sub _order { 10 }

#############################################################################
# event: perl_spec_update 

sub perl_spec_update_order { 10 }

sub perl_spec_update {
    my ($self, $data) = @_;

    warn 'in check for version';

    my $m       = $data->module;
    my $mm      = $data->cpan_meta;
    my $old_v   = $data->spec->version;
    my ($v, $r) = ($mm->version, '1%{?dist}');
    my @cl;
    my @lines = @{ $data->content };

    if ($old_v eq $v) {

        # this isn't a version update, so bump release
        (my $nr = $r) =~ s/\D+$//;
        $r++;
        $r = "$r%{?dist}";
    }
    else {

        # we need to update version and release
        my $s = 'http://search.cpan.org/CPAN/' . $m->path . '/' 
            . $m->package_name . '-%{version}.' . $m->package_extension
            ;
        @lines =  map { /^Source(0|):/i && $_ =~ s/\S+$/$s/; $_ } @lines;

        if (rpmvercmp($old_v, $v) == 1) {

            # rpm is going to think that the old version is larger than the new
            # one, so we're going to need to fiddle with the epoch here
            if ($self->epoch) {
                my $e = $self->epoch + 1;
                @lines = map { /^Epoch:/i && $_ =~ s/\S+$/$e/; $_ } @lines;

                push @cl, "- Bump epoch to $e ($old_v => $v)";
            }
            else {
                @lines = map { /^Version:/i ? ('Epoch: 1', $_) : $_ } @lines;
                push @cl, "- Add epoch of 1 ($old_v => $v)";
            }
        }
    }
    
    @lines = 
        map { /^Version:/i && $_ =~ s/\S+$/$v/; $_    }
        map { /^Release:/i && $_ =~ s/\S+$/$r/; $_    }
        @lines
        ;
    
    $data->add_changelog(@cl);
    $data->content(\@lines);
    return;
}    

1;

__END__

=head1 NAME

Fedora::App::MaintainerTools::Plugin::CheckForUpdate - Check the CPAN for updates

=head1 DESCRIPTION

This plugin checks the CPAN to see if there's a GA version we should be
updating to.  If not, we just bump the release; if so, we reset release to 1,
update the Source0 line (as the uploading author may have changed), and update
the version.  Additionally, if we're updating we check to make sure an epoch
bump isn't required.

=head1 PLUGIN ORDER

10.

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

