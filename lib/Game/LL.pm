package Game::LL;

use feature ':5.10';

use lib 'lib';
use Storable qw/freeze thaw/;
use Game::LL::Schema;
use Game::LL::Board;
use Plack::Request;
use JSON;
use Any::Moose;
use Text::MicroTemplate::File;
use Digest::SHA1 qw/sha1_hex/;

has schema => (
  is => 'ro',
  lazy => 1,
  default => sub {
    Game::LL::Schema->connect($_[0]->dsn);
  }
);

has dsn => (
  is => 'ro',
  auto_deref => 1,
  isa => 'ArrayRef',
  default => sub {
    [ "dbi:SQLite:dbname=ll.db", "", "" ];
  }
);

has template => (
  is => 'ro',
  lazy => 1,
  default => sub {
    Text::MicroTemplate::File->new(
      include_path => $_[0]->share_dir . "/templates",
      package_name => "Game::LL::Board::Data",
    );
  },
);

has share_dir => (
  is => 'ro',
  default => './share',
);

has static_prefix => (
  is => 'ro',
  default => 'http://static.leisurelyletters.com',
);

has url_handlers => (
  is => 'ro',
  auto_deref => 1,
  isa => 'ArrayRef[ArrayRef]',
  default => sub {
    [
      ["/", "games"],
      ["/say", "handle_message"],
      ["/play", "handle_turn"],
      ["/new", "new_game"],
      ["/games", "games"],
      [qr{^/game/(\d+)/state}, "handle_state"],
      [qr{^/game/(\d+)}, "game"],
      ["/logout", "logout"],
    ]
  }
);

sub BUILD {
  my $self = shift;
  $self->template;
}

sub handle_state {
  my ($self, $req, $user, $gameid) = @_;
  my $game = $self->schema->resultset("Game")->find($gameid);
  return $self->not_found($req) unless $game;
  my $state = {
    your_turn => $game->is_current_player($user) ? 1 : 0,
  };
  my $msgid = $req->parameters->{msgid} || 0;
  my $turn = $req->parameters->{turn} || 1;
  my $messages = $game->sorted_messages($msgid);
  if ($messages->all) {
    $state->{messages} = $self->render_section("messages", $messages);
    $state->{last_msgid} = $messages->first->id;
  }
  if ($game->turn_count > $turn) {
    my $board = thaw $game->board;
    $state->{board} = $self->render_section("board", $board);
    $state->{game_info} = $self->render_section("game_info", $user, $game, $board);
    $state->{letters} = [$game->player_letters($user)];
  }
  $state->{turn_count} = $game->turn_count;
  return $self->respond($state);
}

sub handle_turn {
  my ($self, $req, $user) = @_;
  my $gameid = $req->parameters->{game};
  my $game = $self->schema->resultset("Game")->find($gameid);
  return $self->not_found($req) unless $game;

  if ($req->parameters->{pass}) {
    $game->player_passed($user);
    return $self->handle_state($req, $user, $gameid);
  }
  elsif ($req->parameters->{trade}) {
    my $letters = from_json($req->parameters->{trade});
    if ($letters and $game->trade_letters($user, @$letters)) {
      return $self->handle_state($req, $user, $gameid);
    }
  }
  else {
    my $pieces = from_json($req->parameters->{pieces});
    if ($pieces and $game->play_pieces($user, @$pieces)) {
      return $self->handle_state($req, $user, $gameid);
    }
  }
  return $self->respond({error => $game->errormsg});
}

sub handle_message {
  my ($self, $req, $user) = @_;
  my $gameid = $req->parameters->{game};
  my $game = $self->schema->resultset("Game")->find($gameid);
  my $message = $req->parameters->{message};
  if ($game and $message) {
    $message = $self->schema->resultset("Message")->create({
      created => time,
      text => $message,
      sender => $user->display_name,
      game => $gameid,
    });
  }
  return $self->handle_state($req, $user, $gameid);
}

sub game {
  my ($self, $req, $user, $gameid) = @_;
  my $game = $self->schema->resultset("Game")->find($gameid);
  if ($game and ($game->p1->id == $user->id or $game->p2->id == $user->id)) {
    my $board = thaw $game->board;
    return $self->respond("game", $user, $game, $board);
  }
  return $self->redirect("/games");
}

sub new_game {
  my ($self, $req, $user) = @_;
  if ($req->method eq "POST") {
    my $opponent = $self->schema->resultset("User")->find({email => $req->param("opponent")});
    if ($opponent and $opponent->id != $user->id) {
      my $board = Game::LL::Board->new;
      my $game = $self->schema->resultset("Game")->create({
        last_update => time,
        turn_count => 1,
        p1 => $user->id,
        p2 => $opponent->id,
        p1_letters => join("", $board->take_letters(7)),
        p2_letters => join("", $board->take_letters(7)),
      });
      $board = freeze $board;
      $game->update({board => $board, last_update => time});
      return $self->redirect("/game/".$game->id) if $game;
    }
  }
  return $self->redirect("/games");
}

sub games {
  my ($self, $req, $user) = @_;
  my @games = $self->schema->resultset("Game")->search([
    {p1 => $user->id}, {p2 => $user->id}
  ]);
  return $self->respond("games", $user, @games);
}

sub logout {
  my ($self, $req) = @_;
  $req->env->{"psgix.session"}->{logged_in} = 0;
  return $self->redirect("/login");
}

sub login {
  my ($self, $req) = @_;
  my $error = "";
  if ($req->method eq "POST") {
    if (my $user = $self->authenticate($req)) {
      $req->env->{"psgix.session"}->{logged_in} = 1;
      $req->env->{"psgix.session"}->{userid} = $user->id;
      return $self->redirect("/");
    }
    $error = "Bad username or password";
  }
  return $self->respond("login", $req->parameters, $error);
}

sub register {
  my ($self, $req) = @_;
  my $errors = [];
  if ($req->method eq "POST") {
    my ($success, $_errors) = $self->create_user($req->parameters);
    return $self->redirect("/login") if $success;
    $errors = $_errors;
  }
  return $self->respond("register", $req->parameters, $errors);
}

sub to_app {
  my $self = shift;
  return sub {
    my $env = shift;
    my $req = Plack::Request->new($env);
    my $session = $env->{"psgix.session"};
    if ($req->path_info =~ m{^/(login|register)}) {
      return $self->$1($req);
    }
    elsif ($session->{logged_in} and $session->{logged_in} == 1) {
      my $user = $self->schema->resultset("User")->find($session->{userid});
      return $self->dispatch($req, $user) if $user;
    }
    return $self->redirect("/login");
  }
}

sub redirect {
  my ($self, $path) = @_;
  return [302, ["Content-Type", "text/plain", "Location", $path], ["found"]]
}

sub create_user {
  my ($self, $params) = @_;
  my $errors = [];

  $params = { map {$_ => $params->{$_}} grep {$params->{$_}}
            qw/email display_name password/ };

  for (qw/email display_name password/) {
    if (!$params->{$_}) {
      push @$errors, "$_ is a required field";
    }
  }
  return (0, $errors) if @$errors;

  my $user = $self->schema->resultset("User")->find({email => $params->{email}});
  if ($user) {
    return (0, ["Email address already has an account"]);
  }

  $params->{password} = sha1_hex("wwf" . $params->{password});
  $user = $self->schema->resultset("User")->create($params);
  if (!$user) {
    return (0, ["Could not create user"]);
  }

  return 1;
}

sub is_valid_user {
  my ($self, $userid) = @_;
  my $user = $self->schema->resultset("User")->find($userid);
  $user ? 1 : 0;
}

sub authenticate {
  my ($self, $req) = @_;
  my $email = $req->parameters->{email};
  my $pass = sha1_hex "wwf" . $req->parameters->{password};
  if ($email and $pass) {
    my $user = $self->schema->resultset("User")->find({email => $email, password => $pass});
    return $user if $user;
  }
  return 0;
}

sub dispatch {
  my ($self, $req, $user) = @_;
  for ($self->url_handlers) {
    if ($req->path_info ~~ $_->[0]) {
      my @captures = ($1, $2, $3, $4);
      my $method = $_->[1];
      return $self->$method($req, $user, @captures);
    }
  }
  return $self->not_found($req);
}

sub not_found {
  my ($self, $req) = @_;
  return [404, ["Content-Type", "text/plain"], ["not found"]];
}

sub static {
  my ($self, $path_part) = @_;
  return $self->static_prefix . "/" . $path_part;
}

sub respond {
  my ($self, @args) = @_;
  if (ref $args[0] eq "HASH" or ref $args[0] eq "ARRAY") {
    my $json = to_json($args[0], {utf8 => 1});
    return [200, ["Content-Type", "text/json"], [$json]];
  }
  else {
    my $template = shift @args;
    my $html = $self->render($template, @args);
    return [200, ["Content-Type", "text/html"], [$html]]; 
  }
}

sub render {
  my ($self, $template, @args) = @_;
  $self->template->render_file("site.html", $self, $template, @args);
}

sub render_section {
  my ($self, $template, @args) = @_;
  $self->template->render_file("$template.html", $self, @args)->as_string;
}

__PACKAGE__->meta->make_immutable;
1;
