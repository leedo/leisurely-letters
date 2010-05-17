use Test::More;
BEGIN { use_ok( 'Game::LL::Board' ); }

use Game::LL::Board::Data qw/letter_count letter_score word_multiplier
                             letter_multiplier valid_word/;

is word_multiplier(0,0), 3, "triple word score";
ok valid_word("qi"), "found qi";

done_testing();
