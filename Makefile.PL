use inc::Module::Install;

name     'Fedora-App-MaintainerTools';
all_from 'lib/Fedora/App/MaintainerTools.pm';
author   'Chris Weyl <cweyl@alumni.drew.edu>';
license  'perl';

requires_external_bin 'rpm';

requires 'autodie';
requires 'namespace::clean';

# silent autodie dep
requires 'IPC::System::Simple';

requires 'Moose';
requires 'MooseX::App::Cmd';
requires 'MooseX::AttributeHelpers';
requires 'MooseX::Log::Log4perl';
requires 'MooseX::Types';
requires 'MooseX::Types::Path::Class';

requires 'CPANPLUS::Backend';
requires 'DateTime';
requires 'File::Copy';
requires 'Path::Class';
requires 'RPM::Spec';
requires 'YAML::Tiny';

test_requires 'Test::More';

install_script 'scripts/maintainertool';

extra_tests;
auto_provides;
auto_install;
write_mymeta_json;

WriteAll;

