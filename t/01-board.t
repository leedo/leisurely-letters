use Test::More;
BEGIN { use_ok( 'Game::LL::Board' ); }

my $board = Game::LL::Board->new;

is $board->play_letters(["h", 0, 0], ["i", 0, 1]), 5, "good word";
is $board->play_letters(["i", 1, 0], ["g", 2, 0], ["h", 3, 0]), 11, "good word connector";
is $board->play_letters(["e", 4, 0]), 0, "bad word";
is $board->play_letters(["e", 4, 0], ["r", 5, 0]), 13, "good word postfix";

done_testing();
