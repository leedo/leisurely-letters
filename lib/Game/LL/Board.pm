package Game::LL::Board;

use Any::Moose;
use POSIX qw/floor/;
use List::Util qw/shuffle reduce first/;
use JSON;
use Text::MicroTemplate qw/encoded_string/;
use Game::LL::Board::Util qw/letter_count word_multiplier letter_score
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
  return encoded_string to_json $Game::LL::Board::Util::scores;
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
  unless ($self->started or $self->valid_start(@letters)) {
    $self->errormsg("Invalid starting position");
    return 0;
  }
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

  my $grid_state = {
    connected => 0, # all new letters are connected to something
    prev => [0, 0], # last y,x coordinates
    error => 0,     # error bool
    points => 0,    # total points for all new words
  };

  my $word = {}; # current word
  my $reset_word = sub {
    $word = {
      letters => "",
      score => 0,
      multiplier => 1,
      pointed => 0,
      connected => 0,
    };
  };

  my $next_letter = sub {
    my ($y, $x) = @_;
    my $letter = $grid->[$y][$x];

    if ($letter) {
      $word->{letters} .= $letter;
      if (first {$_->[1] == $x and $_->[2] == $y} @letters) {
        $word->{pointed} = 1;
        $word->{multiplier} *= word_multiplier($y, $x);
        $word->{score} += letter_score($letter) * letter_multiplier($y, $x);
      }
      else {
        $word->{connected} = 1;
        $word->{score} += letter_score($letter);
      }
    }
    elsif ($word->{letters} and length $word->{letters} > 1) {
      if (!valid_word($word->{letters})) {
        $grid_state->{error} = 1;
        $self->errormsg("Invalid word $word->{letters}");
      }
      elsif ($word->{pointed}) {
        $grid_state->{points} += $word->{score} * $word->{multiplier};
        $grid_state->{connected} = 1 if $word->{connected};
      }
      $reset_word->();
    }
    elsif (length $word->{letters} == 1) {
      my ($_y, $_x) = @{$grid_state->{prev}};
      # check if last piece is floating in space
      unless ($grid->[$_y - 1][$_x] or $grid->[$_y + 1][$_x]
           or $grid->[$_y][$_x - 1] or $grid->[$_y][$_x + 1]) {
         $grid_state->{error} = 1;
         $self->errormsg("A letter is floating in space, man.");
      }
      $reset_word->();
    }
    else {
      $reset_word->();
    }
  };
  
  # set initial state values
  $reset_word->();
  $self->errormsg("");

  for (my $y = 0; $y < 16; $y++) {
    for (my $x = 0; $x < 16; $x++) {
      $next_letter->($y, $x);
      return 0 if $grid_state->{error};
      $grid_state->{prev} = [$y, $x];
    }
    $reset_word->();
  }

  $grid_state->{prev} = [0, 0];

  for (my $x = 0; $x < 16; $x++) {
    for (my $y = 0; $y < 16; $y++) {
      $next_letter->($y, $x);
      return 0 if $grid_state->{error};
      $grid_state->{prev} = [$y, $x];
    }
    $reset_word->();
  }

  if ($self->started and !$grid_state->{connected}) {
    $self->errormsg("Not connected!");
    return 0;
  } elsif (!$self->started) {
    $self->started(1);
  }
  
  $self->errormsg("");
  return $grid_state->{points};
}

sub valid_start {
  my ($self, @letters) = @_;
  my $valid_start = first {$_->[1] == 7 and $_->[2] == 7} @letters;
  return defined $valid_start;
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
