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

use Path::Class;

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

    my $module = $mm->module;

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

            $data->build_require_this($br => $new);
            push @cl, "- altered br on $br ($old => $new)";
            next NEW_BR_LOOP;
        }

        # if we're here, it's a new BR
        push @new_brs, _br($br => $new);
        $data->build_require_this($br => $new);
        push @cl, "- added a new br on $br (version $new)";
    }

    # delete stale build requirements
    PURGE_BR_LOOP:
    for my $br ($data->build_requires) {

        # not ideal, but WFN.
        next PURGE_BR_LOOP
            if $br !~ /^perl\(/ || $br eq 'perl(CPAN)';

        next PURGE_BR_LOOP if $br =~ /^perl\(:MODULE_COMPAT/;
        next PURGE_BR_LOOP if exists $data->conf->{add_build_requires}->{$br};

        # check to see META.yml lists it as a dep.  if not, purge.
        unless ($mm->has_rpm_br_on($br)) {

            #(my $line = _br($br)) =~ s/:\s+/:\\s+/;
            #warn "line: $line";
            @lines = grep { !/^BuildRequires:\s+$br/ } @lines;

            $data->remove_build_require_on($br);
            push @cl, "- dropped old BR on $br";
        }
    }

    for my $manual_br (keys %{$data->conf->{add_build_requires}}) {

        next if $data->has_build_require($manual_br);

        # FIXME versions??
        my $ver = $data->conf->{add_build_requires}->{$manual_br};
        $data->build_require_this($manual_br => $ver);
        push @new_brs, _br($manual_br => $ver);
        push @cl, "- added manual BR on $manual_br";
    }

    # check for inc::Module::AutoInstall; force br CPAN if so *sigh*
    my $mdir = dir($module->status->extract || $module->extract);
    if (file($mdir, qw{ inc Module AutoInstall.pm })->stat) {

        warn "inc::Module::AutoInstall found; BR'ing CPAN\n";

        if (!$data->has_build_require('perl(CPAN)') &&
        !$mm->has_rpm_br_on('perl(CPAN)')) {

            push @new_brs, _br('perl(CPAN)');
            push @cl, '- added a new br on CPAN (inc::Module::AutoInstall found)';
        }
    }

    $data->content(\@lines);
    $data->add_new_with_tag('auto-added brs!', \@new_brs) if @new_brs;

    my @new_reqs;
    NEW_REQ_LOOP:
    for my $r (sort $mm->rpm_requires) {

        my $new = $mm->rpm_require_version($r);

        if ($data->has_require($r)) {

            my $old = $data->require_version($r);
            next NEW_REQ_LOOP if $new eq '0' || $old eq $new;

            # otherwise, update and clog it
            (my $r_re = $r) =~ s/\(/\\(/g;
            $r_re            =~ s/\)/\\)/g;
            @lines =
                map {
                    if ($_ =~ /^Requires:\s*$r_re/) {

                        $_ =~ s/\S+$/$new/ if $_ !~ /$r_re$/;
                        $_ .= " >= $new"   if $_ =~ /$r_re$/;
                    }
                    $_;
                }
                @lines
                ;
            push @cl, "- altered req on $r ($old => $new)";
            next NEW_REQ_LOOP;
        }

        # if we're here, it's a new BR
        $data->require_this($r => $new);
        push @new_reqs, _req($r => $new);
        push @cl, "- added a new req on $r (version $new)";
    }

    # delete stale build requirements
    PURGE_R_LOOP:
    for my $req ($data->requires) {

        # make sure it's a _perl_ requires
        next PURGE_R_LOOP unless $req =~ /^perl\(/;

        # check to see META.yml lists it as a dep.  if not, purge.
        unless ($mm->has_rpm_require_on($req)) {

            $data->remove_build_require_on($req);
            push @cl, "- dropped old requires on $req";
        }
    }

    $data->add_new_with_tag('auto-added reqs!', \@new_reqs, \@lines);

    # fix up middle -- PERL_INSTALL_ROOT mainly
    my @middle;

    for my $line ($data->all_middle) {

        if ($line eq 'make pure_install PERL_INSTALL_ROOT=%{buildroot}') {

            $line = 'make pure_install DESTDIR=%{buildroot}';
            push @cl, '- PERL_INSTALL_ROOT => DESTDIR';
        }

        push @middle, $line;
    }

    $data->middle(\@middle);

    $data->add_changelog(@cl);
    return;
}

sub _suspect_req { shift =~ /^perl\(Test::/ }

sub _br  { _tag('BuildRequires', @_) }
sub _req { _tag('Requires', @_)      }

sub _tag {
    my ($tag, $val, $ver) = @_;

    return $ver
         ? "$tag:  $val >= $ver"
         : "$tag:  $val"
         ;
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



