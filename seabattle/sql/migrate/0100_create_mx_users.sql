-- Базовый пользователь
CREATE TABLE mx_users (
    id SERIAL PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    created_at timestamp NOT NULL DEFAULT current_timestamp()
);

-- Таблица профилей пользователей
CREATE TABLE `mx_user_profiles` (
    id SERIAL PRIMARY KEY,
    user_id int(11) NOT NULL,
    user_name varchar(100) DEFAULT NULL,
    org_name varchar(100) DEFAULT NULL,
    department varchar(100) DEFAULT NULL,
    position varchar(100) DEFAULT NULL,
    updated_at timestamp NOT NULL DEFAULT current_timestamp() ON UPDATE current_timestamp()
);

-- Активные устройства
CREATE TABLE mx_user_auths (
    id SERIAL PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
    refresh_token TEXT,
    refresh_token_date_start TIMESTAMP NOT NULL,
    FOREIGN KEY (user_id) REFERENCES mx_users(id)
);

-- Самая секретная таблица
CREATE TABLE mx_user_logins (
    id SERIAL PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    password TEXT NOT NULL,
    token TEXT,
    token_expires_at TIMESTAMP,
    is_verified BOOLEAN DEFAULT FALSE,
    user_id BIGINT UNSIGNED NOT NULL,
    FOREIGN KEY (user_id) REFERENCES mx_users(id)
);

CREATE TABLE mx_user_rank (
    id SERIAL PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL,
    score INT DEFAULT 0,
    rank ENUM('New', 'Sailor', 'Lieutenant', 'Captain', 'Admiral', 'God', 'Vip') NOT NULL DEFAULT 'New',
    FOREIGN KEY (user_id) REFERENCES mx_users(id)
);

CREATE TABLE mx_user_amount (
    id SERIAL PRIMARY KEY,
    user_id BIGINT UNSIGNED NOT NULL UNIQUE,
    amount FLOAT DEFAULT 0,
    total_paid FLOAT DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES mx_users(id)
)


