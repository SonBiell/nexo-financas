CREATE TABLE IF NOT EXISTS categories (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  name TEXT NOT NULL COLLATE NOCASE,
  color TEXT NOT NULL DEFAULT '#14b8a6',
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, name)
);

CREATE TABLE IF NOT EXISTS transactions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  description TEXT NOT NULL,
  amount_cents INTEGER NOT NULL CHECK(amount_cents > 0),
  type TEXT NOT NULL CHECK(type IN ('income','expense')),
  category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
  occurred_on TEXT NOT NULL,
  notes TEXT NOT NULL DEFAULT '',
  due_on TEXT,
  installment_count INTEGER NOT NULL DEFAULT 1 CHECK(installment_count > 0),
  installments_paid INTEGER NOT NULL DEFAULT 0 CHECK(installments_paid >= 0),
  paid_at TEXT,
  recurring_monthly INTEGER NOT NULL DEFAULT 0,
  recurrence_key TEXT,
  recurrence_day INTEGER,
  source TEXT NOT NULL DEFAULT 'manual',
  expense_id INTEGER,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS expenses (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  description TEXT NOT NULL,
  amount_cents INTEGER NOT NULL CHECK(amount_cents > 0),
  category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
  due_on TEXT NOT NULL,
  installment_count INTEGER NOT NULL DEFAULT 1 CHECK(installment_count > 0),
  installments_paid INTEGER NOT NULL DEFAULT 0 CHECK(installments_paid >= 0),
  notes TEXT NOT NULL DEFAULT '',
  paid_at TEXT,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS app_metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL);

CREATE TABLE IF NOT EXISTS api_sessions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token_hash TEXT NOT NULL UNIQUE,
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  full_name TEXT NOT NULL,
  document TEXT NOT NULL,
  birth_date TEXT NOT NULL,
  email TEXT NOT NULL COLLATE NOCASE UNIQUE,
  username TEXT NOT NULL COLLATE NOCASE UNIQUE,
  password_hash TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  last_login_at TEXT
);

CREATE INDEX IF NOT EXISTS idx_transactions_date ON transactions(occurred_on);
CREATE INDEX IF NOT EXISTS idx_transactions_type ON transactions(type);
CREATE INDEX IF NOT EXISTS idx_transactions_category ON transactions(category_id);
CREATE INDEX IF NOT EXISTS idx_expenses_due ON expenses(due_on);
CREATE INDEX IF NOT EXISTS idx_api_sessions_user ON api_sessions(user_id);
