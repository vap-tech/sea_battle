package Seabattle::Controller::UserArea;
use strict;
use warnings FATAL => 'all';
use JSON qw(decode_json);
use Redis;

use Seabattle::Controller::MX::Token;


my $config = decode_json do { local (@ARGV, $/) = ('config/config.json'); <> };
my $redis = Redis->new(server => "$config->{'redis'}{'host'}:$config->{'redis'}{'port'}");


sub edit_profile {
    my ($self) = @_;

    my $dbh           = $self->schema->storage->dbh;
    my $json          = $self->req->json;
    my $refresh_token = $self->req->headers->cookie('refreshToken')->value;
    my $payload       = Seabattle::Controller::MX::Token::verify_refresh_token($refresh_token);
    my $user_id       = $payload->{sub};

    my $user_name     = $json->{'userName'} // '';
    my $org_name      = $json->{'orgName'} // '';
    my $department    = $json->{'department'} // '';
    my $position      = $json->{'position'} // '';

    my $access_token = $redis->get("access_token:$user_id");

    unless (defined $access_token) {
        return $self->render(json => {error => 'Access token not found'}, status => 403);
    }

    foreach my $field ($user_name, $org_name, $department, $position) {
        next unless defined $field;
        unless ($field =~ /^[a-zA-Z0-9\s]+$/) {
            return $self->render(json => {error => 'Field contains invalid characters'}, status => 400);
        }
    }

    $dbh->do(
        "UPDATE mx_user_profiles
        SET user_name = ?, org_name = ?, department = ?, position = ?
        WHERE user_id = ?",
        undef,
        $user_name, $org_name, $department, $position,
        $user_id
    );

    return $self->render(json => {message => 'Profile updated successfully'}, status => 200);
};

=head1 НАЗВАНИЕ

Seabattle::Controller::UserArea - Контроллер личного кабинета пользователя

=head1 СИНТАКСИС

    use Seabattle::Controller::UserArea;

    # Редактирование профиля пользователя
    $controller->edit_profile();

=head1 ОПИСАНИЕ

Контроллер предоставляет функционал для работы с личным кабинетом пользователя,
включая редактирование профиля.

=head1 МЕТОДЫ

=head2 edit_profile()

Обновляет информацию профиля пользователя.

Параметры (JSON):
- userName - Имя пользователя
- orgName - Название организации
- department - Отдел/подразделение
- position - Должность

Требования:
- Действительный refresh_token в cookies
- Соответствующий access_token в Redis
- Поля должны содержать только буквы, цифры и пробелы

Возвращает:
- 200 OK при успешном обновлении
- 400 Bad Request при невалидных данных
- 403 Forbidden при отсутствии токена доступа

Пример запроса:
    {
        "userName": "Иван Петров",
        "orgName": "ООО Рога и Копыта",
        "department": "IT отдел",
        "position": "Разработчик"
    }

=head1 ТРЕБОВАНИЯ К БАЗЕ ДАННЫХ

Требуется таблица mx_user_profiles:
- user_id - ID пользователя (внешний ключ)
- user_name - Имя пользователя
- org_name - Название организации
- department - Отдел
- position - Должность

=head1 КОНФИГУРАЦИЯ

Требуется конфигурационный файл config/config.json:
    {
        "redis": {
            "host": "адрес_redis",
            "port": "порт_redis"
        }
    }

=head1 ЗАВИСИМОСТИ

- JSON
- Redis
- Seabattle::Controller::MX::Token

=head1 АВТОР

Виталий <v.petrenko@nic.ru>

=head1 ЛИЦЕНЗИЯ

Это свободное программное обеспечение, вы можете распространять и/или изменять
его на тех же условиях, что и Perl.

=cut

1;