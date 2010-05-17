package Game::LL::Schema;

use base "DBIx::Class::Schema";

our $VERSION = "0.01";

__PACKAGE__->load_classes(qw/User Game Message/);

__PACKAGE__->load_components(qw/Schema::Versioned/);
__PACKAGE__->upgrade_directory('./sql/');

1;
