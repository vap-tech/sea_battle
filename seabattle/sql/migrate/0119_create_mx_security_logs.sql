-- Лог секюрных штук
CREATE TABLE mx_security_logs (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    user_id BIGINT UNSIGNED NOT NULL,
    event_type ENUM(
        'password_change',
        'login_success',
        'login_failed',
        'email_change',
        '2fa_enabled',
        'account_lockout'
    ) NOT NULL,
    ip_address VARCHAR(45) NOT NULL,
    user_agent TEXT,
    device_fingerprint VARCHAR(64) COMMENT 'Хеш отпечатка устройства',
    country_code CHAR(2),
    additional_data JSON,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    PRIMARY KEY (id, created_at),
    INDEX idx_user_event (user_id, event_type),
    INDEX idx_created_ip (created_at, ip_address)
);