use Test::More;
BEGIN { use_ok( 'Game::LL::Board' ); }

my $board = Game::LL::Board->new;

is $board->play_letters(["h", 0, 0], ["i", 0, 1]), 0, "invalid starting position";
is $board->errormsg, "Invalid starting position", "correct error message";

is $board->play_letters(["h", 7, 7], ["i", 7, 8]), 5, "starting word";

is $board->play_letters(["i", 8, 7], ["g", 9, 7], ["h", 10, 7]), 11, "good word connector: igh";

is $board->play_letters(["e", 11, 7]), 0, "bad word: highe";
is $board->errormsg, "Invalid word highe", "correct error message";

is $board->play_letters(["e", 11, 7], ["r", 12, 7]), 14, "good word postfix: higher";

done_testing();
