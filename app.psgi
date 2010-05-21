use Plack::Builder;
use Game::LL;

my $game = Game::LL->new;
builder {
  enable "Session", store => 'File';
  enable "Static", path => sub {s!^/static/!!}, root => $game->share_dir."/static";
  $game->to_app;
}
