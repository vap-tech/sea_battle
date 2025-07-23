package Seabattle::Auth::Utils;

use warnings;
use strict;
use feature 'say';
use List::Util 'shuffle';
use Modern::Perl;
use Mojo::SMTP::Client;
use Mojo::Transaction;
use utf8;
use base 'Exporter';
our @EXPORT_OK = qw(
    is_valid_credentials
    check_credentials
    is_valid_email
    is_valid_pass
    email_exists
    generate_secure_password
    send_email
);


# Валидация email и пароля
sub is_valid_credentials {
    my ($email, $password) = @_;
    my $error = '';

    unless ( is_valid_email($email) ) {
        $error = 'Неверный формат email';
        return $error;
    }
    unless ( is_valid_pass($password) ) {
        $error = 'Неверный формат пароля';
        return $error;
    }
}

# Проверка наличия email и пароля в БД
sub check_credentials {
    my ($c, $email, $password, $error, $user_id) = @_;

    # Проверка наличия email в БД
    unless ( email_exists($c, $email) ) {
        $error = 'Неверная почта';
        return ($error, $user_id);
    }

    # Проверка наличия пароля в БД
    ($error, $user_id) = check_pass($c, $email, $password);
    return ($error, $user_id);
}

# Валидация email
sub is_valid_email {
    my ($email) = @_;

    # Проверяем что в $email есть @ и только один
    return 0 unless $email =~ / ^[^@]+ @ [^@]+$ /x;

    my ($local_part, $domain_tld) = split '@', $email;
    
    # Проверка $local_part (часть до @)
    return 0 unless $local_part =~ / ^[A-Za-z0-9] (?: [A-Za-z0-9.+_-]* [A-Za-z0-9])?$ /x;
    return 0 if $local_part =~ /\.\.|--/;

    # Проверка $domain (часть после @)
    my @domain_parts = split m/\./, $domain_tld;
    my $tld = pop(@domain_parts);
    return 0 unless $tld =~ / ^[A-Za-z]{2,}$ /x;

    my $domain = join '.', @domain_parts;
    return 0 unless $domain =~ / ^[A-Za-z0-9] (?: [A-Za-z0-9-.]* [A-Za-z0-9] )?$ /x;
    return 0 if $domain =~ /\.\.|--/x;

    return 1;
}

# Проверка наличия email в БД
sub email_exists {
    my ($c, $email) = @_;

    return 1 if $c->schema->resultset('User')->search( {email => $email} )->count > 0;
    return 0;
}

# Валидация пароля
sub is_valid_pass {
    my ($pass) = @_;

    return 0 unless defined $pass && length $pass >= 6;

    return $pass =~ / ^(?=.*[A-Z]) (?=.*[%*?@#!\$]) [A-Za-z0-9%*?@#!\$]{6,}$ /x;
}

# Проверка наличия пароля в БД
sub check_pass {
    my ($c, $email, $pass, $error) = @_;

    # Получаем хеш пароля из БД
    my $user = $c->schema->resultset('User')->find({email => $email});
    my $hash_pass = $user->password_hash;

    # Сравниваем пароли
    if ( $c->bcrypt_validate($pass, $hash_pass) ) {
        return ($error, $user->id);
    }
    else {
        $error = 'Неверный пароль';
        return $error;
    }
}

=head2 generate_secure_password

Генерирует случайный пароль, соответствующий требованиям сложности.

    my $password = generate_secure_password();

=head3 Описание

Создает пароль со следующими характеристиками:
- Длина: случайная от 6 до 9 символов
- Содержит латинские буквы обоих регистров (A-Z, a-z)
- Обязательно включает:
  * минимум 1 заглавную букву
  * минимум 1 специальный символ из набора: % * ? @ # $ !
- Все символы в пароле перемешиваются

=head3 Возвращаемое значение

Возвращает строку C<$password> со сгенерированным паролем.

=cut

sub generate_secure_password {

    my $length = 6 + int(rand(4));

    # Наборы символов
    my @lowercase = ('a' .. 'z');
    my @uppercase = ('A' .. 'Z');
    my @special = split //, '%*?@#$!';

    # Гарантируем минимум 1 заглавную и 1 спецсимвол
    my $password = '';
    $password .= $uppercase[rand @uppercase]; # минимум 1 заглавная
    $password .= $special[rand @special];     # минимум 1 спецсимвол

    # Добавляем остальные символы (только буквы)
    while (length $password < $length) {
        my @chars = (rand() > 0.5) ? @lowercase : @uppercase;
        $password .= $chars[rand @chars];
    }

    # Перемешиваем результат
    $password = join '', shuffle split //, $password;

    return $password;
}

=head2 send_email

Отправляет новый пароль на email клиента. Использует SMTP с настройками из конфига.

    send_email($email, $password, $c);

Параметры:

=over 4

=item B<email> - адрес электронной почты получателя;

=item B<password> - Пароль клиента;

=item B<c> - Объект контроллера Mojolicious;

=back

Возвращает 1 при успехе, 0 при ошибке. Также все ошибки записываются в логи.

=cut

sub send_email {
    my ($email, $password, $c) = @_;

    # Получаем конфиг
    my $config = $c->app->config->{email};

    # Создаем SMTP клиент
    my $smtp = Mojo::SMTP::Client->new(%$config) or do {
        $c->app->log->error("Failed to create SMTP client");
        return 0;
    };


   # Формируем письмо
    my $message = <<"END_MSG";
From: example\@seabattle.local
To: $email
Subject: Ваш новый пароль
Content-Type: text/plain; charset=UTF-8

Ваш пароль: $password
END_MSG

    # Отправляем письмо
    my $tx = $smtp->send(
        from => 'example@seabattle.local',
        to   => $email,
        data => $message
    );

    # Возвращаем 1 при успехе, 0 при ошибке
    if ($tx->error) {
        $c->app->log->error("Failed to send email to $email: " . $tx->error->{message});
        return 0;
    }
    else {
         $c->app->log->info("Email successfully sent to $email");
    return 1;
    }
}

1;