use inc::Module::Install;

name      'Game-LL';
author    'Lee Aylward <leedo@cpan.org>';
version   '0.01';
license   'perl';
perl_version '5.01';

all_from  'lib/Game/LL.pm';

requires  'Plack' => 0;
requires  'Plack::Middleware::Session' => 0;
requires  'JSON' => 0;
requires  'Any::Moose' => 0;
requires  'Text::MicroTemplate' => 0;
requires  'Digest::SHA1' => 0;
requires  'Path::Class' => 0;
requires  'List::MoreUtils' => 0;
requires  'DBIx::Class' => 0;
requires  'DBD::SQLite' => 0;

test_requires 'Test::More' => 0;

install_share;
WriteAll;
