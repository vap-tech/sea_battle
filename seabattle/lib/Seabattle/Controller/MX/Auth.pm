package Seabattle::Controller::MX::Auth;
use strict;
use warnings FATAL => 'all';
use Mojo::Base qw(Mojolicious::Controller Mojo::Cookie);
use JSON qw(decode_json encode_json);
use Digest::MD5 qw(md5_hex);
use Date::Parse;
use Crypt::URandom qw(urandom);
use Mojo::Util qw(b64_encode);
use Mojo::SMTP::Client;
use Encode qw(encode decode);
use Redis;

use Seabattle::Controller::MX::Token;


my $config = decode_json do { local (@ARGV, $/) = ('config/config.json'); <> };
my $redis = Redis->new(server => "$config->{'redis'}{'host'}:$config->{'redis'}{'port'}");


sub register {
    my ($self) = @_;

    my $dbh = $self->schema->storage->dbh;

    my $json = $self->req->json;
    return $self->render(json => {error => 'json format required'}, status => 400) unless defined $json;

    my ($name, $email, $password) = @$json{qw(name email password)} or return(
        $self->render(json => {error => 'All fields are required'}, status => 400)
    );

    if ($email !~ /@/) {
        return $self->render(json => {error => 'Invalid email format'}, status => 400);
    }

    my $md5_pass = md5_hex($password);

    eval {
        $dbh->do("INSERT INTO mx_users (name) VALUES (?)", undef, $name);
        my $user_id = $dbh->last_insert_id(undef, undef, 'mx_users', 'user_id');

        $dbh->do(
            "INSERT INTO mx_user_logins (email, password, user_id) VALUES (?, ?, ?)",
            undef,
            lc($email), $md5_pass, $user_id
        );

        $dbh->do("INSERT INTO mx_user_rank (user_id) VALUES (?)", undef, $user_id);

        my $token = _generate_secure_token();
        my $expires_in_days = 3;

        $dbh->do(
            "UPDATE mx_user_logins
            SET token = ?,
            token_expires_at = DATE_ADD(NOW(), INTERVAL ? DAY)
            WHERE user_id = ?",
            undef,
            $token,
            $expires_in_days,
            $user_id
        );

        $self->_send_verification_email($email, $token);

        return $self->render(json => {message => 'User registered successfully'}, status => 201);

    } or do {
        $self->app->log->error("Error inserting into database: $@");
        return $self->render(json => { error => 'An error occurred during registration' }, status => 500);
    }

};

sub auth {
    my ($self) = @_;

    my $dbh = $self->schema->storage->dbh;

    my $json = $self->req->json;
    my ($email, $password) = @$json{qw(email password)} or return(
        $self->render(json => {error => 'Email and password are required'}, status => 400)
    );

    my $md5_pass = md5_hex($password);

    my $sth = $dbh->prepare("SELECT user_id FROM mx_user_logins WHERE email = ? AND password = ?");
    $sth->execute(lc($email), $md5_pass);
    my $user_id = $sth->fetchrow_array();

    if (!defined $user_id) {
        return $self->render(json => {error => 'Invalid credentials'}, status => 401);
    }

    my $access_token = Seabattle::Controller::MX::Token::generate_access_token($user_id);
    my $refresh_token = Seabattle::Controller::MX::Token::generate_refresh_token($user_id);

    $redis->set("access_token:$user_id", $access_token, 'EX', 3600);

    # Если больше 3 авторизованных устройств, сбрасываем авторизацию на всех
    my $select_stmt = 'SELECT COUNT(*) FROM mx_user_auths WHERE user_id = ?';
    my $sth_select = $dbh->prepare($select_stmt);
    $sth_select->execute($user_id);

    my $num_tokens = $sth_select->fetchrow_array();

    if ($num_tokens >= 3) {
        my $delete_stmt = "DELETE FROM mx_user_auths WHERE user_id = ?";
        my $sth_delete = $dbh->prepare($delete_stmt);
        $sth_delete->execute($user_id);
    }

    $dbh->do("INSERT INTO mx_user_auths (refresh_token, refresh_token_date_start, user_id) VALUES (?, NOW(), ?)",
        undef, $refresh_token, $user_id);

    $self->cookie(
        access_token => $access_token,
            {
                domain => $config->{'domain'},
                path => '/',
                expires => time + 3600,
                httponly => 0,
                secure => 1
            }
    );

    $self->cookie(
        refresh_token => $refresh_token,
            {
                domain => $config->{'domain'},
                path => '/',
                expires => time + 172800,
                httponly => 1,
                secure => 1
            }
    );

    return $self->render(json => {message => 'Authenticated successfully'}, status => 200);
};

sub me {
    my ($self) =@_;

    my $dbh = $self->schema->storage->dbh;

    my $user_id = $self->verify_access_token;
    return unless defined $user_id;

    my $sth = $dbh->prepare("SELECT name FROM mx_users WHERE id = ?");
    $sth->execute($user_id);
    my ($user_name) = $sth->fetchrow_array();

    $sth = $dbh->prepare("SELECT rank FROM mx_user_rank WHERE user_id = ?");
    $sth->execute($user_id);
    my ($user_rank) = $sth->fetchrow_array();

    return $self->render(
        json => {
            user_id => $user_id,
            name    => $user_name,
            rank    => $user_rank
        },
        status => 200
    );
}

sub verify_access_token {
    my ($self) = @_;

    my $access_token = $self->cookie('access_token');

    unless (defined $access_token) {
        $self->render(
            json => {
                error   => "token_not_found",
                message => "Access token not found, please refresh"
            },
            status => 401
        );
        return undef;
    }

    my $payload = Seabattle::Controller::MX::Token::verify_token($access_token);
    unless ($payload && $payload->{sub}) {
        $self->render(
            json => {
                error   => "token_invalid",
                message => "Invalid access token, please refresh"
            },
            status => 401
        );
        return undef;
    }

    my $user_id = $payload->{sub};

    unless ($redis->get("access_token:$user_id")) {
        $self->render(
            json => {
                error   => "token_expired",
                message => "Access token expired, please refresh"
            },
            status => 401
        );
        return undef;
    }

    return $user_id;
}


sub refresh_auth {
    my ($self) = @_;

    my $dbh = $self->schema->storage->dbh;

    my $old_refresh_token = $self->cookie('refresh_token');
    my $payload = Seabattle::Controller::MX::Token::verify_token($old_refresh_token);

    my $user_id = $payload->{sub};

    unless (defined $old_refresh_token) {
        return $self->render(json => {error => 'Refresh token not found in cookies'}, status => 400);
    }

    my $sth = $dbh->prepare("SELECT * FROM mx_user_auths WHERE refresh_token = ? AND user_id = ?");
    $sth->execute($old_refresh_token, $user_id);
    my ($found_refresh_token, $refresh_date_start) = $sth->fetchrow_array();

    unless (defined $found_refresh_token) {
        return $self->render(json => {error => 'Refresh token not found'}, status => 404);
    }

    if (time() > str2time($refresh_date_start) + 172800) {
        return $self->render(json => {error => 'Refresh token expired'}, status => 401);
    }

    my $new_access_token = Seabattle::Controller::MX::Token::generate_access_token($user_id);
    my $new_refresh_token = Seabattle::Controller::MX::Token::generate_refresh_token($user_id);

    $redis->set("access_token:$user_id", $new_access_token, 'EX', 1800); # 30 minutes expiration

    $dbh->do(
        "DELETE FROM mx_user_auths WHERE refresh_token = ? AND user_id = ?",
        undef,
        $old_refresh_token,
        $user_id
    );

    $dbh->do(
        "INSERT INTO mx_user_auths (user_id, refresh_token, refresh_token_date_start) VALUES (?, ?, NOW())",
        undef,
        $user_id,
        $new_refresh_token
    );

    $self->cookie(
        access_token => $new_access_token,
            {
                domain => $config->{'domain'},
                path => '/',
                expires => time + 3600,
                httponly => 0,
                secure => 1
            }
    );

    $self->cookie(
        refresh_token => $new_refresh_token,
            {
                domain => $config->{'domain'},
                path => '/',
                expires => time + 172800,
                httponly => 1,
                secure => 1
            }
    );

    return $self->render(json => {message => 'Tokens refreshed successfully'}, status => 200);
};

sub verify {
    my ($self) = @_;

    my $dbh = $self->schema->storage->dbh;

    my $json = $self->req->json;
    my ($token) = @$json{qw(token)} or return(
        $self->render(json => {error => 'Token are required'}, status => 400)
    );

    my $sth = $dbh->prepare("SELECT user_id FROM mx_user_logins WHERE token = ?");
    $sth->execute($token);
    my ($user_id) = $sth->fetchrow_array();

    return $self->render(json => {error => 'Invalid verification code'}, status => 400)
        unless defined $user_id;

    $dbh->do("UPDATE mx_user_logins SET is_verified = TRUE WHERE user_id = ?", undef, $user_id);

    return $self->render(json => {message => 'User verified successfully'}, status => 200);
};

sub verification_email {
    my ($self) = @_;

    my $dbh = $self->schema->storage->dbh;

    my $user_id = $self->verify_access_token;
    return unless defined $user_id;

    my $sth = $dbh->prepare("SELECT email, is_verified FROM mx_user_logins WHERE user_id = ? AND is_verified = FALSE");
    $sth->execute($user_id);
    my ($email) = $sth->fetchrow_array();

    return $self->render(json => {error => 'User not found or already verified'}, status => 400)
        unless defined $email;

    my $token = _generate_secure_token();
    my $expires_in_days = 3;

    $dbh->do(
        "UPDATE mx_user_logins
         SET token = ?,
         token_expires_at = DATE_ADD(NOW(), INTERVAL ? DAY)
         WHERE user_id = ?",
        undef,
        $token,
        $expires_in_days,
        $user_id
    );

    $self->_send_verification_email($email, $token);

    return $self->render(json => {message => 'Verification email resent successfully'}, status => 200);
};

sub _send_verification_email {
    my ($self, $email, $token) = @_;

    my $domain = $self->config->{'domain'} || $self->req->url->base->host;
    my $verification_url = "https://$domain/verify/$token";

    my $body = $self->render_to_string(
        'email/verification',
        verification_url => $verification_url,
        format => 'mail'
    );

    my $params = {
        to      => $email,
        subject => 'Подтверждение регистрации в SeaBattle',
        body    => $body
    };

    $self->_send_mail( $params )
        or $self->app->log->error("Failed to send  verification email: $@");
}

sub _generate_secure_token {
    my $bytes = urandom(32);
    my $encoded = b64_encode($bytes, '');
    $encoded =~ tr/+/_/;
    $encoded =~ tr/=/~/;
    $encoded =~ tr|/|_|;
    return $encoded;
}

sub change_password {
    my ($self) = @_;

    my $dbh = $self->schema->storage->dbh;

    my $json = $self->req->json;
    my ($old_password, $new_password) = @$json{qw(old_password new_password)} or return(
        $self->render(json => {error => 'Old password or new password missing'}, status => 403)
    );

    my $user_id = $self->verify_access_token or return;

    unless ($old_password && $new_password && length($new_password) >= 6) {
        return $self->render(json => {error => 'Old password or new password invalid'}, status => 403);
    }

    my $md5_old_pass = md5_hex($old_password);
    my $md5_new_pass = md5_hex($new_password);

    my $sth = $dbh->prepare("SELECT user_id FROM mx_user_logins WHERE user_id = ? AND password = ?");
    $sth->execute($user_id, $md5_old_pass);
    my ($found_user_id) = $sth->fetchrow_array();

    return $self->render(json => {error => 'Incorrect old password'}, status => 403)
        unless defined $found_user_id;

    $dbh->do("UPDATE mx_user_logins SET password = ? WHERE user_id = ?", undef, $md5_new_pass, $user_id);

    $self->_log_password_change($user_id);
    $self->_notify_password_change($user_id);

    return $self->render(json => {message => 'Password changed successfully'}, status => 200);
};

sub _notify_password_change {
    my ($self, $user_id) = @_;

    # 1. Получаем email пользователя
    my $user = $self->schema->storage->dbh->selectrow_hashref(
        "SELECT email FROM mx_user_logins WHERE user_id = ?",
        undef,
        $user_id
    ) or return $self->app->log->error("User $user_id not found");

    my $email = $user->{email};

    my $alert = 'mailto:battle@v-petrenko.ru?subject=SeaBattle';

    my $body = $self->render_to_string(
        'email/password_changed',
        user_id => $user_id,
        change_time => scalar(localtime),
        ip_address => $self->tx->remote_address,
        security_alert => $alert,
        format => 'mail'
    );

    my $params = {
        to      => $email,
        subject => 'Изменение пароля в SeaBattle',
        body    => $body,
    };

    eval {
        $self->_send_mail( $params );
        $self->app->log->debug("Password change notification sent");
    }
        or $self->app->log->error("Failed to send password change email");
}

sub _send_mail {
    my ($self, $params) = @_;

    my $smtp = Mojo::SMTP::Client->new(
        address => $config->{'smtp'}{'host'},
        port    => 25,
        tls     => 0
    );

    my $auth = $smtp->send(auth => {
            login => "$config->{'smtp'}{'username'}",
            password => "$config->{'smtp'}{'async_me'}"
        });

    if ($auth->error) {
        $self->app->log->error("Failed to auth smtp server: $config->{'smtp'}{'host'}" . $auth->error->{message});
        return
    }
    $self->app->log->debug("Auth to smtp server OK");

    my $ok = $smtp->send(
        from => "$config->{'smtp'}{'from'}",
        to   => "$params->{'to'}",
        data => "Subject: "
            . encode('utf8' , $params->{'subject'})
            . "\n\n"
            . encode('utf8' , $params->{'body'})
    );

    if ($ok->error) {
        $self->app->log->error("Failed to send email: " . $ok->error->{message});
        return
    }

    $self->app->log->debug('Email successfully sent');

}

sub _log_password_change {
    my ($self, $user_id) = @_;

    $self->schema->storage->dbh->do(
        "INSERT INTO mx_security_logs
     (user_id, event_type, ip_address, user_agent)
     VALUES (?, ?, ?, ?)",
    undef,
    $user_id,
    'password_change',
    $self->tx->remote_address,
    $self->req->headers->user_agent
    );
}

=head1 NAME

Seabattle::Controller::MX::Auth - Контроллер для аутентификации и авторизации в игре SeaBattle

=head1 SYNOPSIS

    # В Mojolicious router
    $r->post('/api/v2/register')->to(controller => 'MX::Auth', action => 'register');
    $r->post('/api/v2/auth')->to(controller => 'MX::Auth', action => 'auth');
    $r->post('/api/v2/refresh_auth')->to(controller => 'MX::Auth', action => 'refresh_auth');
    $r->post('/api/v2/verification_email')->to(controller => 'MX::Auth', action => 'verification_email');
    $r->get('/api/v2/verify')->to(controller => 'MX::Auth', action => 'verify');
    $r->patch('/api/v2/change_password')->to(controller => 'MX::Auth', action => 'change_password');

=head1 DESCRIPTION

Контроллер предоставляет функционал для регистрации, аутентификации, обновления токенов,
верификации email и смены пароля пользователей.

=head1 CONFIGURATION

Конфигурация берется из файла config/config.json, который должен содержать:

    {
        "redis": {
            "host": "хост Redis",
            "port": "порт Redis"
        },
        "domain": "домен приложения",
        "smtp": {
            "host": "SMTP сервер",
            "port": "SMTP порт",
            "username": "логин SMTP",
            "password": "пароль SMTP",
            "from": "email отправителя"
        }
    }

=head1 METHODS

=head2 register

    POST /api/v2/register

Регистрирует нового пользователя.

Параметры (JSON):
    - login: логин пользователя
    - email: email пользователя
    - password: пароль пользователя

Возвращает:
    - 201: пользователь успешно зарегистрирован
    - 400: не все поля заполнены или неверный формат email
    - 500: ошибка сервера при регистрации

=head2 auth

    POST /api/v2/auth

Аутентифицирует пользователя.

Параметры (JSON):
    - email: email пользователя
    - password: пароль пользователя

Возвращает:
    - 200: успешная аутентификация (устанавливает cookies access_token и refresh_token)
    - 400: email или пароль не указаны
    - 401: неверные учетные данные

=head2 verify_access_token

Внутренний метод для проверки access token.

Проверяет валидность токена в cookie и его наличие в Redis.

Возвращает:
    - user_id: если токен валиден
    - undef: если токен невалиден (устанавливает соответствующий JSON ответ)

=head2 me

    GET /api/v2/me

Возвращает базовую информацию об аутентифицированном пользователе.

Требования:
    - Действительный access token в cookies

Возвращаемые данные (JSON):
    - user_id: идентификатор пользователя
    - name: логин пользователя
    - rank: ранг пользователя

Коды статуса:
    - 200: информация успешно получена
    - 401: если access token недействителен или истек (через verify_access_token)

Пример ответа:
    {
        "user_id": 123,
        "name": "игрок1",
        "rank": "капитан"
    }

Запросы к базе данных:
    - Получает логин из таблицы mx_users
    - Получает ранг из таблицы mx_user_rank

Примечания:
    1. Для работы метода требуется предварительная аутентификация
    2. Метод сначала проверяет access token перед возвратом информации
    3. Возвращает только базовую информацию о пользователе
    4. Для получения расширенной информации следует использовать другие методы

Особенности реализации:
    - Использует подготовленные SQL-запросы для безопасности
    - Проверяет авторизацию через verify_access_token
    - Возвращает компактный JSON-ответ

=head2 refresh_auth

    POST /api/v2/refresh

Обновляет access и refresh токены.

Использует refresh token из cookies для генерации новых токенов.

Возвращает:
    - 200: токены успешно обновлены (устанавливает новые cookies)
    - 400: refresh token не найден в cookies
    - 401: refresh token истек
    - 404: refresh token не найден в базе

=head2 verify

    GET /api/v2/verify

Верифицирует email пользователя по токену из письма.

Параметры:
    - token: токен верификации

Возвращает:
    - 200: email успешно верифицирован
    - 400: токен не предоставлен или невалиден

=head2 verification_email

    POST /api/v2/verification_email

Отправляет письмо с подтверждением email.

Требует валидный access token.

Возвращает:
    - 200: письмо отправлено
    - 400: пользователь не найден или уже верифицирован

=head2 change_password

    PATCH /api/v2/change_password

Изменяет пароль пользователя.

Требует валидный access token.

Параметры (JSON):
    - old_password: текущий пароль
    - new_password: новый пароль (минимум 6 символов)

Возвращает:
    - 200: пароль успешно изменен
    - 403: неверный старый пароль или новый пароль слишком короткий

=head1 INTERNAL METHODS

=head2 _send_verification_email

Отправляет email с ссылкой для верификации.

Параметры:
    - email: email получателя
    - token: токен верификации

=head2 _generate_secure_token

Генерирует криптографически безопасный токен.

Возвращает:
    - строка с токеном

=head2 _notify_password_change

Отправляет уведомление об изменении пароля.

Параметры:
    - user_id: ID пользователя

=head2 _send_mail

Отправляет email через SMTP.

Параметры:
    - params: хэш с параметрами письма (to, subject, body)

=head2 _log_password_change

Логирует смену пароля в базу данных.

Параметры:
    - user_id: ID пользователя

=head1 DEPENDENCIES

    Mojo::Base, JSON, Digest::MD5, Date::Parse, Crypt::URandom,
    Mojo::Util, Mojo::SMTP::Client, Encode, Redis

=head1 AUTHOR

Виталий <v.petrenko@nic.ru>

=head1 LICENSE

MIT наверно, а там хз..

=cut

1;