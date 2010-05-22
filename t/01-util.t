use Test::More;
BEGIN { use_ok( 'Game::LL::Board' ); }

use Game::LL::Board::Util qw/letter_count letter_score word_multiplier
                             letter_multiplier valid_word/;

is letter_count("e"), 12, "12 Es";
is letter_count("d"), 4, "4 Ds";
is letter_count("b"), 2, "2 Bs";
is letter_count("f"), 2, "2 Fs";
is letter_count("k"), 1, "1 K";
is letter_count("j"), 1, "1 J";
is letter_count("q"), 1, "1 Q";

is letter_score("e"), 1, "1 pt E";
is letter_score("d"), 2, "2 pt D";
is letter_score("b"), 3, "3 pt B";
is letter_score("f"), 4, "4 pt F";
is letter_score("k"), 5, "5 pt K";
is letter_score("j"), 8, "8 pt J";
is letter_score("q"), 10, "10 pt Q";

is letter_multiplier(0,3), 2, "double letter score"; 
is word_multiplier(0,0), 3, "triple word score";

ok valid_word("qi"), "found qi";
ok !valid_word("hellh"), "not found hellh";

done_testing();
