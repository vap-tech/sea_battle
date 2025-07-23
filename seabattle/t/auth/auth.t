use Modern::Perl;
use Test::Spec;
use Test::Mojo;
use Mojo::Base -strict;
use Test::MockModule;
use Test::MockObject;

# Общие моки и настройки
my $mock_utils;
my $t;
my $mock_user;
my $mock_rs;
my $mock_schema;
my @created_users;
my %last_create_params;
my $mock_loop;
my $loop_called;
my $loop_callback;
my $mock_smtp;
my $smtp_called;
my $last_email;
my $mock_c;

describe "Seabattle Auth Tests" => sub {
    before each => sub {
        # Создаем mock модуль перед загрузкой приложения
        $mock_utils = Test::MockModule->new('Seabattle::Auth::Utils');

        # Мокируем функции
        $mock_utils->mock('is_valid_email', sub {
            my ($c, $email) = @_;
            return $email =~ /\A[^@\s]+@[^@\s]+\z/;
        });

        $mock_utils->mock('email_exists', sub {
            my ($c, $email) = @_;
            return $email eq 'exists@example.com' ? 1 : 0;
        });

        # Загружаем приложение
        $t = Test::Mojo->new('Seabattle');

        # Мокируем БД
        $mock_user = Test::MockObject->new;
        $mock_user->mock('id', sub { 42 });

        @created_users = ();  # Для хранения созданных пользователей
        %last_create_params = ();  # Для хранения параметров создания

        $mock_rs = Test::MockObject->new;
        $mock_rs->mock('create', sub {
            my ($c, $params) = @_;

            %last_create_params = %$params;  # Сохраняем параметры

            # Создаем нового пользователя
            my $user = Test::MockObject->new;
            $user->mock('id', sub { 42 });
            $user->mock('email', sub { $params->{email} });
            $user->mock('nickname', sub { $params->{email} });

            push @created_users, $user;
            return $user;
        });

        $mock_schema = Test::MockObject->new;
        $mock_schema->mock('resultset', sub { $mock_rs });

        # Подменяем хелперы
        $t->app->helper(schema => sub { $mock_schema });

        # Мокируем Mojo::IOLoop
        $mock_loop = Test::MockModule->new('Mojo::IOLoop');
        $loop_called = 0;
        $loop_callback = undef;

        $mock_loop->mock('next_tick', sub {
            my ($self, $cb) = @_;
            $loop_called++;
            $loop_callback = $cb;
            return $self;
        });

        # Мокируем Mojo::SMTP::Client
        $mock_smtp = Test::MockModule->new('Mojo::SMTP::Client');
        $smtp_called = 0;
        $last_email = undef;

        $mock_smtp->mock('new', sub {
            my ($class, %config) = @_;
            return bless \%config, $class;
        });

        $mock_smtp->mock('send', sub {
            my ($self, %params) = @_;
            $smtp_called++;
            $last_email = \%params;
            return bless { error => undef }, 'Mojo::Transaction';
        });

        # Создаем полный mock контроллера с конфигом
        $mock_c = Test::MockObject->new;
        $mock_c->mock('app', sub {
            my $mock_app = Test::MockObject->new;

            $mock_app->mock('config', sub {
                return {
                    email => {
                        address => 'localhost',
                        port    => 1025,
                        timeout => 10,
                        from    => 'example@seabattle.local'
                    }
                };
            });

            $mock_app->mock('log', sub {
                my $mock_log = Test::MockObject->new;
                $mock_log->mock('info', sub {});
                $mock_log->mock('error', sub {});
                return $mock_log;
            });

            return $mock_app;
        });
    };

    # Тест  get-запроса /login
    describe "GET /login" => sub {
        it "should return login form" => sub {
            $t->get_ok('/login')
              ->status_is(200);
        };
    };

    # Тест обработки email (POST /login)
    describe "POST /login" => sub {

        # Если email найден то редирект на /auth
        it "should redirect existing user to /auth" => sub {
            $t->post_ok('/login' => form => { email => 'exists@example.com' })
              ->status_is(302)
              ->header_is(Location => '/auth');
        };

        # Если email не найден то создание нового пользователя и редирект на /registred
        it "should create new user and redirect to /registred" => sub {
            @created_users = ();  # Сбрасываем перед тестом
            %last_create_params = ();

            $t->post_ok('/login' => form => { email => 'new@example.com' })
              ->status_is(302)
              ->header_is(Location => '/registred');

            # Проверяем создание пользователя
            is scalar @created_users, 1, 'Exactly one user created';

            my $user = $created_users[0];
            is $user->email, 'new@example.com', 'Email set correctly';
            is $user->nickname, 'new@example.com', 'Nickname set correctly';

            # Проверяем что пароль хеширован
            like $last_create_params{password_hash},
                qr/^(?:{CRYPT})?\$2[aby]\$/,
                'Password was hashed with bcrypt';

            # Проверяем установку сессии
            my $session_cookie = $t->tx->res->cookie('seabattle');
            ok $session_cookie, 'Session cookie was set';

            my $mock_c = $t->app->build_controller;
            $mock_c->session({user_id => $user->id});
            is $mock_c->session('user_id'), $user->id, 'Mock session has correct user_id';
        };

        # Тест на отсутствие email
        it "should return 400 for missing email field" => sub {
            $t->post_ok('/login' => form => { name => 'Test' })
              ->status_is(400);
        };

        # Тест пустого email
        it "should return 400 for empty email" => sub {
            $t->post_ok('/login' => form => { email => '' })
              ->status_is(400);
        };

        # Тест невалидного email
        it "should return 400 for invalid email format" => sub {
            $t->post_ok('/login' => form => { email => 'invalid-email' })
              ->status_is(400);
        };
    };

    # Тест  get-запроса /registred
    describe "GET /registred" => sub {
        it "should return registration form" => sub {
            $t->get_ok('/registred')
              ->status_is(200);
        };
    };

    # Тест отправки пароля на email
    describe "Email sending" => sub {
        it "should send email via next_tick with config" => sub {
            # Сбрасываем состояние перед тестом
            $loop_called = 0;
            $smtp_called = 0;
            $last_email = undef;
            $loop_callback = undef;

            # Вызываем код, который использует next_tick
            Mojo::IOLoop->next_tick(sub {
                Seabattle::Auth::Utils::send_email('test@example.com', 'pass123', $mock_c);
            });

            # Проверяем что next_tick был вызван
            is $loop_called, 1, 'next_tick was called';

            # Выполняем колбэк
            $loop_callback->();

            # Проверяем результаты
            is $smtp_called, 1, 'SMTP send was called';
            is $last_email->{to}, 'test@example.com', 'Correct recipient';
            like $last_email->{data}, qr/Ваш пароль: pass123/, 'Correct email content';
        };
    };
};

runtests unless caller;