package Game::LL::Schema::Message;
use base qw/DBIx::Class::Core/;

__PACKAGE__->table('message');
__PACKAGE__->add_columns(
  id => {
    data_type => "integer",
    is_nullable => 0,
    is_auto_increment => 1,
  },
  game => {
    data_type => "integer",
    is_nullable => 0,
    is_foreign_key => 1,
  },
  text => {
    data_type => "text",
    is_nullable => 0,
  },
  created => {
    data_type => "integer",
    is_nullable => 0,
  },
  type => {
    data_type => "varchar",
    size      => 32,
    default_value => "dialog",
  },
  sender => {
    data_type => "varchar",
    size => 32,
    is_nullable => 0,
  },
);

__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to(game => 'Game::LL::Schema::Game');

1;
