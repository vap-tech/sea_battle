package Seabattle::Controller::MX::Token;
use strict;
use warnings FATAL => 'all';
use JSON qw( decode_json );
use JSON::WebToken;


my $config = decode_json do { local (@ARGV, $/) = ('./config/config.json'); <> };
my $secret_key = "$config->{'jwt'}{'async_me'}";

sub generate_access_token {
    my ($user_id) = @_;

    my %payload = (
        iss => "$config->{'domain'}",          # Издатель токена
        exp => time + 3600,                    # Срок действия
        iat => time,                           # Время выпуска
        jti => rand(),                         # Уникальный идентификатор токена
        sub => $user_id,                       # Идентификатор пользователя
    );

    my $token = JSON::WebToken->encode(\%payload, $secret_key, 'HS256');

    return $token;
}

sub generate_refresh_token {
    my ($user_id) = @_;

    my %payload = (
        iss => "$config->{'domain'}",         # Издатель токена
        exp => time + 604800,                 # Срок действия
        iat => time,                          # Время выпуска
        jti => rand(),                        # Уникальный идентификатор токена
        sub => $user_id,                      # Идентификатор пользователя
    );

    my $jwt = JSON::WebToken->encode(\%payload, $secret_key, 'HS256');

    return $jwt;
}

sub verify_token {
    my ($token) = @_;

    my $payload = {};
    eval {
        $payload = JSON::WebToken->decode($token, $secret_key, 1, ['HS256']);
        1;
    }
        or do {
        warn "Error decoding JWT: $@\n";
        return undef;
    };

    return $payload;
}

sub update_tokens {
    my ($refresh_token) = @_;

    my $payload = verify_refresh_token($refresh_token);
    unless (defined $payload) {
        return {error => 'Invalid refresh token'};
    }

    my $access_token = generate_access_token($payload->{sub});
    my $new_refresh_token = generate_refresh_token($payload->{sub});

    return {
        access_token => $access_token,
        refresh_token => $new_refresh_token,
    };
}

=head1 НАЗВАНИЕ

Token - Модуль для работы с JWT токенами (access и refresh токены)

=head1 СИНТАКСИС

    use Seabattle::Controller::MX::Token;

    # Создание access токена
    my $access_token = Seabattle::Controller::MX::Token::generate_access_token($user_id);

    # Создание refresh токена
    my $refresh_token = Seabattle::Controller::MX::Token::generate_refresh_token($user_id);

    # Проверка refresh токена
    my $payload = Seabattle::Controller::MX::Token::verify_refresh_token($refresh_token);

    # Обновление пары токенов
    my $tokens = Seabattle::Controller::MX::Token::update_tokens($old_refresh_token);

=head1 ОПИСАНИЕ

Модуль предоставляет функциональность для работы с JSON Web Tokens (JWT):
- Генерация access токенов (краткосрочных)
- Генерация refresh токенов (долгосрочных)
- Верификация refresh токенов
- Обновление пар токенов (получение новых access и refresh токенов)

Модуль использует секретный ключ из конфигурационного файла ('./config/config.json')
и алгоритм HS256 для подписи токенов.

=head1 КОНФИГУРАЦИЯ

Модуль требует наличия конфигурационного файла './config/config.json' со следующей структурой:

    {
        "jwt": {
            "async_me": "ваш_секретный_ключ"
        },
        "domain": "ваш_домен"
    }

=head1 ПОДПРОГРАММЫ

=head2 generate_access_token($user_id)

Генерирует краткосрочный JWT access токен (действителен 1 час).

Параметры:
- $user_id - Идентификатор пользователя для включения в токен

Возвращает:
- Строку с JWT access токеном

=head2 generate_refresh_token($user_id)

Генерирует долгосрочный JWT refresh токен (действителен 1 неделю).

Параметры:
- $user_id - Идентификатор пользователя для включения в токен

Возвращает:
- Строку с JWT refresh токеном

=head2 verify_token($token)

Проверяет токен и возвращает его payload если токен валиден.

Параметры:
- $token - JWT токен для проверки

Возвращает:
- Хэш с содержимым токена если валиден
- undef если токен невалиден

=head2 update_tokens($refresh_token)

Проверяет refresh токен и генерирует новую пару access и refresh токенов.

Параметры:
- $refresh_token - Валидный refresh токен

Возвращает:
- Хэш с новыми токенами:
    {
        access_token => 'новый_access_токен',
        refresh_token => 'новый_refresh_токен'
    }
- Хэш с ошибкой если refresh токен невалиден:
    {
        error => 'Невалидный refresh токен'
    }

=head1 ЗАВИСИМОСТИ

- JSON
- JSON::WebToken

=head1 АВТОР

Виталий <v.petrenko@nic.ru>

=head1 ЛИЦЕНЗИЯ

Это свободное программное обеспечение, вы можете распространять и/или изменять
его на тех же условиях, что и Perl.

=cut

1;