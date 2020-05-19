use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  NAME         => 'Mojolicious::Plugin::ServiceWorker',
  VERSION_FROM => 'lib/Mojolicious/Plugin/ServiceWorker.pm',
  AUTHOR       => 'A Good Programmer <nospam@cpan.org>',
  PREREQ_PM    => {'Mojolicious' => '8.42'},
  test         => {TESTS => 't/*.t'}
);
