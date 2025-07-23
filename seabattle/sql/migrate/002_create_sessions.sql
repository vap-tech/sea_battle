CREATE TABLE sessions (
  session_id CHAR(64) PRIMARY KEY,
  user_id 	 INT NOT NULL,
  ip_address VARCHAR(45) NOT NULL,
  user_agent TEXT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  expires_at DATETIME NOT NULL,
  is_active  BOOLEAN DEFAULT TRUE,
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  INDEX idx_user_id (user_id),
  INDEX idx_expires (expires_at)
) 
ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
