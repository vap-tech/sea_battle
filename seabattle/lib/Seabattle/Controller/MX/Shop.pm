package Seabattle::Controller::MX::Shop;
use Mojo::Base qw(Mojolicious::Controller Mojo::Cookie);
use JSON qw(decode_json encode_json);
use strict;
use warnings FATAL => 'all';
use Carp qw(croak);

use Seabattle::Controller::MX::Token;

my $config = decode_json do { local (@ARGV, $/) = ('config/config.json'); <> };
my $redis = Redis->new(server => "$config->{'redis'}{'host'}:$config->{'redis'}{'port'}");


sub list_boosts {
    my ($self) = @_;

    my $dbh = $self->schema->storage->dbh;

    my $type      = $self->param('type');
    my $last_id   = $self->param('last_id');
    my $limit     = $self->param('limit') || 5;

    my $query = "
        SELECT id, name, price, description, game_effect
        FROM mx_boosts
        WHERE is_active = 1
    ";
    my @bind_params;

    if (defined $type) {
        $query .= " AND type = ?";
        push @bind_params, $type;
    }

    if (defined $last_id) {
        $query .= " AND id > ?";
        push @bind_params, $last_id;
    }

    $query .= " ORDER BY id ASC LIMIT ?";
    push @bind_params, $limit;

    my $boosts = $dbh->selectall_arrayref($query, { Slice => {} }, @bind_params);

    my $next_last_id;
    if (@$boosts) {
        $next_last_id = $boosts->[-1]{id};
    }

    $self->render(json => {
        boosts      => $boosts,
        next_last_id => $next_last_id
    });
}

# Купить уст (POST /api/v2/shop/boosts/:id/buy)
sub buy_boost {
    my ($self) = @_;

    my $dbh = $self->schema->storage->dbh;

    my $user_id   = $self->_verify_access_token();
    my $boost_id  = $self->stash('id');
    my $promocode = undef;

    # Проверяем промокод
    my $discount = 0;
    if (defined $promocode) {
        my $promo_data = $dbh->selectrow_hashref(
            "SELECT discount_percent, boost_id, expires_at, max_uses, current_uses
             FROM mx_promocodes WHERE code = ?",
            undef, $promocode
        ) or return $self->render(json => { error => "Invalid promocode" }, status => 400);

        # Валидация промокода
        if ($promo_data->{expires_at} && DateTime->now > $promo_data->{expires_at}) {
            return $self->render(json => { error => "Promocode expired" }, status => 400);
        }
        if ($promo_data->{current_uses} >= $promo_data->{max_uses}) {
            return $self->render(json => { error => "Promocode uses exceeded" }, status => 400);
        }
        if ($promo_data->{boost_id} && $promo_data->{boost_id} != $boost_id) {
            return $self->render(json => { error => "Promocode not valid for this boost" }, status => 400);
        }

        $discount = $promo_data->{discount_percent};
    }

    eval {
        $dbh->begin_work;

        my ($price) = $dbh->selectrow_array(
            "SELECT price FROM mx_boosts WHERE id = ?", undef, $boost_id
        );

        my $final_price = $price * (1 - $discount / 100);

        # 1. Проверяем текущий баланс
        my $sth = $dbh->prepare("SELECT amount FROM mx_user_amount WHERE user_id = ? FOR UPDATE");
        $sth->execute($user_id);
        my $row = $sth->fetchrow_hashref;

        unless ($row && $row->{amount} >= $final_price) {
            $dbh->rollback;
            return $self->render(json => {
                error => 'Insufficient funds',
                current_balance => $row ? $row->{amount} : 0,
                required_amount => $final_price
            }, status => 402); # 402 Payment Required
        }

        # 2. Списание
        $sth = $dbh->prepare(
            "UPDATE mx_user_amount SET amount = amount - ? WHERE user_id = ?"
        );
        $sth->execute($final_price, $user_id);

        $dbh->do(
            "INSERT INTO mx_user_inventory (user_id, boost_id) VALUES (?, ?)
             ON DUPLICATE KEY UPDATE quantity = quantity + 1",
            undef, $user_id, $boost_id
        );

        $dbh->do(
            "INSERT INTO mx_boost_popularity (boost_id, purchases_count, last_purchased_at)
             VALUES (?, 1, NOW())
             ON DUPLICATE KEY UPDATE
                purchases_count = purchases_count + 1,
                last_purchased_at = NOW()",
            undef, $boost_id
        );

        if (defined $promocode) {
            $dbh->do(
                "UPDATE mx_promocodes SET current_uses = current_uses + 1 WHERE code = ?",
                undef, $promocode
            );
        }

        $dbh->commit;
        $self->render(json => {
            success => 1,
            price => $final_price,
            discount => $discount
        });
    } or do {
        $dbh->rollback;
        $self->render(json => { error => "Purchase failed: $@" }, status => 500);
    };
}

# Топ популярных бустов (GET /api/v2/shop/boosts/top?limit=5)
sub top_boosts {
    my ($self) = @_;

    my $dbh = $self->schema->storage->dbh;
    my $limit = $self->param('limit') || 5;

    my $top = $dbh->selectall_arrayref(
        "SELECT b.id, b.name, bp.purchases_count
         FROM mx_boost_popularity bp
         JOIN mx_boosts b ON bp.boost_id = b.id
         ORDER BY bp.purchases_count DESC
         LIMIT ?",
        { Slice => {} },
        $limit
    );

    $self->render(json => { top_boosts => $top });
}

sub _verify_access_token {
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


=head1 НАЗВАНИЕ

Seabattle::Controller::MX::Shop - Контроллер магазина игровых бустов для системы Seabattle

=head1 СИНТАКСИС

    use Seabattle::Controller::MX::Shop;

    # Получить список бустов с фильтрацией
    $controller->list_boosts();

    # Купить буст (с промокодом)
    $controller->buy_boost();

    # Получить топ популярных бустов
    $controller->top_boosts();

=head1 ОПИСАНИЕ

Контроллер предоставляет функционал для работы с магазином игровых бустов:
- Получение списка доступных бустов с фильтрацией и пагинацией
- Покупка бустов (с учетом промокодов)
- Получение статистики популярности бустов

=head1 МЕТОДЫ

=head2 list_boosts()

Возвращает список доступных бустов с возможностью фильтрации и пагинации.

Параметры запроса:
- type - Фильтр по типу буста (damage/defense/speed)
- last_id - ID последнего полученного буста (для курсорной пагинации)
- limit - Количество возвращаемых элементов (по умолчанию 10)

Возвращает:
- Массив бустов в формате JSON
- next_last_id - ID для получения следующей страницы

Пример ответа:
    {
        "boosts": [
            {"id": 1, "name": "Двойной урон", "price": 100},
            {"id": 2, "name": "Защитный щит", "price": 150}
        ],
        "next_last_id": 2
    }

=head2 buy_boost()

Обрабатывает покупку буста пользователем.

Параметры запроса:
- boost_id - ID покупаемого буста
- promocode - Промокод для скидки (опционально)

Логика работы:
1. Проверяет валидность промокода
2. Рассчитывает итоговую цену с учетом скидки
3. В транзакции:
   - Добавляет буст в инвентарь пользователя
   - Обновляет статистику популярности
   - Учитывает использование промокода
4. Возвращает итоговую цену и размер скидки

Возможные ошибки:
- 400: Невалидный промокод
- 400: Промокод просрочен
- 400: Лимит использований промокода исчерпан
- 400: Промокод не применим к данному бусту
- 500: Ошибка при обработке покупки

=head2 top_boosts()

Возвращает топ самых популярных бустов.

Параметры запроса:
- limit - Количество возвращаемых бустов (по умолчанию 5)

Возвращает:
- Массив самых популярных бустов с количеством покупок

Пример ответа:
    {
        "top_boosts": [
            {"id": 3, "name": "Ускорение", "purchases_count": 42},
            {"id": 1, "name": "Двойной урон", "purchases_count": 38}
        ]
    }

=head1 ТРЕБОВАНИЯ К БАЗЕ ДАННЫХ

Модуль предполагает наличие следующих таблиц:

1. boosts - таблица игровых бустов:
   - id - идентификатор буста
   - name - название буста
   - price - цена
   - is_active - флаг активности
   - game_effect - JSON с эффектом буста

2. promocodes - таблица промокодов:
   - code - код промокода
   - discount_percent - процент скидки
   - boost_id - привязка к конкретному бусту (опционально)
   - expires_at - срок действия
   - max_uses - максимальное количество использований
   - current_uses - текущее количество использований

3. user_inventory - инвентарь пользователей:
   - user_id - ID пользователя
   - boost_id - ID буста
   - quantity - количество

4. boost_popularity - статистика популярности:
   - boost_id - ID буста
   - purchases_count - количество покупок
   - last_purchased_at - дата последней покупки

=head1 ЗАВИСИМОСТИ

- Mojo::Base
- Carp

=head1 АВТОР

Виталий <v.petrenko@nic.ru>

=head1 ЛИЦЕНЗИЯ

Это свободное программное обеспечение, вы можете распространять и/или изменять
его на тех же условиях, что и Perl.

=cut

1;