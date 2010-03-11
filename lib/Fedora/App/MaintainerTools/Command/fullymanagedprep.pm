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

package Fedora::App::MaintainerTools::Command::fullymanagedprep;

use Moose;
use MooseX::Types::Moose ':all';
use MooseX::Types::Path::Class ':all';
use namespace::autoclean;
use File::Copy 'cp';
use Path::Class;

use Smart::Comments '###', '####';

extends 'MooseX::App::Cmd::Command';
with 'Fedora::App::MaintainerTools::Role::Logger';
with 'Fedora::App::MaintainerTools::Role::Template';
with 'Fedora::App::MaintainerTools::Role::SpecUtils';

# classes we need but don't want to load a compile-time
my @CLASSES = qw{
    Config::IniFiles
};

our $VERSION = '0.006';

has inifile => (is => 'rw', isa => File, coerce => 1, default => 'auto.ini');

sub command_names { 'fully-managed-prep' }

sub execute {
    my ($self, $opt, $args) = @_;

    my %ini_defaults = (-commentchar => ';');

    $self->log->info('Beginning update-spec run.');
    Class::MOP::load_class($_) for @CLASSES;
    my $dir = dir->absolute;
    my $log = $self->log;

    for my $filename (@$args) {

        $log->info("working on: $filename");
        my $file = file $filename;
        my @lines =
            map { s/^\s*//; s/\s*$//; chomp; $_ }
            split /\n/, $file->slurp;

        my ($inifile, $ini) = ($self->inifile, undef);
        if ($inifile->stat) {

            $log->info("attempting to update existing ini file.");
            $ini = Config::IniFiles->new(-file => "$inifile", %ini_defaults);
        }
        else {

            $log->info("creating new ini file");
            $ini = Config::IniFiles->new;
            $ini->SetFileName($inifile, %ini_defaults);
        }

        # Ok, so now we pretty much do a VERY primitive loop over @lines, and
        # write out the chunks to the .ini.  If any of the sections are out of
        # order, or wonky, then our output is going to be wonky.

        my @sections =
            qw{ description prep build install check clean files changelog };
        my @watch = map { "%$_" } @sections;
        my $i = 0;
        my (@ini_sections, @current);

        for my $line (@lines) {

            #do { shift @watch; next } if $line eq $watch[0]
            do { $ini_sections[$i++] = [@current]; @current = (); next }
                if $line eq $watch[$i];

            push @current, $line;
        }

        ### @ini_sections

        # ditch the preamble
        shift @ini_sections;

        # add the description verbatim
        $ini->newval(spec_description => content => shift @ini_sections);

        # now prep, but it gets split...
        my @prep = @{ shift @ini_sections };
        my $setup = shift @prep;
        $ini->newval(spec_prep => setup_line  => $setup);
        $ini->newval(spec_prep => use_custom_prep => 1);
        $ini->newval(spec_prep => custom_prep => [ @prep ]);

        # build
        # install
        # check
        # clean
        # files

        for my $sec (qw{ build install check clean files }) {

            $ini->newval("spec_$sec" => use_custom => 1);
            $ini->newval("spec_$sec" => custom => shift @ini_sections);

            $ini->SetParameterComment("spec_$sec" => use_custom =>
                'Set to 0 or delete section to use the default');
        }

        $ini->newval(common => is_fully_managed => 1);
        $ini->SetParameterComment(common => is_fully_managed =>
            'Set to 0 to DISABLE all description/prep/build/etc management.');

        $ini->RewriteConfig;
    }

    return;
}

__PACKAGE__->meta->make_immutable;

__END__

=head1 NAME

Fedora::App::MaintainerTools::Command::fullymanagedprep

=head1 DESCRIPTION

Prepare an auto.ini for fully-managed spec file updates.

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



