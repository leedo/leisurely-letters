package Game::LL::Board;

use Any::Moose;
use POSIX qw/floor/;
use List::Util qw/shuffle reduce/;
use JSON;
use Text::MicroTemplate qw/encoded_string/;
use Game::LL::Board::Data qw/letter_count letter_score word_multiplier
                             letter_multiplier valid_word/;

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

has errormsg => (
  is => "rw",
  default => "",
);

has letters => (
  is => 'rw',
  isa => 'ArrayRef',
  auto_deref => 1,
  lazy => 1,
  default => sub {
    [shuffle map {($_) x letter_count($_)} "a" .. "z"];
  }
);

sub json_letter_scores {
  my $self = shift;
  return encoded_string to_json $Game::LL::Board::Data::scores;
}

sub json_grid {
  my $self = shift;
  return encoded_string to_json $self->grid;
}

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
  return 0;
}

sub check_grid {
  my ($self, $grid, @letters) = @_;

  # state variables
  my ($points, $current_word, $word_score, $word_multiplier,
      $pointed_word, $connected, $error);

  my $reset_word = sub {
    $current_word = "";
    $word_score = 0;
    $word_multiplier = 1;
    $pointed_word = 0;
    $connected = 0;
  };

  my $next_letter = sub {
    my ($x, $y) = @_;
    my $letter = $grid->[$y][$x];

    if ($letter) {
      $current_word .= $letter;
      if (grep {$_->[1] == $x and $_->[2] == $y} @letters) {
        $pointed_word = 1;
        $word_multiplier *= word_multiplier($y, $x);
        $word_score += letter_score($letter) * letter_multiplier($y, $x);
      }
      else {
        $connected = 1;
        $word_score += letter_score($letter);
      }
    }
    elsif ($current_word and length $current_word > 1) {
      if (!$connected and $self->started) {
        $error = 1;
        $self->errormsg("Word is not connected!");
      }
      elsif (!valid_word($current_word)) {
        $error = 1;
        $self->errormsg("Invalid word");
      }
      elsif ($pointed_word) {
        $points += $word_score * $word_multiplier;
      }
      $reset_word->();
    }
  };
  
  # set initial state values
  $reset_word->();

  for (my $y = 0; $y < 15; $y++) {
    for (my $x = 0; $x < 15; $x++) {
      $next_letter->($y, $x);
      return 0 if $error;
    }
    $reset_word->();
  }

  for (my $x = 0; $x < 15; $x++) {
    for (my $y = 0; $y < 15; $y++) {
      $next_letter->($y, $x);
      return 0 if $error;
    }
    $reset_word->();
  }
  
  $self->started(1);
  return $points;
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
