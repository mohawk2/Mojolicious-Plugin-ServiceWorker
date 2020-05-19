use Mojo::Base -strict;

use Test::More;
use Mojolicious::Lite;
use Test::Mojo;

plugin 'ServiceWorker' => {
  route_sw => '/sw2.js',
  precache_urls => [
  ],
};

my $t = Test::Mojo->new;
subtest 'sw' => sub {
  $t->get_ok('/sw2.js')->status_is(200)->content_like(qr/self\.addEventListener/);
};

done_testing();
