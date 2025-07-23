# Шаблон приложения seabattle

## Запуск приложения

* Локально:
    - `morbo seabattle/script/seabattle`; 

* В docker-compose:
    - переименовать `.env.example` в `.env`. 
    - загрузить переменные окружения из `.env` в вашу среду оболочки. 
    - `docker-compose up -d` поднимает:
        - Контейнер `seabattle_app` с запущенным дефолтным приложением Mojo. 
        - Контейнер `seabattle_db` с MariaDB:10.11 и базой данных `seabattle_db`.

* Опционально: 
    - Можно развернуть только БД из `build/database/Dockerfile` командой:
        ```shell
        docker build -t seabattle-db -f build/database/Dockerfile seabattle/sql/
        ```
    - Запуск контейнера:
        ```shell
        docker run -d \
            -e MARIADB_ROOT_PASSWORD=${DB_ROOT_PASSWORD} \
            -e MARIADB_DATABASE=${DB_NAME} \
            -e MARIADB_USER=${DB_USER} \
            -e MARIADB_PASSWORD=${DB_PASSWORD} \
            seabattle-db
        ```


## Миграции

* Файлы миграции можно размещать в `seabattle/sql/migrate/`. Сейчас там 2 файла  `001_create_users.sql` и `002_create_sessions.sql` - создает пустую таблицу `users` и `sessions`.

## Подключение к БД

* Реализовано через хелпер в `Seabattle.pm`:
    ```perl
    $self->helper(schema => sub {
        state $schema = Seabattle::Schema->connect(
            "dbi:MariaDB:database=$ENV{DB_NAME};host=$ENV{DB_HOST};port=$ENV{DB_PORT}",
            $ENV{DB_USER},
            $ENV{DB_PASSWORD},
            { RaiseError => 1, AutoCommit => 1 }
        );
    });
    ```

* Если поднимаете БД локально и с переменными окружения не запускается - укажите настройки прямо в коде. 

* В любом месте приложения `$c->schema`, например:
    ```perl
    $c->schema->resultset('User')->search({ email => $email })->first;
    ```

## Зависимости для Docker compose

* В `seabattle/cpanfile` укажите перловые зависимости.
* В `build/app/Dockerfile` добавьте необходимые системные зависимости. 
 

