package Game::LL::Board;

use Any::Moose;
use POSIX qw/floor/;
use List::Util qw/shuffle reduce first/;
use JSON;
use Text::MicroTemplate qw/encoded_string/;
use Game::LL::Board::Data qw/letter_count word_multiplier letter_score
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

sub return_letters {
  my ($self, @letters) = @_;
  push @{$self->letters}, shuffle @letters;
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
      $pointed_word, $connected, $error, $valid_start, $_x, $_y,
      $any_connected);

  my $reset_word = sub {
    $current_word = "";
    $word_score = 0;
    $word_multiplier = 1;
    $pointed_word = 0;
    $connected = 0;
  };

  my $next_letter = sub {
    my ($y, $x) = @_;
    my $letter = $grid->[$y][$x];

    if ($letter) {
      $current_word .= $letter;
      if (first {$_->[1] == $x and $_->[2] == $y} @letters) {
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
      if (!valid_word($current_word)) {
        $error = 1;
        $self->errormsg("Invalid word $current_word");
      }
      elsif ($pointed_word) {
        $points += $word_score * $word_multiplier;
        $any_connected = 1 if $connected;
      }
      $reset_word->();
    }
    elsif (length $current_word == 1) {
      # check if last square (this letter) is floating in space
      unless ($grid->[$_y - 1][$_x] or $grid->[$_y + 1][$_x]
           or $grid->[$_y][$_x - 1] or $grid->[$_y][$_x + 1]) {
         $error = 1;
         $self->errormsg("A letter is floating in space, man.");
      }
      $reset_word->();
    }
    else {
      $reset_word->();
    }
  };
  
  if (!$self->started) {
    my $valid_start = first {$_->[1] == 7 and $_->[2] == 7} @letters;
    if (!$valid_start) {
      $self->errormsg("Invalid starting position");
      return 0;
    }
  }

  # set initial state values
  $reset_word->();
  $self->errormsg("");
  ($_x, $_y) = (0, 0);

  for (my $y = 0; $y < 16; $y++) {
    for (my $x = 0; $x < 16; $x++) {
      $next_letter->($y, $x);
      return 0 if $error;
      ($_y, $_x) = ($y, $x);
    }
    $reset_word->();
  }

  ($_x, $_y) = (0, 0);

  for (my $x = 0; $x < 16; $x++) {
    for (my $y = 0; $y < 16; $y++) {
      $next_letter->($y, $x);
      return 0 if $error;
      ($_y, $_x) = ($y, $x);
    }
    $reset_word->();
  }

  if ($self->started and !$any_connected) {
    $self->errormsg("Not connected!");
    return 0;
  } elsif (!$self->started) {
    $self->started(1);
  }
  
  $self->errormsg("");
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
