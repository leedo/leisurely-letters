package Game::LL::Schema::Game;
use base qw/DBIx::Class::Core/;
use Storable qw/thaw freeze/;
use List::Util qw/reduce/;
use List::MoreUtils qw/first_index/;

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
  completed => {
    data_type => "bool",
    is_nullable => 0,
    default_value => 0,
  },
  winner => {
    data_type => "integer",
    is_nullable => 1,
    is_foreign_key => 1,
  },
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(winner => 'Game::LL::Schema::User');
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
  for my $letter (@remove) {
    my $index = first_index {$_ eq $letter} @letters;
    splice @letters, $index, 1;
  }
  return @letters;
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

    $self->add_status_message($user, "got $points points");
    $self->update({
      board => freeze($board),
      $letters => join("", @letters),
      $score => $self->$score + $points,
      active_player => ($self->active_player == 1 ? 2 : 1),
      last_update => time,
      turn_count => $self->turn_count + 1,
    });

    if (!$board->letters_left and !@letters) {
      my $winner = $self->p1_score > $self->p2_score ? "p1" : "p2";
      my $winner_user = $self->$winner;
      my $winner_score = $winner . "_score";

      my $loser = $winner == "p1" ? "p2" : "p1";
      my $loser_user = $self->$loser;
      my $loser_score = $loser . "_score";
      my $loser_letters = $loser . "_letters";

      my @letters = split "", $self->$loser_letters;

      my $bonus = reduce {letter_score($a) + letter_score($b)} @letters;
      $self->update({
        $winner_score => $self->$winner_score + $bonus,
        $loser_score  => $self->$loser_score - $bonus,
        completed => 1,
        winner => $winner_user->id,
      });

      $self->add_status_message($winner_user, "got $bonus point bonus");
      $self->add_status_message($loser_user, "got $bonus point penalty");
      $self->add_status_message($winner_user, "won the game!");
    }

    return 1;
  }
  $self->update({board => freeze $board});
  return 0;
}

sub opponent {
  my ($self, $user) = @_;
  return $self->p1->id == $user->id ? $self->p2 : $self->p1;
}

sub player_passed {
  my ($self, $user) = @_;
  return 0 unless $self->is_current_player($user);
  $self->update({
    active_player => ($self->active_player == 1 ? 2 : 1),
    turn_count => $self->turn_count + 1,
    last_update => time,
  }); 
  $self->add_status_message($user, "passed");
}

sub trade_letters {
  my ($self, $user, @traded_letters) = @_;
  return 0 unless $self->is_current_player($user);
  my $board = thaw $self->board;
  if ($board->letters_left < scalar @traded_letters) {
    $board->errormsg("Not enough letters left");
    $self->update({board => freeze $board});
    return 0;
  }

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
  $self->add_status_message($user, "traded in ".scalar @traded_letters." letters");
  return 1;
}

sub errormsg {
  my $self = shift;
  my $board = thaw $self->board;
  return $board->errormsg;
}

sub last_msgid {
  my $self = shift;
  my $messages = $self->sorted_messages;
  if (my $msg = $messages->first) {
    return $msg->id;
  }
  return 0;
}

sub sorted_messages {
  my ($self, $msgid) = @_;
  $msgid ||= 0;
  my $messages = $self->messages->search({id => {">" => $msgid}},{order_by => {-desc => 'id'}});
  return $messages;
}

sub forfeit_user {
  my ($self, $user) = @_;
  return 0 unless $self->is_current_player($user);
  my $winner = $user->id == $self->p1 ? $self->p2 : $self->p1;
  $self->update({
    completed => 1,
    winner => $winner->id,
    last_update => time,
    turn_count => $self->turn_count + 1,
  });
  $self->add_status_message($user, "has forfeit the game");
}

sub add_status_message {
  my ($self, $user, $message) = @_;
  $self->result_source->schema->resultset("Message")->create({
    sender => $user->display_name,
    text   => $message,
    created => time,
    game => $self->id,
    type => "status",
  });
}

1;
