use Test::More;
use Path::Class qw/dir file/;
use Storable qw/thaw/;
BEGIN { use_ok( 'Game::LL::Board' ); }

my $boards_dir = dir(qw/t boards/);
ok -e $boards_dir, "boards directory exists";

# board 01, word formed horizontally, connected vertically 
{
  my $board = load_board("01");
  isa_ok $board, "Game::LL::Board";
  my $points = $board->play_letters(["o",6,14],["d",7,14],["e",8,14]);
  is $points, 17, "word formed horizontally, connected vertically";
}

done_testing();

sub load_board {
  my $num = shift;
  my $file = $boards_dir->file("01");
  return thaw scalar $file->slurp;
}
