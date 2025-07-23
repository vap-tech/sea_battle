package Seabattle::Controller::MX::Orders;
use Mojo::Base 'Mojolicious::Controller';
use Carp qw(croak);


sub create_order {
    my ($self, $user_id, $product_id, $amount) = @_;

    my $dbh = $self->schema->storage->dbh;

    my $query = q{
        INSERT INTO mx_orders (user_id, product_id, status, amount)
        VALUES (?, ?, 'created', ?)
    };

    $dbh->do($query, undef, $user_id, $product_id, $amount) or croak $dbh->errstr;
    my $order_id = $dbh->last_insert_id(undef, undef, 'orders', 'id');

    $self->_log_status_change($order_id, 'created');
    return $order_id;
}

sub mark_order_paid {
    my ($self, $order_id, $payment_id) = @_;

    my $dbh = $self->schema->storage->dbh;

    my $query = q{
        UPDATE mx_orders
        SET status = 'paid', payment_id = ?, paid_at = NOW()
        WHERE id = ?
    };

    $dbh->do($query, undef, $payment_id, $order_id) or croak $dbh->errstr;
    $self->_log_status_change($order_id, 'paid');

    $self->apply_boost($order_id);  # Активируем буст
    return 1;
}

sub apply_boost {
    my ($self, $order_id) = @_;

    my $dbh = $self->schema->storage->dbh;

    $dbh->do("UPDATE mx_orders SET status = 'processing' WHERE id = ?", undef, $order_id);
    $self->_log_status_change($order_id, 'processing');

    # Вызов API игры...
    my $api_success = $self->_mock_game_api($order_id);

    if ($api_success) {
        $dbh->do("UPDATE mx_orders SET status = 'completed' WHERE id = ?", undef, $order_id);
        $self->_log_status_change($order_id, 'completed');
    } else {
        $dbh->do("UPDATE mx_orders SET status = 'failed', error_message = 'API error' WHERE id = ?", undef, $order_id);
        $self->_log_status_change($order_id, 'failed');
    }
}

sub refund_order {
    my ($self, $order_id) = @_;
    my $dbh = $self->schema->storage->dbh;

    $dbh->do("UPDATE mx_orders SET status = 'refunded' WHERE id = ?", undef, $order_id) or croak $dbh->errstr;
    $self->_log_status_change($order_id, 'refunded');

    # Запрос к платежному шлюзу...
    $self->_mock_refund($order_id);
    return 1;
}

sub _log_status_change {
    my ($self, $order_id, $status) = @_;
    my $dbh = $self->schema->storage->dbh;

    $dbh->do(
        "INSERT INTO mx_order_status_history (order_id, status) VALUES (?, ?)",
        undef, $order_id, $status
    ) or warn "Failed to log status: " . $dbh->errstr;
}

# Заглушка для тестирования
sub _mock_game_api { return 1 }
sub _mock_refund { return 1 }

=head1 НАЗВАНИЕ

Seabattle::Controller::MX::Orders - Контроллер для работы с заказами в игруле Seabattle

=head1 СИНТАКСИС

    use Seabattle::Controller::MX::Orders;

    # Создание заказа
    my $order_id = $controller->create_order($user_id, $product_id, $amount);

    # Отметка заказа как оплаченного
    $controller->mark_order_paid($order_id, $payment_id);

    # Возврат средств по заказу
    $controller->refund_order($order_id);

=head1 ОПИСАНИЕ

Контроллер для управления жизненным циклом заказов в игре Seabattle.
Обеспечивает:
- Создание новых заказов
- Обработку оплаты заказов
- Применение игровых бустов
- Возврат средств

=head1 МЕТОДЫ

=head2 create_order($user_id, $product_id, $amount)

Создает новый заказ в системе.

Параметры:
- $user_id - ID пользователя
- $product_id - ID продукта
- $amount - Сумма заказа

Возвращает:
- ID созданного заказа

Исключения:
- Вызывает croak при ошибке базы данных

=head2 mark_order_paid($order_id, $payment_id)

Отмечает заказ как оплаченный и активирует игровой буст.

Параметры:
- $order_id - ID заказа
- $payment_id - ID платежа

Возвращает:
- 1 в случае успеха

Исключения:
- Вызывает croak при ошибке базы данных

=head2 apply_boost($order_id)

Применяет игровой буст, связанный с заказом.

Параметры:
- $order_id - ID заказа

Логика:
1. Устанавливает статус 'processing'
2. Вызывает API игры (заглушка в текущей реализации)
3. При успехе устанавливает статус 'completed'
4. При ошибке устанавливает статус 'failed'

=head2 refund_order($order_id)

Обрабатывает возврат средств по заказу.

Параметры:
- $order_id - ID заказа

Возвращает:
- 1 в случае успеха

Исключения:
- Вызывает croak при ошибке базы данных

=head1 ВНУТРЕННИЕ МЕТОДЫ

=head2 _log_status_change($order_id, $status)

Логирует изменение статуса заказа в историю.

Параметры:
- $order_id - ID заказа
- $status - Новый статус

=head2 _mock_game_api($order_id)

Заглушка для имитации вызова API игры (всегда возвращает успех).

=head2 _mock_refund($order_id)

Заглушка для имитации процесса возврата платежа.

=head1 ТРЕБОВАНИЯ К БАЗЕ ДАННЫХ

Модуль предполагает наличие следующих таблиц:

1. orders - таблица заказов с полями:
   - id
   - user_id
   - product_id
   - status
   - amount
   - payment_id
   - paid_at
   - error_message

2. order_status_history - история статусов заказов:
   - order_id
   - status
   - created_at (автоматически)

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