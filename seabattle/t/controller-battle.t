use Mojo::Base -strict;
use Test::More;
use Test::Mojo;

my $t = Test::Mojo->new('Seabattle');

# Cases 1-2: Подключение двух клиентов к WebSocket
my $alice_ws = $t->websocket_ok('/battle-ws');
my $bob_ws = $t->websocket_ok('/battle-ws');

# Cases 3-4: Регистрируем обоих пользователей
$alice_ws->send_ok({ json => { type => 'connect', payload => { username => 'Alice' } } });
$bob_ws->send_ok({ json => { type => 'connect', payload => { username => 'Bob' } } });

# Cases 5-9: Ждём подтверждений от сервера
$alice_ws->message_ok()->json_message_is('/type', 'response', 'Alice connected');
$bob_ws->message_ok()->json_message_is('/type', 'response', 'Bob connected');

# Case 10: Отправляем сообщение от Alice к Bob
$alice_ws->send_ok({ json => { type => 'chat', payload => { to_user => 'Bob', text => 'Hello, Bob!' } } });

# Case 11: Ждём сообщение на стороне Bob'a
$bob_ws->message_ok()->json_message_is('/payload/text', 'Hello, Bob!', 'Bob получил сообщение от Alice');

# Проверяем, что Alice не получила собственное сообщение
$alice_ws->message_unlike(qr/Hello, Bob!/x, 'Alice не получила свое сообщение');

done_testing();