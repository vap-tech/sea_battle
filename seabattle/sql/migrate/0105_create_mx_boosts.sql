-- Таблица бустов
CREATE TABLE mx_boosts (
    id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    price DECIMAL(10, 2) NOT NULL,
    type VARCHAR(30) NOT NULL,
    game_effect JSON NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Вставка тестовых данных
INSERT INTO mx_boosts (name, description, price, type, game_effect, is_active) VALUES
('Double Shoot', 'Позволяет выстрелить после промаха', 47, 'damage', '{"value": 25, "duration_min": 30}', TRUE),
('Restore Ship', 'Восстанавливает самый большой корабль', 410, 'defense', '{"value": 25, "duration_min": 30}', TRUE),
('Dragon Fury', 'Увеличивает урон на 25% на 30 минут', 49.99, 'damage', '{"value": 25, "duration_min": 30}', TRUE),
('Berserker Rage', '+40% к урону в ближнем бою', 79.99, 'damage', '{"value": 40, "duration_min": 15, "melee_only": true}', TRUE),
('Precision Shot', '+15% к урону от снайперских атак', 59.99, 'damage', '{"value": 15, "duration_min": 45, "weapon_type": "sniper"}', TRUE),
('Titan Shield', 'Уменьшает получаемый урон на 30%', 69.99, 'defense', '{"value": 30, "duration_min": 30}', TRUE),
('Phoenix Aura', 'Медленное восстановление здоровья', 89.99, 'defense', '{"hp_regen": 5, "duration_min": 60}', TRUE),
('Steel Skin', '+50 брони на 20 минут', 54.99, 'defense', '{"armor": 50, "duration_min": 20}', TRUE),
('Lightning Dash', '+35% к скорости передвижения', 44.99, 'speed', '{"value": 35, "duration_min": 25}', TRUE),
('Wind Walker', 'Бег не расходует выносливость', 64.99, 'speed', '{"no_stamina_cost": true, "duration_min": 40}', TRUE),
('Quantum Leap', 'Увеличивает прыжок в 2 раза', 74.99, 'speed', '{"jump_boost": 100, "duration_min": 15}', TRUE),
('Wisdom Potion', '+50% к получаемому опыту', 99.99, 'xp', '{"value": 50, "duration_min": 60}', TRUE),
('Mentor''s Blessing', 'Удваивает опыт за квесты', 119.99, 'xp', '{"quest_xp": 100, "duration_min": 120}', TRUE),
('Golden Touch', '+40% к получаемой валюте', 89.99, 'resource', '{"value": 40, "duration_min": 45}', TRUE),
('Lucky Miner', 'Шанс удвоения добычи руды', 109.99, 'resource', '{"double_chance": 30, "duration_min": 60}', TRUE),
('Invisibility Cloak', 'Делает невидимым на 2 минуты', 199.99, 'special', '{"ability": "invisibility", "duration_min": 2}', TRUE),
('Time Warp', 'Замедляет время вокруг на 15 сек', 249.99, 'special', '{"ability": "slow_time", "duration_sec": 15, "cooldown_min": 30}', TRUE),
('Halloween Terror', 'Спецэффекты и +10% ко всем характеристикам', 149.99, 'event', '{"damage": 10, "defense": 10, "speed": 10, "duration_min": 90, "event": "halloween"}', FALSE),
('New Year Miracle', 'Снежные эффекты и случайные бонусы', 129.99, 'event', '{"random_boost": true, "duration_min": 120, "event": "new_year"}', FALSE),
('Warrior''s Banner', '+20% к урону для всей группы', 179.99, 'team', '{"radius": 15, "damage_boost": 20, "duration_min": 30}', TRUE),
('Guardian Totem', 'Защищает союзников в радиусе 10м', 159.99, 'team', '{"radius": 10, "damage_reduction": 15, "duration_min": 45}', TRUE);

-- Создание таблицы аналитики популярности бустов
CREATE TABLE mx_boost_popularity (
    boost_id BIGINT UNSIGNED NOT NULL PRIMARY KEY,
    purchases_count INT NOT NULL DEFAULT 0,
    last_purchased_at TIMESTAMP NULL DEFAULT NULL,
    total_revenue DECIMAL(12, 2) DEFAULT 0.00,
    FOREIGN KEY (boost_id) REFERENCES mx_boosts(id) ON DELETE CASCADE
);

-- Наполнение таблицы аналитики реалистичными данными
INSERT INTO mx_boost_popularity (boost_id, purchases_count, last_purchased_at, total_revenue) VALUES
-- Топ-5 самых популярных бустов
(1, 254, '2023-11-15 14:32:18', 12697.46),  -- Dragon Fury
(4, 189, '2023-11-14 09:21:05', 13228.11),  -- Titan Shield
(7, 176, '2023-11-16 18:45:33', 7922.24),   -- Lightning Dash
(10, 143, '2023-11-13 22:15:47', 14285.57), -- Wisdom Potion
(13, 132, '2023-11-15 11:03:29', 11879.68), -- Golden Touch

-- Среднепопулярные бусты
(2, 98, '2023-11-12 16:54:22', 7839.02),    -- Berserker Rage
(5, 87, '2023-11-14 13:37:41', 7829.13),    -- Phoenix Aura
(8, 76, '2023-11-16 10:12:08', 4939.24),    -- Wind Walker
(11, 65, '2023-11-11 19:28:56', 7799.35),   -- Mentor's Blessing
(14, 54, '2023-11-10 15:45:19', 10799.46),  -- Invisibility Cloak

-- Нишевые бусты
(3, 43, '2023-11-09 12:23:17', 2579.57),    -- Precision Shot
(6, 37, '2023-11-08 20:34:28', 2034.63),    -- Steel Skin
(9, 29, '2023-11-07 17:56:39', 2174.71),    -- Quantum Leap
(12, 21, '2023-11-06 14:45:12', 2309.79),   -- Lucky Miner
(15, 18, '2023-11-05 11:23:45', 4499.82),   -- Time Warp

-- Сезонные и командные бусты
(16, 15, '2023-10-31 23:59:59', 2249.85),   -- Halloween Terror
(17, 12, '2023-01-01 00:10:15', 1559.88),   -- New Year Miracle
(18, 28, '2023-11-14 17:32:44', 5039.72),   -- Warrior's Banner
(19, 19, '2023-11-13 12:11:33', 3039.81);   -- Guardian Totem

-- Таблица промокодов
CREATE TABLE mx_promocodes (
    code VARCHAR(32) PRIMARY KEY,
    discount_percent INT NOT NULL,
    boost_id BIGINT UNSIGNED NULL,  -- Если промокод для конкретного буста
    expires_at TIMESTAMP NULL,
    max_uses INT DEFAULT 1,
    current_uses INT DEFAULT 0,
    FOREIGN KEY (boost_id) REFERENCES mx_boosts(id)
);

-- Таблица инвентаря игроков
CREATE TABLE mx_user_inventory (
    user_id BIGINT UNSIGNED NOT NULL,
    boost_id BIGINT UNSIGNED NOT NULL,
    quantity INT NOT NULL DEFAULT 1,
    purchased_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (boost_id) REFERENCES mx_boosts(id),
    PRIMARY KEY (user_id, boost_id)
);