#shop_items(id, name, price)

CREATE TABLE shop_items (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(255) UNIQUE NOT NULL,
    price INT UNSIGNED NOT NULL,
    UNIQUE KEY (name)
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

INSERT INTO shop_items (name, price) VALUES
('Дополнительный выстрел', 50),
('Восстановить корабль', 100);