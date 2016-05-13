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
my $prefix = "/home/phil21/delltest";

my $dom;
my $ua = Mojo::UserAgent->new;

if (my $file = shift @ARGV) {
  $dom = Mojo::DOM->new(decode 'UTF-16', slurp $file);
} else {
  my $tx = $ua->build_tx(GET => 'http://pastebin.cloud.servercentral.com/uploads-public/99fb1f02fc04b72bbf899ce847e7f0c6/Catalog.xml');
  $tx->res->max_message_size(0)->default_charset('UTF-16');
  $dom = $ua->start($tx)->res->dom;
}

my $found = $dom->find('SoftwareBundle[bundleType="BTLX"]')->grep(sub{
  $_->at('TargetSystems Model Display')->text eq 'R420';
});

my @display;
my @urls;
$found->each(sub{
  my $item = $_->at('Description Display')->text;
  push @display, $item;
  say "Starting on $item";
  make_path("$prefix/$item");
  my @packages = $_->find('Contents Package')->map(sub{ $_->{path} })->each;
  for my $pkg (@packages) {
    #push (@urls, $dom->at(qq/SoftwareComponent[path\$="$pkg"]/)->{path});
    #push(@{ $files{$item} }, $dom->at(qq/SoftwareComponent[path\$="$pkg"]/)->{path});
    my %h;
    $h{bundle} = $item;
    $h{url} = $dom->at(qq/SoftwareComponent[path\$="$pkg"]/)->{path};
    push @urls, \%h;
  }
});


#say for @urls;

my $concurrency = 20;

Fetch() for 1..$concurrency;

sub Fetch {
  my $h = shift @urls;
  return unless $h;
  my $bundle = $h->{bundle};
  my $url = $h->{url};
  my $fn = basename($url);
  say "Starting on $url for bundle $bundle saving as $prefix/$bundle/$fn";
  $ua->get($host . $url, sub{
    say "Finished $url (saved to $prefix/$bundle/$fn)";
    my ($ua, $tx) = @_;
    $tx->res->content->asset->move_to("$prefix/$bundle/$fn");
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
