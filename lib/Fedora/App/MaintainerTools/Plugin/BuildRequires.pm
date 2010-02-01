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

package Fedora::App::MaintainerTools::Plugin::BuildRequires;

use strict;
use warnings;

use autodie qw{ system };

our $VERSION = '0.002';

#############################################################################
# order

sub _order { 15 }

#############################################################################
# event: perl_spec_prep

sub perl_spec_prep_order { 15 }

sub perl_spec_prep {


}

#############################################################################
# event: perl_spec_update 

sub perl_spec_update_order { 15 }

sub perl_spec_update {
    my ($self, $data) = @_;

    warn 'in br-update';

    ##############################################################
    # BR info (should be refactored)

    my $mm    = $data->cpan_meta;
    my $spec  = $data->spec;
    my @lines = @{ $data->content };

    my (@new_brs, @cl);
    NEW_BR_LOOP:
    for my $br (sort $mm->rpm_build_requires) {

        my $new = $mm->rpm_build_require_version($br);

        if ($spec->has_build_require($br)) {
        
            my $old = $spec->build_require_version($br);
            next NEW_BR_LOOP if $new eq '0' || $old eq $new;

            # otherwise, update and clog it
            (my $br_re = $br) =~ s/\(/\\(/g;
            $br_re            =~ s/\)/\\)/g;
            @lines = 
                map { 
                    if ($_ =~ /^BuildRequires:\s*$br_re/) {
                    
                        $_ =~ s/\S+$/$new/ if $_ !~ /$br_re$/;
                        $_ .= " >= $new"   if $_ =~ /$br_re$/;
                    }
                    $_;
                }
                @lines
                ;
            push @cl, "- altered br on $br ($old => $new)";
            next NEW_BR_LOOP;
        }

        # if we're here, it's a new BR
        push @new_brs, $new 
                     ? "BuildRequires:  $br >= $new" 
                     : "BuildRequires:  $br"
                     ;
        push @cl, "- added a new br on $br (version $new)";
    }

    $data->content(\@lines);
    $data->add_new_with_tag('auto-added brs!', \@new_brs) if @new_brs;
    $data->add_changelog(@cl);
    return;
}

1;

__END__

=head1 NAME

Fedora::App::MaintainerTools::Plugin::BuildRequires - Update BR's

=head1 DESCRIPTION

This plugin handles the "perl_spec_update" event, updating or adding
buildrequires to the spec file as needed.

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



