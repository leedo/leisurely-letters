package Game::LL::Board;

use Any::Moose;
use POSIX qw/floor/;
use List::Util qw/shuffle/;
use Path::Class qw/file/;
use Text::MicroTemplate qw/encoded_string/;
use JSON;

has grid => (
  is => 'rw',
  isa => 'ArrayRef',
  default => sub {
    [ map {[ map {""} (0 .. 14) ]} (0 .. 14) ]
  }
);

has started => (
  is => 'rw',
  default => 0,
);

sub json_grid {
  my $self = shift;
  return encoded_string to_json $self->grid;
}

has errormsg => (
  is => "rw",
  default => "",
);

has letter_scores => (
  is => 'ro',
  default => sub {{
    a => 1,  b => 3,  c => 3,  d => 2,
    e => 1,  f => 4,  g => 2,  h => 4,
    i => 1,  j => 8,  k => 5,  l => 1,
    m => 3,  n => 1,  o => 1,  p => 3,
    q => 10, r => 1,  s => 1,  t => 1,
    u => 1,  v => 4,  w => 4,  x => 8,
    y => 4,  z => 10
  }},
);

sub letter_score {
  my ($self, $letter) = @_;
  return $self->letter_scores->{$letter};
}

sub json_letter_scores {
  my $self = shift;
  return encoded_string to_json $self->letter_scores;
}

has dict => (
  is => 'ro',
  default => sub {
    my $words = {map {$_ => []} "a" .. "z"};
    my $file = file("/usr/share/dict/words")->openr;
    while (my $word = <$file>) {
      chomp $word;
      my $letter = substr lc $word, 0, 1;
      push @{$words->{$letter}}, $word;
    }
    return $words;
  }
);

has letter_counts => (
  is => 'ro',
  default => sub {{
    e => 12, a => 9, i => 9, o => 8, n => 6, r => 6,
    t => 6,  l => 4, s => 4, u => 4, d => 4, g => 3,
    b => 2,  c => 2, m => 2, p => 2, f => 2, h => 2,
    v => 2,  w => 2, y => 2, k => 1, j => 1, x => 1,
    q => 1,  z => 1
  }},
);

has letters => (
  is => 'rw',
  isa => 'ArrayRef',
  auto_deref => 1,
  lazy => 1,
  default => sub {
    [shuffle map {($_) x $_[0]->letter_counts->{$_}} "a" .. "z"];
  }
);

sub letters_left {
  my $self = shift;
  return scalar @{ $self->letters };
}

sub take_letters {
  my ($self, $count ) = @_;
  return splice @{$self->letters}, 0, $count;
}

sub play_letters {
  my ($self, @letters) = @_;
  my $clone = $self->clone_grid;
  for (@letters) {
    my ($letter, $x, $y) = @$_;
    if ($self->grid->[$y][$x]) {
      $self->errormsg("Not an empty square");
      return 0 
    }
    $clone->[$y][$x] = $letter;
  }
  if (my $score = $self->check_grid($clone, @letters)) {
    $self->grid($clone);
    return $score;
  }
  $self->errormsg("Invalid word");
  return 0;
}

sub check_grid {
  my ($self, $grid, @letters) = @_;

  my $height = scalar @{ $self->grid };
  my $width = scalar @{ $self->grid->[0] };
  my ($points, $current_word, $pointed_word, $connected, $error);

  my $reset_word = sub {
    $current_word = "";
    $pointed_word = 0;
    $connected = 0;
  };

  my $next_letter = sub {
    my ($x, $y) = @_;
    my $letter = $grid->[$y][$x];
    if ($letter) {
      $current_word .= $letter;
      (grep {$_->[1] == $x and $_->[2] == $y} @letters) ? $pointed_word = 1 : $connected = 1;
    }
    elsif ($current_word and length $current_word > 1) {
      if (!$connected and !self->started) {
        $error = 1;
        $self->errormsg("Word is not connected!");
      }
      elsif (!$self->valid_word($current_word)) {
        $error = 1;
        $self->errormsg("Invalid word");
      }
      elsif ($pointed_word) {
        $points += $self->score_word($current_word);
      }
      $reset_word->();
    }
  };
  
  for (my $y = 0; $y < $height; $y++) {
    for (my $x = 0; $x < $width; $x++) {
      $next_letter->($y, $x);
      return 0 if $error;
    }
    $reset_word->();
  }

  for (my $x = 0; $x < $width; $x++) {
    for (my $y = 0; $y < $height; $y++) {
      $next_letter->($y, $x);
      return 0 if $error;
    }
    $reset_word->();
  }
  
  $self->started(1);
  return $points;
}

sub score_word {
  my ($self, $word) = @_;
  my $sum = 0;
  for (split "", $word) {
    $sum += $self->letter_scores->{$_};
  }
  return $sum;

}

sub valid_word {
  my ($self, $word) = @_;
  my $letter = substr $word, 0, 1;
  for my $word2 (@{$self->dict->{$letter}}) {
    return 1 if $word eq $word2;
  }
  return 0;
}

sub clone_grid {
  my $self = shift;
  my $new_grid = [];
  for my $row (@{$self->grid}) {
    push @$new_grid, [ @{$row} ];
  }
  return $new_grid;
}

1;
