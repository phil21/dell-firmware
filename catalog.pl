#!/usr/bin/perl
$| = 1;
use Mojo::Base -strict;
use Data::Dumper;
use Mojo::DOM;
use Mojo::IOLoop;
use Mojo::Util qw/decode slurp/;
use File::Path qw/make_path/;
require Mojo::UserAgent;
use File::Basename;
use strict;
use warnings;

my $host = 'http://downloads.dell.com/';

# Where to put the Dell update bundle 
my $prefix = "/home/phil21/delltest";
# Number of simultaneous downloads
my $concurrency = 20;

# Model numbers to build bundles for
# FIXME: Use the more reliable hex model number here
my @models = (
  'R420',
  'R430',
  'R620',
  'R630',
  'R910',
  'R920',
  'R930',
);

my $dom;
my $ua = Mojo::UserAgent->new;

if (my $file = shift @ARGV) {
  say "Using local Catalog file $file";
  $dom = Mojo::DOM->new(decode 'UTF-16', slurp $file);
} else {
  my $tx = $ua->build_tx(GET => 'http://pastebin.cloud.servercentral.com/uploads-public/99fb1f02fc04b72bbf899ce847e7f0c6/Catalog.xml');
  $tx->res->max_message_size(0)->default_charset('UTF-16');
  $dom = $ua->start($tx)->res->dom;
}

my @models_found;
for my $model (@models) {
  my $found = $dom->find('SoftwareBundle[bundleType="BTLX"]')->grep(sub{
    $_->at('TargetSystems Model Display')->text eq $model;
  });
  push @models_found, $found if $found;
}

# XML parse you long time.
# Build an array of SoftwareComponent paths once vs. iterating per-model
my %pkg_map = map { basename($_) => $_ } $dom->find('SoftwareComponent')->map(sub{ $_->{path} })->each;

my @urls;
for my $found (@models_found) {
  $found->each(sub{
    my $item = $_->at('Description Display')->text;
    say "Starting on $item";
    make_path("$prefix/$item");
    my @packages = $_->find('Contents Package')->map(sub{ $_->{path} })->each;
    for my $pkg (@packages) {
      my %h;
      $h{bundle} = $item;
      #      $h{url} = $dom->at(qq/SoftwareComponent[path\$="$pkg"]/)->{path};
      $h{url} = $pkg_map{$pkg};
      say $h{url};
      push @urls, \%h;
    }
  });
}

Fetch() for 1..$concurrency;

sub Fetch {
  my $h = shift @urls;
  return unless $h;
  my $bundle = $h->{bundle};
  my $url = $h->{url};
  my $fn = basename($url);
  say "Starting on Bundle: $bundle saving to $bundle/$fn";
  $ua->get($host . $url, sub{
    my ($ua, $tx) = @_;
    $tx->res->content->asset->move_to("$prefix/$bundle/$fn");
    say "Finished $bundle (saved to $prefix/$bundle/$fn)";
    Fetch();
  });
}


Mojo::IOLoop->start;

    #print "Downloading $pkg... ";
    #my $tx = $ua->get($host . $dom->at(qq/SoftwareComponent[path\$="$pkg"]/)->{path},sub{
    #  my ($ua, $tx) = @_;
    #  $tx->res->content->asset->move_to("$prefix/$item/$pkg");
    #  print " Done\n";
    #});
