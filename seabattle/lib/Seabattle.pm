package Seabattle;
use Mojo::Base 'Mojolicious';
use Seabattle::Schema;
use Seabattle::Model::Executor;

use Modern::Perl;

 
# This method will run once at server start
sub startup {
    my ($self) = @_;
    
    # Подключение рендера Template Toolkit
    $self->plugin('tt_renderer');
    $self->renderer->default_handler('tt');
 
    # Загрузка конфигурации из конфига seabattle.yml
    my $config = $self->plugin('NotYAMLConfig');
    $self->secrets( $config->{secrets} );

    # Настройка сессий
    $self->sessions->cookie_name('seabattle');
    $self->sessions->default_expiration(3600);

    # Хелпер подключения к БД
    $self->helper(schema => sub {
        state $schema = Seabattle::Schema->connect(
            "dbi:MariaDB:database=$ENV{DB_NAME};host=$ENV{DB_HOST};port=$ENV{DB_PORT}",
            $ENV{DB_USER},
            $ENV{DB_PASSWORD},
            { RaiseError => 1, AutoCommit => 1 },
        );
    });

    # Хелпер проверки аутентификации
    $self->helper(is_authenticated => sub {
        my ($c) = @_;

        return !!$c->session('user_id');
    });

    # Плагин для хеширования пароля
    $self->plugin('Bcrypt', { cost => 8 });

    # Хук для корректной отрисовки хедера (для авторизованного / не авторизованного)
    $self->hook(before_render => sub {
        my ($c, $args) = @_;

        $args->{is_authenticated} = $c->is_authenticated;
    });

    # Роутер
    my $r = $self->routes;
 
    # Индексная страница
    $r->get('/')->to('Index#index');
 
    $r->get('/login')->to('Auth#login_form');
    $r->post('/login')->to('Auth#login');
    $r->get('/auth')->to('Auth#auth_form');
    $r->post('/auth')->to('Auth#authorization');
    $r->post('/recovery')->to('Auth#recovery');
    
    # Приватные роуты
    $r->get('/registred')->to('Auth#registred');
    $r->post('/logout')->to('Auth#logout');

    $self->{clients} = {};
    $self->{executor} = Seabattle::Model::Executor->new;
    $self->helper('clients' => sub { shift->app->{clients} });
    $r->websocket('/api/v2/battle-ws')->to(controller => 'MX::Battle', action => 'ws_connection');
    $r->post('/api/v2/register')->to(controller => 'MX::Auth', action => 'register');
    $r->post('/api/v2/auth')->to(controller => 'MX::Auth', action => 'auth');
    $r->post('/api/v2/me')->to(controller => 'MX::Auth', action => 'me');
    $r->post('/api/v2/refresh_auth')->to(controller => 'MX::Auth', action => 'refresh_auth');
    $r->post('/api/v2/verification_email')->to(controller => 'MX::Auth', action => 'verification_email');
    $r->post('/api/v2/verify')->to(controller => 'MX::Auth', action => 'verify');
    $r->patch('/api/v2/change_password')->to(controller => 'MX::Auth', action => 'change_password');
    $r->get('/api/v2/rank')->to(controller => 'MX::Rank', action => 'rank');
    $r->post('/api/v2/balance/deposit')->to(controller => 'MX::Balance', action => 'deposit');
    $r->post('/api/v2/balance/current')->to(controller => 'MX::Balance', action => 'current');
    $r->post('/api/v2/balance/subtract')->to(controller => 'MX::Balance', action => 'subtract');
    $r->get('/api/v2/shop/boosts')->to(controller => 'MX::Shop', action => 'list_boosts');
    $r->post('/api/v2/shop/boosts/:id/buy')->to(controller => 'MX::Shop', action => 'buy_boost');
    $r->get('/api/v2/shop/boosts/top')->to(controller => 'MX::Shop', action => 'top_boosts');
    $r->put('/api/v2/user_area/profile')->to(controller => 'MX::UserArea', action => 'edit_profile');

    # API: формирование рейтинга
    $r->get('/game/rating')->to('rating#index');

}
 
1;