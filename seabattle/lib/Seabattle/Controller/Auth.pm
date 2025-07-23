package Seabattle::Controller::Auth;
use Modern::Perl;
use Mojo::Base 'Mojolicious::Controller';
use Mojo::Util qw(trim);
use Seabattle::Auth::Utils qw(
    is_valid_credentials
    check_credentials
    is_valid_email
    email_exists
    generate_secure_password
    send_email
);

=head2 login_form : GET /login

Отображает форму входа.

Рендерит шаблон auth/login

=cut
sub login_form {
    my $c = shift;

    $c->render( template => 'auth/login' );
}

=head2 login : POST /login

Проверяет есть ли пользователь в базе данных. Проверка идет по email. Email берем из формы GET /login

Если пользователь есть в базе данных:
- Сохраняет email в сессии;
- Перенаправляет на аутентификацию (/auth);

Если пользователя нет в базе данных, то:
- Генерирует пароль для пользователя;
- Сохраняет пользователя в базе данных;
- Устанавливает сессию;
- Отправляет пароль на электронную почту клиента;
- Перенаправляет пользователя на страницу /registred;

=over 4

=item B<email> - адрес электронной почты клиента.

=back

Возвращает HTTP-редирект.

=cut
sub login {
    my ($c) = @_;

     # Получаем email из параметров запроса
    my $email = $c->param('email') || '';

    # Проверяем валидность email
    unless (is_valid_email( $c, $email )) {
        return $c->render(
        error => 'Неверный формат электронной почты',
        status => 400
        );
    }

    # Проверяем наличие в БД (0 или 1)
    my $email_exists = email_exists( $c, $email );

    if ($email_exists) {
        # Email найден - сохраняем в session и редирект на /auth
        $c->session( email => $email );

        return $c->redirect_to('/auth');

    } else {
        # Email не найден - отправляем письмо и редирект на /registred

        # Генерируем пароль
        my $password = generate_secure_password();

        # Получаем схему их хелпера
        my $schema = $c->schema;

        my $ppr = $c->bcrypt($password);

        # Создаем пользователя и получаем его id
        my $user = $schema->resultset('User')->create({
            email         => $email,
            password_hash => $ppr,
            nickname      => $email,
        });

        # Устанавливаем сессию
        my $user_id = $user->id;
        $c->session({user_id => $user_id,});

        # Редирект на /registred
        $c->redirect_to('/registred');

        Mojo::IOLoop->next_tick( sub { send_email($email, $password, $c);});

        return
    }
}

# GET /auth - форма с email и password
sub auth_form {
    my ($c) = @_;
    my $email = $c->session('email') || '';

    # Редирект в ЛК, если юзер уже авторизован
    return $c->redirect_to('/account') if $c->is_authenticated;
    
    $c->render(
        template => 'authorization',
        email => $email
    );
}

# POST /auth - авторизация
sub authorization {
    my ($c) = @_;

    # Редирект в ЛК, если юзер уже авторизован
    return $c->redirect_to('/account') if $c->is_authenticated;

    # Получаем креды из запроса
    my $email    = $c->param('email') || '';
    my $password = $c->param('password') || '';
    # Переменные для ошибок и ID юзера
    my $error;
    my $user_id;
    # Счетчик попыток ввода пароля
    my $attempts = $c->session('auth_attempts') || 0;

    # Валидация email и пароля
    $error = is_valid_credentials($email, $password);
    if ($error) {
        return $c->render(
            error => $error,
            email => $email
        );
    }
    
    # Проверка email и пароля в БД
    ($error, $user_id) = check_credentials($c, $email, $password);
    # Обработка ошибок
    if ( $error eq 'Неверная почта' ) {
        return $c->render(
            error => $error,
            email => $email
        );
    }
    elsif ( $error eq 'Неверный пароль' ) {
        # Проверка лимита попыток ввода пароля
        $attempts++;
        $c->session( auth_attempts => $attempts );
        # Если попыток больше или равно 5 - восстаналиваем пароль
        if ( $attempts >= 5 ) {
            $c->session( email => $email );
            return $c->redirect_to('/recovery');
        }

        # Если попыток меньше 5 - возвращаем ошибку
        return $c->render(
            error => $error,
            email => $email
        );
    }

    # Если все проверки пройдены, авторизуем юзера
    # Обновляем время последнего логина в БД
    $c->schema->resultset('User')->find($user_id)->update({
        last_login => \'NOW()'
    });
    # Перезаписываем сессию. Добавлям в сессию ID юзера
    $c->session( {user_id => $user_id} );
    # Перенаправляем в ЛК 
    $c->redirect_to('/account');
}

=head2 login_form : GET /registred

Отображает форму входа.

Рендерит шаблон auth/registred

=cut
sub registred {
    my $self = shift;

    $self->render(template => 'auth/registred');
}

# Экшен восстановления пароля
sub recovery {
    my ($c) = @_;
    # Получатель письма
    my $recipient;

    # Если было >=5 неудачных попыток ввода пароля - берем имейл из сессии (передан из authorization)
    # Если меньше - значит клиент нажал кнопку "восстановить пароль" (передан из формы)
    $recipient = $c->session('auth_attempts') >= 5 
        ? $c->session('email') 
        : $c->param('email');

    # Валидируем $recipient
    my $result_valid = is_valid_email($recipient);
    # Проверяем наличие $recipient в БД
    my $result_exists = email_exists($recipient);

    # Если $recipient прошел проверки - сбрасываем пароль
    if ( $result_valid && $result_exists ) {
        # Генерируем новый пароль
        my $new_password = generate_secure_password();
        my $hash_new_password = $c->bcrypt($new_password);
        
        # Отправляем письмо с новым паролем
        if ( send_email( $recipient, $new_password, $c ) ) {
            # Записываем хеш нового пароля в БД
            $c->schema->resultset('User')->find({ email => $recipient })->update({
                password_hash => $hash_new_password
            });
            # Обнуляем число попыток ввода пароля
            $c->session( auth_attempts => 0 );
        }

        return $c->render();
    }
    # На текущий момент не знаю как реализовать обработку ошибок и надо ли (по БТ нет). 
    # Условно принимаем (согласно БТ), что юзер на странице /auth не будет редактировать имейл.
    # elsif ( $result_valid == 0 ) {}
    # elsif ( $result_exists == 0 ) {}   
}

sub logout {
    my ($c) = @_;

    # Проверка авторизации
    return $c->redirect_to('/') unless $c->is_authenticated;

    # Удаляем данные сессии
    $c->session(expires => 1);
    delete $c->session->{user_id};

    # Перенаправляем на индексную страницу
    $c->redirect_to('/');
}

1;