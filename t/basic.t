use Mojo::Base -strict;

use Test::More;
use Mojolicious::Lite;
use Test::Mojo;

my $t = Test::Mojo->new;
plugin 'ServiceWorker' => {
  route_sw => '/sw2.js',
};
subtest 'other route' => sub {
  $t->get_ok('/serviceworker.js')->status_is(404);
  $t->get_ok('/sw2.js')->status_is(200)->content_like(qr/self\.addEventListener/);
  my $got = app->serviceworker->config;
  is_deeply $got, { precache_urls => [ '/sw2.js' ] } or diag explain $got;
  is app->serviceworker->route, '/sw2.js';
};

plugin 'ServiceWorker' => {
  precache_urls => [ 'js/important.js', '' ],
};
subtest 'default route' => sub {
  $t->get_ok('/serviceworker.js')->status_is(200)->content_like(qr/self\.addEventListener/);
  my $got = app->serviceworker->config;
  is_deeply $got, {
    precache_urls => [ 'js/important.js', '', '/serviceworker.js' ],
  } or diag explain $got;
  is app->serviceworker->route, '/serviceworker.js';
};

done_testing();
