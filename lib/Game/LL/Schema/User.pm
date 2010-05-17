package Game::LL::Schema::User;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('user');
__PACKAGE__->add_columns(
  id => {
    data_type => "integer",
    is_nullable => 0,
    is_auto_increment => 1,
  },
  email => {
    data_type => "varchar",
    size => 32,
    is_nullable => 0,
  },
  display_name => {
    data_type => "varchar",
    size => 32,
    is_nullable => 0,
  },
  password => {
    data_type => "varchar",
    size => 40,
    is_nullable => 0,
  },
);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->has_many(games => 'Game::LL::Schema::Game',
                      [{ 'foreign.p1' => 'self.id' },
                       { 'foreign.p2' => 'self.id' },]);

1;
