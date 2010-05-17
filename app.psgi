use Plack::Builder;
use Game::LL;

builder {
  enable "Session";
  enable "Static", path => sub {s!^/static/!!}, root => "./static";
  Game::LL->new->to_app;
}
