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

package Fedora::App::MaintainerTools::SpecData::New;

use Moose;
#use MooseX::AttributeHelpers;
#use MooseX::Types::Moose ':all';
#use MooseX::Types::URI   ':all';

use namespace::autoclean;
#use autodie qw{ system };

#use Fedora::App::MaintainerTools::Types ':all';

#use CPAN::MetaMuncher;
#use Config::Tiny;
use DateTime;
use File::Basename;
#use File::Copy qw{ cp };
#use List::MoreUtils qw{ any };
#use Path::Class;
use Pod::POM;
use Pod::POM::View::Text;
#use RPM::VersionSort;
use Text::Autoformat;

extends 'Fedora::App::MaintainerTools::SpecData';

our $VERSION = '0.002';

# debugging
#use Smart::Comments '###', '####';

sub _build_name { 'perl-' . shift->dist }

sub _build__build_requires { my %x = shift->mm->full_rpm_build_requires; \%x }
sub _build__requires       { my %x = shift->mm->full_rpm_requires;       \%x }

sub _build__changelog      {

    #my $dt = DateTime->now->strftime('%a %b %d %Y');
    #my $v  = shift->version;

    #'%changelog',
    #"* $dt $packager $v-1"

    [ "- specfile by Fedora::App::MaintainerTools $Fedora::App::MaintainerTools::VERSION" ]
}

sub _build_version { shift->mm->data->{version} }
#sub _build_version { shift->module->version }

sub _build_summary {
    # FIXME this is probably broken for most modules
    shift->mm->data->{abstract};
}

has description => (is => 'rw', isa => 'Str', lazy_build => 1);

#
# given a cpanplus::module, try to extract its description from the
# embedded pod in the extracted files. this would be the first paragraph
# of the DESCRIPTION head1.
#
sub _build_description {
    my $self = shift @_;

    my $module = $self->module;

    # where tarball has been extracted
    my $path   = dirname $module->_status->extract;
    my $parser = Pod::POM->new;

    my @docfiles =
        map  { "$path/$_" }               # prepend extract directory
        sort { length $a <=> length $b }  # sort by length
        grep { /\.(pod|pm)$/ }            # filter potentially pod-containing
        @{ $module->_status->files };     # list of embedded files

    my $desc;

    # parse file, trying to find a header
    DOCFILE:
    foreach my $docfile ( @docfiles ) {

        # extract pod; the file may contain no pod, that's ok
        my $pom = $parser->parse_file($docfile);
        next DOCFILE unless defined $pom;

        HEAD1:
        foreach my $head1 ($pom->head1) {

            next HEAD1 unless $head1->title eq 'DESCRIPTION';

            my $pom  = $head1->content;
            my $text = $pom->present('Pod::POM::View::Text');

            # limit to 3 paragraphs at the moment
           my @paragraphs = (split /\n\n/, $text)[0..2];
            #$text = join "\n\n", @paragraphs;
            $text = q{};
            for my $para (@paragraphs) { $text .= $para }

            # autoformat and return...
            return autoformat $text, { all => 1 };
        }
    }

    return 'no description found';
}

__PACKAGE__->meta->make_immutable;

__END__

=head1 NAME

Fedora::App::MaintainerTools::SpecData::New - Prepare data for the generation
of a new specfile

=head1 SYNOPSIS

	use <Module::Name>;
	# Brief but working code example(s) here showing the most common usage(s)

	# This section will be as far as many users bother reading
	# so make it as educational and exemplary as possible.


=head1 DESCRIPTION

This package extends L<Fedora::App::MaintainerTools::SpecData> to gather data
from the CPAN (and a dist's META.yml) to generate a RPM specfile.

=head1 ATTRIBUTES

We define the additional attributes:

=head2 description


=head1 OVERRIDDEN BUILDERS

We override a number of builder methods to provide the correct data.  (If
you're really interested in them, you should probably read the source :))

=head1 SEE ALSO

L<Fedora::App::MaintainerTools>, L<Fedora::App::MaintainerTools::SpecData>,
L<CPANPLUS::Dist::RPM>

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



