CREATE TABLE user_stats (
    user_id INT PRIMARY KEY,
    score INT UNSIGNED DEFAULT 0,
    coins INT UNSIGNED DEFAULT 0,
    score_achieved_at DATETIME,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
)
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
