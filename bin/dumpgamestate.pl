#!/usr/bin/perl

use lib 'lib';
use Game::LL::Schema;
use Storable qw/thaw/;

my $schema = Game::LL::Schema->connect("dbi:SQLite:ll.db","","");
my $game = $schema->resultset("Game")->find(5);
open my $fh, ">", "gamedump";
print $fh $game->board;
