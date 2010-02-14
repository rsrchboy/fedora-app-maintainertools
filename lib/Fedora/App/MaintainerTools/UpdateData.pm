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

package Fedora::App::MaintainerTools::UpdateData;

use Moose;
use namespace::autoclean;
use MooseX::AttributeHelpers;
use MooseX::Types::Moose ':all';
use MooseX::Types::URI   ':all';

use Fedora::App::MaintainerTools::Types ':all';

#use English qw{ -no_match_vars };  # Avoids regex performance penalty

use autodie qw{ system };

use CPAN::MetaMuncher;
use Config::Tiny;
use DateTime;
use File::Copy qw{ cp };
use List::MoreUtils qw{ any };
use Path::Class;
use RPM::VersionSort;

with 'MooseX::Log::Log4perl';

our $VERSION = '0.002';

# debugging
#use Smart::Comments '###', '####';

has conf => (is => 'rw', isa => 'Config::Tiny', lazy_build => 1);
# FIXME
sub _build_conf { Config::Tiny->read('auto.ini') || Config::Tiny->new }

has spec => (
    is => 'ro', isa => 'RPM::Spec', required => 1,
    # FIXME
    handles => [ qw{ license name summary } ],
    #handles => [ qw{ license name } ],
);
has dist => (is => 'ro', isa => 'Str', lazy_build => 1 );

sub _build_dist { 
    my $self = shift @_;
    
    # FIXME we should really allow for overrides here
    my $j = $self->spec->name;
    $j =~ s/^perl-//; 
    $j =~ s/\s+$//;

    return $j; 
}

has packager => (is => 'rw', isa => 'Str', lazy_build => 1);
sub _build_packager { chomp(my $p = `rpm --eval '%packager'`); $p }

has cpan_meta => (
    is => 'ro', isa => 'CPAN::MetaMuncher', lazy_build => 1,
    handles => [ 'version' ],
);
has cpanp     => (is => 'ro', isa => CPBackend, lazy_build => 1);
has module    => (is => 'ro', isa => CPModule,  lazy_build => 1);

sub _build_cpan_meta { CPAN::MetaMuncher->new(module => shift->module)     }
sub _build_cpanp  { require CPANPLUS::Backend; CPANPLUS::Backend->new       }
sub _build_module { my $s = shift; $s->cpanp->parse_module(module => $s->dist) }

has release => (is => 'rw', isa => Int, lazy_build => 1);
has source0 => (is => 'rw', isa => Str, lazy_build => 1);
has epoch   => (is => 'rw', isa => Int, lazy_build => 1);
sub _build_release { 1 }
sub _build_source0 { shift->spec->source0 }
sub _build_epoch   { shift->spec->epoch || 0}

has middle  => (
    metaclass => 'Collection::Array',
    is => 'rw', lazy_build => 1, isa => 'ArrayRef[Str]',

    provides => { elements => 'all_middle' },
);

sub _build_middle  { [ shift->spec->middle ] }

has is_noarch => (is => 'rw', isa => Bool, lazy_build => 1);

sub _build_is_noarch {
    my $self = shift @_;

    my $files = $self->module->parent->status->files;
    return do { first { /\.(c|xs)$/i } @$files } ? 0 : 1;
}


has changelog => (
    metaclass => 'Collection::Array',

    lazy       => 1,
    default    => sub { [ ] },
    auto_deref => 1,
    is         => 'ro',
    isa        => 'ArrayRef[Str]',

    provides => {
        empty   => 'has_changelog',
        push    => 'add_changelog',
        unshift => 'prepend_changelog',
    },
);

has spec_build_requires => (
    metaclass => 'Collection::Hash',

    is         => 'ro',
    isa        => 'HashRef',
    lazy_build => 1,

    provides => {
        'empty'  => 'has_build_requires',
        'exists' => 'has_build_require',
        'get'    => 'build_require_version',
        'set'    => 'build_require_this',
        'count'  => 'num_build_requires',
        'keys'   => 'build_requires',
        'delete' => 'remove_build_require_on',
        # set, etc...?
    },
);

sub _build_spec_build_requires { shift->spec->_build_requires }

has spec_requires => (
    metaclass => 'Collection::Hash',

    is         => 'ro',
    isa        => 'HashRef',
    lazy_build => 1,

    provides => {
        'empty'  => 'has_requires',
        'exists' => 'has_require',
        'get'    => 'require_version',
        'count'  => 'num_requires',
        'keys'   => 'requires',
        'set'    => 'require_this',
        # set, etc...?
    },
);

sub _build_spec_requires {

    # FIXME
    my $x = shift->spec->_requires;
    #delete $x->{'perl(:MODULE_COMPAT_%(eval >= -V:version`";'};
    do { delete $x->{$_} if $_ =~ /perl\(:MODULE_COMPAT/ }
        for keys %$x;
    return $x;
}

has content => (is => 'rw', isa => 'ArrayRef[Str]', lazy_build => 1);
# grap a copy, strip tail whitespace
sub _build_content { [ map { $_ =~ s/\s+$//; $_ } shift->spec->content ] }

sub add_new_with_tag {
    my ($self, $tag, $new) = @_;
    my @new = sort @$new;
    #$tag = "### auto-added $tag!";
    
    ### @new

    my $content = $self->content;

    if (@new && any { /^### $tag/ } @$content) {
        
        #unshift @new_brs, '### auto-added brs!';
        push  @new, q{};
        @$content = map { $_ =~ /^### $tag/ ? @new : $_ } @$content;
    }
    elsif (scalar @new) {
        
        # we may break this out in the future
        my $key = '%description';

        unshift @new, "### $tag";
        push @new, q{}, '%description';
        @$content = map { /^%description$/ ? @new : $_ } @$content;
    }

    $self->content($content);
    return;
}

__PACKAGE__->meta->make_immutable;

__END__

=head1 NAME

<Module::Name> - <One line description of module's purpose>

=head1 VERSION

The initial template usually just has:

This documentation refers to <Module::Name> version 0.0.1


=head1 SYNOPSIS

	use <Module::Name>;
	# Brief but working code example(s) here showing the most common usage(s)

	# This section will be as far as many users bother reading
	# so make it as educational and exemplary as possible.


=head1 DESCRIPTION

A full description of the module and its features.
May include numerous subsections (i.e. =head2, =head3, etc.)


=head1 SUBROUTINES/METHODS

A separate section listing the public components of the module's interface.
These normally consist of either subroutines that may be exported, or methods
that may be called on objects belonging to the classes that the module provides.
Name the section accordingly.

In an object-oriented module, this section should begin with a sentence of the
form "An object of this class represents...", to give the reader a high-level
context to help them understand the methods that are subsequently described.


=head1 DIAGNOSTICS

A list of every error and warning message that the module can generate
(even the ones that will "never happen"), with a full explanation of each
problem, one or more likely causes, and any suggested remedies.


=head1 CONFIGURATION AND ENVIRONMENT

A full explanation of any configuration system(s) used by the module,
including the names and locations of any configuration files, and the
meaning of any environment variables or properties that can be set. These
descriptions must also include details of any configuration language used.


=head1 DEPENDENCIES

A list of all the other modules that this module relies upon, including any
restrictions on versions, and an indication whether these required modules are
part of the standard Perl distribution, part of the module's distribution,
or must be installed separately.


=head1 INCOMPATIBILITIES

A list of any modules that this module cannot be used in conjunction with.
This may be due to name conflicts in the interface, or competition for
system or program resources, or due to internal limitations of Perl
(for example, many modules that use source code filters are mutually
incompatible).

=head1 SEE ALSO

L<...>

=head1 BUGS AND LIMITATIONS

A list of known problems with the module, together with some indication
whether they are likely to be fixed in an upcoming release.

Also a list of restrictions on the features the module does provide:
data types that cannot be handled, performance issues and the circumstances
in which they may arise, practical limitations on the size of data sets,
special cases that are not (yet) handled, etc.

The initial template usually just has:

There are no known bugs in this module.

Please report problems to Chris Weyl <cweyl@alumni.drew.edu>, or (preferred) 
to this package's RT tracker at E<bug-PACKAGE@rt.cpan.org>.

Patches are welcome.

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



