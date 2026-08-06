CREATE TABLE IF NOT EXISTS native_users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  full_name TEXT NOT NULL,
  email TEXT NOT NULL COLLATE NOCASE UNIQUE,
  username TEXT NOT NULL COLLATE NOCASE UNIQUE,
  password_hash TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_login_at TEXT
);

CREATE TABLE IF NOT EXISTS native_sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL REFERENCES native_users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL UNIQUE,
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS native_categories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL REFERENCES native_users(id) ON DELETE CASCADE,
  name TEXT NOT NULL COLLATE NOCASE,
  color TEXT NOT NULL DEFAULT '#8b5cf6',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, name)
);

CREATE TABLE IF NOT EXISTS native_transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL REFERENCES native_users(id) ON DELETE CASCADE,
  category_id INTEGER REFERENCES native_categories(id) ON DELETE SET NULL,
  description TEXT NOT NULL,
  amount_cents INTEGER NOT NULL CHECK(amount_cents > 0),
  type TEXT NOT NULL CHECK(type IN ('income','expense')),
  occurred_on TEXT NOT NULL,
  notes TEXT NOT NULL DEFAULT '',
  source TEXT NOT NULL DEFAULT 'manual',
  expense_id INTEGER,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS native_expenses (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL REFERENCES native_users(id) ON DELETE CASCADE,
  category_id INTEGER REFERENCES native_categories(id) ON DELETE SET NULL,
  description TEXT NOT NULL,
  amount_cents INTEGER NOT NULL CHECK(amount_cents > 0),
  due_on TEXT NOT NULL,
  installment_count INTEGER NOT NULL DEFAULT 1 CHECK(installment_count > 0),
  installments_paid INTEGER NOT NULL DEFAULT 0 CHECK(installments_paid >= 0),
  notes TEXT NOT NULL DEFAULT '',
  paid_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_native_sessions_user ON native_sessions(user_id);
CREATE INDEX IF NOT EXISTS idx_native_categories_user ON native_categories(user_id);
CREATE INDEX IF NOT EXISTS idx_native_transactions_user_date ON native_transactions(user_id, occurred_on);
CREATE INDEX IF NOT EXISTS idx_native_expenses_user_due ON native_expenses(user_id, due_on);

