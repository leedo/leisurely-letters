#!/usr/bin/perl

use lib 'lib';
use Game::LL::Schema;
use Storable qw/thaw/;

die "Need game id to dump\n" unless exists $ARGV[0];
my $schema = Game::LL::Schema->connect("dbi:SQLite:ll.db","","",{});
my $game = $schema->resultset("Game")->find($ARGV[0]);
open my $fh, ">", "gamedump";
print $fh $game->board;
