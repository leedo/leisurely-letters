package Game::LL::Schema::Game;
use base qw/DBIx::Class::Core/;
use Storable qw/thaw freeze/;

__PACKAGE__->table('game');
__PACKAGE__->add_columns(
  id  => {
    data_type => "integer",
    is_nullable => 0,
    is_auto_increment => 1,
  },
  turn_count => {
    data_type => "integer",
    is_nullable => 0,
    default_value => 1,
  },
  last_update => {
    data_type => "integer",
    is_nullable => 0,
  },
  p1 => {
    data_type => "integer",
    is_nullable => 0,
    is_foreign_key => 1,
  },
  p2 => {
    data_type => "integer",
    is_nullable => 0,
    is_foreign_key => 1,
  },
  p1_score => {
    data_type => "integer",
    is_nullable => 0,
    default_value => 0,
  },
  p2_score => {
    data_type => "integer",
    is_nullable => 0,
    default_value => 0,
  },
  p1_letters => {
    data_type => "varchar",
    size => 7,
    is_nullable => 1,
  },
  p2_letters => {
    data_type => "varchar",
    size => 7,
    is_nullable => 1,
  },
  board => {
    data_type => "blob",
    is_nullable => 1,
  },
  active_player => {
    data_type => "integer",
    is_enum => 1,
    default_value => 1,
    extra => {list => [qw/1 2/]}
  },
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(p1 => 'Game::LL::Schema::User');
__PACKAGE__->belongs_to(p2 => 'Game::LL::Schema::User');
__PACKAGE__->has_many(messages => 'Game::LL::Schema::Message', "game");

sub player_letters {
  my ($self, $user) = @_;
  if ($user->id == $self->p1->id) {
    return split "", $self->p1_letters;
  }
  return split "", $self->p2_letters;
}

sub remove_user_letters {
  my ($self, $user, @remove) = @_;
  my @letters = $self->player_letters($user);
  my @new_letters;
  for my $letter (@letters) {
    my $remove = 0;
    for my $rm_idx (0 .. @remove - 1) {
      if ($remove[$rm_idx] eq $letter) {
        $remove = 1;
        splice(@remove, $rm_idx, 1);
        last;
      }
    }
    push @new_letters, $letter unless $remove;
  }
  return @new_letters;
}

sub is_current_player {
  my ($self, $user) = @_;
  my $player = "p" . $self->active_player;
  return $self->$player->id == $user->id;
}

sub play_pieces {
  my ($self, $user, @pieces) = @_;
  return 0 unless $self->is_current_player($user);

  my $player = "p" . $self->active_player;
  my $score = $player . "_score";
  my $letters = $player . "_letters";

  my $board = thaw $self->board;
  if (my $points = $board->play_letters(@pieces)) {
    my @letters = $self->remove_user_letters($user, map {$_->[0]} @pieces);
    push @letters, $board->take_letters(7 - @letters);
    $self->update({
      board => freeze($board),
      $letters => join("", @letters),
      $score => $self->$score + $points,
      active_player => ($self->active_player == 1 ? 2 : 1),
      last_update => time,
      turn_count => $self->turn_count + 1,
    });
    $self->result_source->schema->resultset("Message")->create({
      sender => $user->display_name,
      text   => "got $points points",
      created => time,
      game => $self->id,
      type => "status",
    });
    return 1;
  }
  $board = freeze $board;
  $self->update({board => $board});
  return 0;
}

sub opponent {
  my ($self, $user) = @_;
  return $self->p1->id == $user->id ? $self->p2 : $self->p1;
}

sub player_passed {
  my ($self, $user) = @_;
  $self->update({
    active_player => ($self->active_player == 1 ? 2 : 1),
    turn_count => $self->turn_count + 1,
    last_update => time,
  }); 
  $self->result_source->schema->resultset("Message")->create({
    sender => $user->display_name,
    text   => "passed",
    created => time,
    game => $self->id,
    type => "status",
  });
}

sub trade_letters {
  my ($self, $user, @traded_letters) = @_;
  my $board = thaw $self->board;
  return 0 if $board->letters_left < scalar @traded_letters;

  my @letters = $self->remove_user_letters($user, @traded_letters);
  push @letters, $board->take_letters(scalar @traded_letters);
  $board->return_letters(@traded_letters);
  my $player = "p".$self->active_player."_letters";
  $self->update({
    last_update => time,
    active_player => ($self->active_player == 1 ? 2 : 1),
    $player => join("", @letters),
    board => freeze($board),
    turn_count => $self->turn_count + 1,
  });
  $self->result_source->schema->resultset("Message")->create({
    sender => $user->display_name,
    text   => "traded in ".scalar @traded_letters." letters",
    created => time,
    game => $self->id,
    type => "status",
  });
  return 1;
}

sub errormsg {
  my $self = shift;
  my $board = thaw $self->board;
  return $board->errormsg;
}

sub last_msgid {
  my $self = shift;
  my $messages = $self->messages->search(undef, {order_by => {-desc => 'id'}});
  if (my $msg = $messages->first) {
    return $msg->id;
  }
  return 0;
}

1;
