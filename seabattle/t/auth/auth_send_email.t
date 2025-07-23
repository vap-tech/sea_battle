use Modern::Perl;
use utf8;
use Test::More;
use Test::MockModule;
use Test::MockObject;
use FindBin;
use lib "$FindBin::Bin/../../lib";
use open ':std', ':encoding(UTF-8)';

our $last_email;

BEGIN { use_ok('Seabattle::Auth::Utils') }

# Mock для логгера
my $mock_log = Test::MockObject->new();
$mock_log->mock('debug', sub {});
$mock_log->mock('info', sub {});
$mock_log->mock('error', sub {});

# Mock для приложения
my $mock_app = Test::MockObject->new();
$mock_app->mock('log', sub { $mock_log });
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

# Mock для контроллера
my $mock_controller = Test::MockObject->new();
$mock_controller->mock('app', sub { $mock_app });

# Mock для SMTP клиента
my $mock_smtp = Test::MockModule->new('Mojo::SMTP::Client');
$mock_smtp->mock('new', sub { bless {}, shift });

# Тест успешной отправки
subtest 'Successful sending' => sub {
    $mock_smtp->mock('send', sub {
        my ($self, %params) = @_;
        $last_email = \%params;
        return bless { error => undef }, 'Mojo::Transaction';
    });

    my $result = Seabattle::Auth::Utils::send_email('test@example.com', 'pass123', $mock_controller);
    is($result, 1, 'return 1 on success');
};

# Тест ошибки отправки
subtest 'Send error' => sub {
    my $mock_tx = Test::MockObject->new();
    $mock_tx->mock('error', sub {
        return {
            code => 500,
            message => 'Test error message'
        };
    });

    $mock_smtp->mock('send', sub {
        my ($self, %params) = @_;
        $last_email = \%params;
        return $mock_tx;
    });

    my $result = Seabattle::Auth::Utils::send_email('test@example.com', 'pass123', $mock_controller);
    is($result, 0, 'return 0 on error');
};

# Тест содержимого письма
subtest 'Email content' => sub {
    $mock_smtp->mock('send', sub {
        my ($self, %params) = @_;
        $last_email = \%params;
        return bless { error => undef }, 'Mojo::Transaction';
    });

    Seabattle::Auth::Utils::send_email('test@example.com', 'pass123', $mock_controller);

    like($last_email->{data}, qr/^From: example\@seabattle.local/m, 'From header correct');
    like($last_email->{data}, qr/^To: test\@example.com/m, 'To header correct');
    like($last_email->{data}, qr/^Subject: Ваш новый пароль/m, 'Subject correct');
    like($last_email->{data}, qr/Content-Type: text\/plain; charset=UTF-8/, 'Content-Type correct');
    like($last_email->{data}, qr/Ваш пароль: pass123/, 'Password pattern correct');
};

# Проверка вызова логгера
$mock_log->mock('error', sub {
    my ($self, $msg) = @_;
    like($msg, qr/Test error message/, 'Error logged correctly');
});

done_testing();