package Mojolicious::Plugin::ServiceWorker;
use Mojo::Base 'Mojolicious::Plugin';
use Mojo::JSON;

our $VERSION = '0.01';

my $SW_URL = '/serviceworker.js';
my @COPY_KEYS = qw(debug precache_urls network_only cache_only network_first);

sub register {
  my ($self, $app, $conf) = @_;
  my %config = %{ $conf || {} };
  my $sw_route = $conf->{route_sw} || $SW_URL;
  my $r = $app->routes;
  $r->get($sw_route => sub {
    my ($c) = @_;
    $c->render(template => 'serviceworker', format => 'js');
  }, 'serviceworker.route');
  $app->helper('serviceworker.route' => sub { $sw_route });
  $config{precache_urls} = [
    @{ $config{precache_urls} || [] },
    $sw_route,
  ];
  my %config_copy = map {$config{$_} ? ($_ => $config{$_}) : ()} @COPY_KEYS;
  $app->helper('serviceworker.config' => sub { \%config_copy });
  push @{ $app->renderer->classes }, __PACKAGE__;
  $self;
}

1;

=encoding utf8

=head1 NAME

Mojolicious::Plugin::ServiceWorker - plugin to add a Service Worker

=head1 SYNOPSIS

  # Mojolicious::Lite
  plugin 'ServiceWorker' => {
    route_sw => '/sw2.js',
    precache_urls => [
    ],
  };

=head1 DESCRIPTION

L<Mojolicious::Plugin::ServiceWorker> is a L<Mojolicious> plugin.

=head1 METHODS

L<Mojolicious::Plugin::ServiceWorker> inherits all methods from
L<Mojolicious::Plugin> and implements the following new ones.

=head2 register

  my $p = $plugin->register(Mojolicious->new, \%conf);

Register plugin in L<Mojolicious> application, returning the plugin
object. Takes a hash-ref as configuration, see L</OPTIONS> for keys.

=head1 OPTIONS

=head2 route_sw

The service worker route. Defaults to C</serviceworker.js>. Note that
you need this to be in your app's top level, since the service worker
can only affect URLs at or below its "scope".

=head2 debug

If a true value, C<console.log> will be used to indicate various events
including SW caching choices.

=head2 precache_urls

An array-ref of URLs (relative is fine) to load into the SW's cache
on installation. The SW URL will always be added to this.

=head2 network_only

An array-ref of URLs. Any fetched URL in this list will never be cached,
and always fetched over the network.

=head2 cache_only

As above, except the matching URL will never be re-checked. Use only
where you cache-bust by including a hash in the filename.

=head2 network_first

As above, except the matching URL will be fetched from the network
every time and used if possible. The cached value will only be used if
that fails.

B<Any URL not matching these three criteria> will be treated with a
"cache first" strategy, also known as "stale while revalidate": the cached
version will immediately by returned to the web client for performance,
but also fetched over the network and re-cached for freshness.

=head1 HELPERS

=head2 serviceworker.route

  my $route_name = $c->serviceworker->route;

The configured L</route_sw> route.

=head2 serviceworker.config

  my $config = $c->serviceworker->config;

The SW configuration (a hash-ref). Keys: C<debug>, C<precache_urls>,
C<network_only>, C<cache_only>, C<network_first>.

=head1 TEMPLATES

Various templates are available for including in the app's templates:

=head2 serviceworker-install.html.ep

A snippet of JavaScript that will install the supplied service
worker. Include it within a C<script> element:

  <script>
  %= include 'serviceworker-install'
  </script>

=head1 SEE ALSO

L<Mojolicious>, L<Mojolicious::Guides>, L<https://mojolicious.org>.

=cut

__DATA__

@@ serviceworker-install.html.ep
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register(
    <%== Mojo::JSON::encode_json(url_for(app->serviceworker->route)) %>
  ).then(function(registration) {
   // Worker is registered
  }).catch(function(error) {
   // There was an error registering the SW
  });
}

@@ serviceworker.js.ep
/* https://github.com/mohawk2/sw-turnkey */
var cachename = "myAppCache";
var config_raw = <%== Mojo::JSON::encode_json(app->serviceworker->config) %>;
var config = {};
var as_set = { network_only: true, cache_only: true, network_first: true };
for (ck in config_raw) {
  if (!config_raw[ck]) continue;
  if (as_set[ck]) {
    config_raw[ck].forEach(url => { config[ck][url] = 1 });
  } else {
    config[ck] = config_raw[ck];
  }
}

function cachingFetch(request) {
  return fetch(request).then(networkResponse => {
    var nrClone = networkResponse.clone(); // capture here else extra ticks will make body be read by time get to inner .then
    if (networkResponse.ok) {
      caches.open(cachename).then(
        cache => cache.put(request, nrClone)
      ).catch(()=>{}); // caching error, typically from eg POST
    }
    return networkResponse;
  });
}

function cachingFetchOrCached(request, cacheResponse) {
  return cachingFetch(request).then(
    response => response.ok ? response : cacheResponse
  ).catch(error => cacheResponse);
}

function maybeMatch(config, key, value) {
  return config[key] && config[key][value];
}

self.addEventListener("install", event => {
  console.log("Installing SW...");
  event.waitUntil(caches.open(cachename).then(cache => {
    console.log("Caching: ", config.precache_urls);
    return cache.addAll(config.precache_urls);
  }).then(() => console.log("The SW is now installed")));
});

self.addEventListener("fetch", event => {
  var url = event.request.url;
  if (maybeMatch(config, 'network_only', url)) {
    if (config.debug) console.log('network_only', url);
    return event.respondWith(fetch(event.request).catch(() => {}));
  }
  return caches.open(cachename).then(
    cache => cache.match(event.request)
  ).then(cacheResponse => {
    if (cacheResponse && maybeMatch(config, 'cache_only', url)) {
      if (config.debug) console.log('cache_only', url);
      return cacheResponse;
    }
    if (maybeMatch(config, 'network_first', url)) {
      if (config.debug) console.log('network_first', url);
      return cachingFetchOrCached(event.request, cacheResponse);
    }
    if (config.debug) console.log('cache_first', url);
    var cF = cachingFetch(event.request).catch(() => {});
    return cacheResponse || cF;
  });
});
