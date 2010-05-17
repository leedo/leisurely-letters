package Game::LL::Board::Data;
use base "Exporter";
use Path::Class qw/file/;

our @EXPORT_OK = qw/letter_count letter_score word_multiplier letter_multiplier valid_word/;

our $scores = {
  a => 1,  b => 3,  c => 3,  d => 2,
  e => 1,  f => 4,  g => 2,  h => 4,
  i => 1,  j => 8,  k => 5,  l => 1,
  m => 3,  n => 1,  o => 1,  p => 3,
  q => 10, r => 1,  s => 1,  t => 1,
  u => 1,  v => 4,  w => 4,  x => 8,
  y => 4,  z => 10
};

our $counts = {
  e => 12, a => 9, i => 9, o => 8, n => 6, r => 6,
  t => 6,  l => 4, s => 4, u => 4, d => 4, g => 3,
  b => 2,  c => 2, m => 2, p => 2, f => 2, h => 2,
  v => 2,  w => 2, y => 2, k => 1, j => 1, x => 1,
  q => 1,  z => 1
};

our $letter_multipliers = {
  1 => { 4 => 2, 12 => 2 },
  2 => { 6 => 3, 10 => 3 },
  3 => { 7 => 2, 9 => 2 },
  4 => { 1 => 2, 8 => 2, 15 => 2 },
  6 => { 2 => 3, 6 => 3, 10 => 3, 14 => 3 },
  7 => { 3 => 2, 7 => 2, 9 => 2, 13 => 2 },
  8 => { 4 => 2, 12 => 2 },
  9 => { 3 => 2, 7 => 2, 9 => 2, 13 => 2 },
  10 => { 2 => 3, 6 => 3, 10 => 3, 14 => 3 },
  12 => { 1 => 2, 8 => 2, 15 => 2 },
  13 => { 7 => 2, 9 => 2 },
  14 => { 6 => 3, 10 => 3 },
  15 => { 4 => 2, 12 => 2 },
};

our $word_multipliers = {
  1 => { 1 => 3, 8 => 3, 15 => 3 },
  2 => { 2 => 2, 14 => 2 },
  3 => { 3 => 2, 13 => 2 },
  4 => { 4 => 2, 12 => 2 },
  5 => { 5 => 2, 11 => 2 },
  8 => { 1 => 3, 15 => 3 },
  11 => { 5 => 2, 11 => 2 },
  12 => { 4 => 2, 12 => 2 },
  13 => { 3 => 2, 13 => 2 },
  14 => { 2 => 2, 14 => 2 },
  15 => { 1 => 3, 8 => 3, 15 => 3 },
};

my $dict = do {;
  my $file = file("/usr/share/dict/words")->openr;
  my $words = {};
  while (my $word = <$file>) {
    chomp $word;
    $words->{$word} = 1;
  }
  $words;
};

sub valid_word {
  my $word = shift;
  return $dict->{$word} || 0;
}

sub letter_count {
  my $letter = shift;
  return $counts->{$letter} || 0;
}

sub letter_score {
  my $letter = shift;
  return $scores->{$letter} || 0;
}

sub letter_multiplier {
  my ($y, $x) = @_;
  return $letter_multipliers->{$y + 1}{$x + 1} || 1;
}

sub word_multiplier {
  my ($y, $x) = @_;
  return $word_multipliers->{$y + 1}{$x + 1} || 1;
}

1;
