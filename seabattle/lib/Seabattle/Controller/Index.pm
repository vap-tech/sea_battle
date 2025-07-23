package Seabattle::Controller::Index;
use Mojo::Base 'Mojolicious::Controller';

sub index {
  my ($c) = @_;

#  $c->session(user_id => 1); # Включает авторизация
  $c->session(user_id => undef); # Отключает авторизацию

  $c->render();
}

1;
