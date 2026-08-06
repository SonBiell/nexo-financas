from __future__ import annotations

import json
import hashlib
import calendar
import os
import re
import secrets
import sqlite3
from datetime import date, datetime, timedelta
from decimal import Decimal, InvalidOperation
from pathlib import Path

from flask import Flask, abort, flash, jsonify, redirect, render_template, request, session, url_for
from werkzeug.security import check_password_hash, generate_password_hash
from werkzeug.middleware.proxy_fix import ProxyFix


BASE_DIR = Path(__file__).resolve().parent


class ClosingConnection(sqlite3.Connection):
    """Commit or roll back, then always release the local database file."""

    def __exit__(self, exc_type, exc_value, traceback):
        try:
            return super().__exit__(exc_type, exc_value, traceback)
        finally:
            self.close()


def create_app(test_config: dict | None = None) -> Flask:
    app = Flask(__name__)
    production = os.environ.get("FINANCE_ENV") == "production"
    secret_key = os.environ.get("FINANCE_SECRET")
    if production and not secret_key:
        raise RuntimeError("FINANCE_SECRET é obrigatória em produção")
    app.config.from_mapping(
        SECRET_KEY=secret_key or "local-development-key",
        DATABASE=os.environ.get("DATABASE_PATH", str(BASE_DIR / "instance" / "financas.db")),
        SESSION_COOKIE_HTTPONLY=True,
        SESSION_COOKIE_SAMESITE="Lax",
        SESSION_COOKIE_SECURE=production or os.environ.get("FINANCE_HTTPS", "0") == "1",
        PERMANENT_SESSION_LIFETIME=timedelta(days=30),
    )
    if test_config:
        app.config.update(test_config)
    if production:
        app.wsgi_app = ProxyFix(app.wsgi_app, x_for=1, x_proto=1, x_host=1)

    Path(app.config["DATABASE"]).parent.mkdir(parents=True, exist_ok=True)

    def db() -> sqlite3.Connection:
        connection = sqlite3.connect(app.config["DATABASE"], factory=ClosingConnection)
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA foreign_keys = ON")
        return connection

    def init_db() -> None:
        with db() as connection:
            connection.executescript((BASE_DIR / "schema.sql").read_text(encoding="utf-8"))
            connection.executescript((BASE_DIR / "native_schema.sql").read_text(encoding="utf-8"))
            existing = {row["name"] for row in connection.execute("PRAGMA table_info(transactions)")}
            migrations = {
                "due_on": "ALTER TABLE transactions ADD COLUMN due_on TEXT",
                "installment_count": "ALTER TABLE transactions ADD COLUMN installment_count INTEGER NOT NULL DEFAULT 1",
                "installments_paid": "ALTER TABLE transactions ADD COLUMN installments_paid INTEGER NOT NULL DEFAULT 0",
                "paid_at": "ALTER TABLE transactions ADD COLUMN paid_at TEXT",
                "source": "ALTER TABLE transactions ADD COLUMN source TEXT NOT NULL DEFAULT 'manual'",
                "expense_id": "ALTER TABLE transactions ADD COLUMN expense_id INTEGER",
            }
            for column, statement in migrations.items():
                if column not in existing:
                    connection.execute(statement)
            user_columns = {row["name"] for row in connection.execute("PRAGMA table_info(users)")}
            user_migrations = {
                "full_name": "ALTER TABLE users ADD COLUMN full_name TEXT NOT NULL DEFAULT ''",
                "document": "ALTER TABLE users ADD COLUMN document TEXT NOT NULL DEFAULT ''",
                "birth_date": "ALTER TABLE users ADD COLUMN birth_date TEXT NOT NULL DEFAULT ''",
                "email": "ALTER TABLE users ADD COLUMN email TEXT NOT NULL DEFAULT ''",
            }
            for column, statement in user_migrations.items():
                if column not in user_columns:
                    connection.execute(statement)
            owner = connection.execute("SELECT id FROM users ORDER BY id LIMIT 1").fetchone()
            for table in ("categories", "transactions", "expenses"):
                columns = {row["name"] for row in connection.execute(f"PRAGMA table_info({table})")}
                if "user_id" not in columns:
                    connection.execute(f"ALTER TABLE {table} ADD COLUMN user_id INTEGER REFERENCES users(id) ON DELETE CASCADE")
                if owner:
                    connection.execute(f"UPDATE {table} SET user_id=? WHERE user_id IS NULL", (owner["id"],))
            categories_sql = connection.execute(
                "SELECT sql FROM sqlite_master WHERE type='table' AND name='categories'"
            ).fetchone()["sql"]
            if "UNIQUE(user_id, name)" not in categories_sql.replace("\n", " "):
                connection.commit()
                connection.execute("PRAGMA foreign_keys=OFF")
                connection.execute("""CREATE TABLE categories_v2 (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
                    name TEXT NOT NULL COLLATE NOCASE,
                    color TEXT NOT NULL DEFAULT '#8b5cf6',
                    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    UNIQUE(user_id, name))""")
                connection.execute("""INSERT INTO categories_v2(id,user_id,name,color,created_at)
                                      SELECT id,user_id,name,color,created_at FROM categories WHERE user_id IS NOT NULL""")
                connection.execute("DROP TABLE categories")
                connection.execute("ALTER TABLE categories_v2 RENAME TO categories")
                connection.commit()
                connection.execute("PRAGMA foreign_keys=ON")
            expense_columns = {row["name"] for row in connection.execute("PRAGMA table_info(expenses)")}
            expense_migrations = {
                "recurring_monthly": "ALTER TABLE expenses ADD COLUMN recurring_monthly INTEGER NOT NULL DEFAULT 0",
                "recurrence_key": "ALTER TABLE expenses ADD COLUMN recurrence_key TEXT",
                "recurrence_day": "ALTER TABLE expenses ADD COLUMN recurrence_day INTEGER",
            }
            for column, statement in expense_migrations.items():
                if column not in expense_columns:
                    connection.execute(statement)
            connection.execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_expenses_recurrence_due ON expenses(recurrence_key, due_on) WHERE recurrence_key IS NOT NULL")
            migrated = connection.execute("SELECT value FROM app_metadata WHERE key='expenses_split_v1'").fetchone()
            if not migrated:
                connection.execute(
                    """INSERT INTO expenses(user_id, description, amount_cents, category_id, due_on, installment_count, installments_paid, notes, paid_at, created_at)
                       SELECT user_id, description, amount_cents, category_id, COALESCE(due_on,occurred_on), installment_count,
                              installments_paid, notes, paid_at, created_at FROM transactions WHERE type='expense'"""
                )
                connection.execute("DELETE FROM transactions WHERE type='expense'")
                connection.execute("INSERT INTO app_metadata(key,value) VALUES('expenses_split_v1','done')")
            connection.execute("CREATE INDEX IF NOT EXISTS idx_categories_user ON categories(user_id)")
            connection.execute("CREATE INDEX IF NOT EXISTS idx_transactions_user ON transactions(user_id)")
            connection.execute("CREATE INDEX IF NOT EXISTS idx_expenses_user ON expenses(user_id)")
            for user in connection.execute("SELECT id FROM users").fetchall():
                connection.executemany(
                    "INSERT OR IGNORE INTO categories (user_id, name, color) VALUES (?, ?, ?)",
                    [(user["id"], "Moradia", "#8b5cf6"), (user["id"], "Alimentação", "#22c55e"), (user["id"], "Transporte", "#38bdf8"), (user["id"], "Salário", "#f59e0b")],
                )
            for damaged_name, correct_name in (("AlimentaÃ§Ã£o", "Alimentação"), ("SalÃ¡rio", "Salário")):
                damaged = connection.execute("SELECT id,user_id FROM categories WHERE name=?", (damaged_name,)).fetchone()
                correct = connection.execute("SELECT id FROM categories WHERE name=? AND user_id=?", (correct_name, damaged["user_id"] if damaged else -1)).fetchone()
                if damaged and correct:
                    connection.execute("UPDATE transactions SET category_id=? WHERE category_id=?", (correct["id"], damaged["id"]))
                    connection.execute("UPDATE expenses SET category_id=? WHERE category_id=?", (correct["id"], damaged["id"]))
                    connection.execute("DELETE FROM categories WHERE id=?", (damaged["id"],))
                elif damaged:
                    connection.execute("UPDATE categories SET name=? WHERE id=?", (correct_name, damaged["id"]))

    init_db()

    if app.config.get("TESTING"):
        with db() as connection:
            if not connection.execute("SELECT 1 FROM users LIMIT 1").fetchone():
                connection.execute("""INSERT INTO users(full_name,document,birth_date,email,username,password_hash)
                                      VALUES('Usuário de Teste','00000000000','1990-01-01','test@nexo.local','test',?)""",
                                   (generate_password_hash("test-password"),))
                test_user_id = connection.execute("SELECT id FROM users WHERE username='test'").fetchone()["id"]
                connection.executemany("INSERT INTO categories(user_id,name,color) VALUES(?,?,?)", [
                    (test_user_id, "Moradia", "#8b5cf6"), (test_user_id, "Alimentação", "#22c55e"),
                    (test_user_id, "Transporte", "#38bdf8"), (test_user_id, "Salário", "#f59e0b")])

    def active_user_id() -> int:
        if "user_id" in session:
            return int(session["user_id"])
        if app.config.get("TESTING"):
            with db() as connection:
                return int(connection.execute("SELECT id FROM users ORDER BY id LIMIT 1").fetchone()["id"])
        abort(401)

    def following_month(due_on: str, preferred_day: int) -> str:
        current = datetime.strptime(due_on, "%Y-%m-%d").date()
        year, month = (current.year + 1, 1) if current.month == 12 else (current.year, current.month + 1)
        day = min(preferred_day, calendar.monthrange(year, month)[1])
        return date(year, month, day).isoformat()

    def ensure_recurring_expenses(user_id: int) -> None:
        with db() as connection:
            series = connection.execute(
                """SELECT e.* FROM expenses e JOIN (
                     SELECT recurrence_key, MAX(due_on) latest_due FROM expenses
                     WHERE recurring_monthly=1 AND recurrence_key IS NOT NULL AND user_id=? GROUP BY recurrence_key
                   ) latest ON latest.recurrence_key=e.recurrence_key AND latest.latest_due=e.due_on
                   WHERE e.user_id=?"""
                , (user_id, user_id)).fetchall()
            for item in series:
                latest_due = item["due_on"]
                preferred_day = item["recurrence_day"] or int(latest_due[-2:])
                while latest_due <= date.today().isoformat():
                    latest_due = following_month(latest_due, preferred_day)
                    connection.execute(
                        """INSERT OR IGNORE INTO expenses(
                             user_id,description,amount_cents,category_id,due_on,installment_count,notes,
                             recurring_monthly,recurrence_key,recurrence_day
                           ) VALUES(?,?,?,?,?,1,?,1,?,?)""",
                        (user_id, item["description"], item["amount_cents"], item["category_id"], latest_due, item["notes"], item["recurrence_key"], preferred_day),
                    )

    def csrf_token() -> str:
        if "csrf_token" not in session:
            session["csrf_token"] = secrets.token_urlsafe(32)
        return session["csrf_token"]

    @app.before_request
    def protect_application():
        if request.path.startswith("/api/v2/"):
            return None
        if app.config.get("TESTING"):
            return None
        endpoint = request.endpoint or ""
        public_endpoints = {"login", "setup", "static", "health"}
        if request.method == "POST":
            received = request.form.get("csrf_token") or request.headers.get("X-CSRF-Token")
            if not received or not secrets.compare_digest(received, session.get("csrf_token", "")):
                abort(400, "Formulário expirado. Atualize a página e tente novamente.")
        if endpoint not in public_endpoints and "user_id" not in session:
            return redirect(url_for("login", next=request.path))
        return None

    @app.after_request
    def security_headers(response):
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
        response.headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()"
        response.headers["Content-Security-Policy"] = "default-src 'self'; style-src 'self' https://fonts.googleapis.com 'unsafe-inline'; font-src https://fonts.gstatic.com; script-src 'self' 'unsafe-inline'; img-src 'self' data:; form-action 'self'; frame-ancestors 'none'"
        if production:
            response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
        return response

    @app.get("/health")
    def health():
        try:
            with db() as connection:
                connection.execute("SELECT 1").fetchone()
            return jsonify({"status": "ok"})
        except sqlite3.Error:
            return jsonify({"status": "unavailable"}), 503

    def issue_native_token(connection: sqlite3.Connection, user_id: int) -> str:
        token = secrets.token_urlsafe(48)
        token_hash = hashlib.sha256(token.encode()).hexdigest()
        expires_at = (datetime.now() + timedelta(days=30)).isoformat(timespec="seconds")
        connection.execute(
            "INSERT INTO native_sessions(user_id,token_hash,expires_at) VALUES(?,?,?)",
            (user_id, token_hash, expires_at),
        )
        return token

    def native_user_from_request(connection: sqlite3.Connection):
        authorization = request.headers.get("Authorization", "")
        if not authorization.startswith("Bearer "):
            return None
        token_hash = hashlib.sha256(authorization[7:].strip().encode()).hexdigest()
        return connection.execute(
            """SELECT u.* FROM native_users u JOIN native_sessions s ON s.user_id=u.id
               WHERE s.token_hash=? AND s.expires_at>?""",
            (token_hash, datetime.now().isoformat(timespec="seconds")),
        ).fetchone()

    @app.post("/api/v2/auth/register")
    def native_register():
        payload = request.get_json(silent=True) or {}
        full_name = " ".join(str(payload.get("full_name", "")).split())
        email = str(payload.get("email", "")).strip().lower()
        username = str(payload.get("username", "")).strip()
        password = str(payload.get("password", ""))
        if len(full_name) < 5 or not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", email):
            return jsonify({"error": "Informe nome completo e e-mail válido."}), 400
        if len(username) < 3 or len(password) < 8:
            return jsonify({"error": "Usuário deve ter 3 caracteres e a senha pelo menos 8."}), 400
        try:
            with db() as connection:
                cursor = connection.execute(
                    "INSERT INTO native_users(full_name,email,username,password_hash) VALUES(?,?,?,?)",
                    (full_name, email, username, generate_password_hash(password)),
                )
                user_id = cursor.lastrowid
                connection.executemany(
                    "INSERT INTO native_categories(user_id,name,color) VALUES(?,?,?)",
                    [(user_id, "Moradia", "#8b5cf6"), (user_id, "Alimentação", "#22c55e"), (user_id, "Transporte", "#38bdf8"), (user_id, "Salário", "#f59e0b")],
                )
                token = issue_native_token(connection, user_id)
            return jsonify({"token": token, "user": {"id": user_id, "full_name": full_name, "email": email, "username": username}}), 201
        except sqlite3.IntegrityError:
            return jsonify({"error": "E-mail ou usuário já cadastrado."}), 409

    @app.post("/api/v2/auth/login")
    def native_login():
        payload = request.get_json(silent=True) or {}
        identity = str(payload.get("identity", "")).strip()
        password = str(payload.get("password", ""))
        with db() as connection:
            user = connection.execute(
                "SELECT * FROM native_users WHERE email=? OR username=?", (identity.lower(), identity)
            ).fetchone()
            if not user or not check_password_hash(user["password_hash"], password):
                return jsonify({"error": "Usuário ou senha inválidos."}), 401
            connection.execute("UPDATE native_users SET last_login_at=? WHERE id=?", (datetime.now().isoformat(timespec="seconds"), user["id"]))
            token = issue_native_token(connection, user["id"])
        return jsonify({"token": token, "user": {"id": user["id"], "full_name": user["full_name"], "email": user["email"], "username": user["username"]}})

    @app.get("/api/v2/auth/me")
    def native_me():
        with db() as connection:
            user = native_user_from_request(connection)
        if not user:
            return jsonify({"error": "Sessão inválida ou expirada."}), 401
        return jsonify({"user": {"id": user["id"], "full_name": user["full_name"], "email": user["email"], "username": user["username"]}})

    @app.post("/api/v2/auth/logout")
    def native_logout():
        authorization = request.headers.get("Authorization", "")
        if authorization.startswith("Bearer "):
            token_hash = hashlib.sha256(authorization[7:].strip().encode()).hexdigest()
            with db() as connection:
                connection.execute("DELETE FROM native_sessions WHERE token_hash=?", (token_hash,))
        return "", 204

    @app.context_processor
    def inject_security():
        return {"csrf_token": csrf_token, "logged_in": "user_id" in session, "current_username": session.get("username"), "current_full_name": session.get("full_name", session.get("username"))}

    @app.route("/register", methods=["GET", "POST"])
    @app.route("/setup", methods=["GET", "POST"])
    def setup():
        if request.method == "POST":
            full_name = " ".join(request.form.get("full_name", "").split())
            document = re.sub(r"[^0-9A-Za-z]", "", request.form.get("document", "")).upper()
            birth_date = request.form.get("birth_date", "")
            email = request.form.get("email", "").strip().lower()
            username = request.form.get("username", "").strip()
            password = request.form.get("password", "")
            confirmation = request.form.get("password_confirmation", "")
            try:
                born = datetime.strptime(birth_date, "%Y-%m-%d").date()
                valid_birth_date = born < date.today()
            except ValueError:
                valid_birth_date = False
            if len(full_name) < 5:
                flash("Informe seu nome completo.", "error")
            elif len(document) < 7 or len(document) > 14:
                flash("Informe um RG ou CPF válido.", "error")
            elif not valid_birth_date:
                flash("Informe uma data de nascimento válida.", "error")
            elif not re.fullmatch(r"[^@\s]+@[^@\s]+\.[^@\s]+", email):
                flash("Informe um endereço de e-mail válido.", "error")
            elif len(username) < 3:
                flash("O usuário d…582 tokens truncated…d"], session["username"], session["full_name"] = user["id"], user["username"], user["full_name"] or user["username"]
                    session.permanent = request.form.get("remember") == "1"
                    destination = request.args.get("next", "")
                    return redirect(destination if destination.startswith("/") and not destination.startswith("//") else url_for("dashboard"))
            flash("Usuário ou senha inválidos.", "error")
        return render_template("login.html")

    @app.post("/logout")
    def logout():
        session.clear()
        flash("Sessão encerrada com segurança.", "success")
        return redirect(url_for("login"))

    @app.template_filter("money")
    def money(value: int | None) -> str:
        amount = (value or 0) / 100
        return f"R$ {amount:,.2f}".replace(",", "_").replace(".", ",").replace("_", ".")

    @app.context_processor
    def inject_year():
        return {"current_year": date.today().year}

    @app.get("/dashboard")
    def dashboard():
        user_id = active_user_id()
        ensure_recurring_expenses(user_id)
        month = request.args.get("month", date.today().strftime("%Y-%m"))
        try:
            datetime.strptime(month, "%Y-%m")
        except ValueError:
            month = date.today().strftime("%Y-%m")
        today = date.today()
        due_soon_limit = today + timedelta(days=7)
        with db() as connection:
            totals = connection.execute(
                """SELECT COALESCE(SUM(CASE WHEN type='income' THEN amount_cents END),0) income,
                          COALESCE(SUM(CASE WHEN type='expense' THEN amount_cents END),0) expense
                   FROM transactions WHERE substr(occurred_on,1,7)=? AND user_id=?""", (month, user_id)
            ).fetchone()
            recent = connection.execute(
                """SELECT t.*, c.name category_name, c.color FROM transactions t
                   LEFT JOIN categories c ON c.id=t.category_id
                   WHERE substr(t.occurred_on,1,7)=? AND t.user_id=? ORDER BY t.occurred_on DESC, t.id DESC LIMIT 8""", (month, user_id)
            ).fetchall()
            breakdown = connection.execute(
                """SELECT COALESCE(c.name,'Sem categoria') name, COALESCE(c.color,'#64748b') color,
                          SUM(t.amount_cents) total
                   FROM transactions t LEFT JOIN categories c ON c.id=t.category_id
                   WHERE t.type='expense' AND substr(t.occurred_on,1,7)=? AND t.user_id=?
                   GROUP BY c.id ORDER BY total DESC""", (month, user_id)
            ).fetchall()
            wallet = connection.execute(
                "SELECT COALESCE(SUM(CASE WHEN type='income' THEN amount_cents ELSE -amount_cents END),0) balance FROM transactions WHERE user_id=?",
                (user_id,)
            ).fetchone()["balance"]
            expense_overview = connection.execute(
                """SELECT
                     COUNT(CASE WHEN paid_at IS NULL THEN 1 END) open_count,
                     COALESCE(SUM(CASE WHEN paid_at IS NULL THEN amount_cents ELSE 0 END),0) open_total,
                     COUNT(CASE WHEN paid_at IS NULL AND due_on < ? THEN 1 END) overdue_count,
                     COALESCE(SUM(CASE WHEN paid_at IS NULL AND due_on < ? THEN amount_cents ELSE 0 END),0) overdue_total,
                     COUNT(CASE WHEN paid_at IS NULL AND due_on BETWEEN ? AND ? THEN 1 END) due_soon_count
                   FROM expenses WHERE user_id=?""", (today.isoformat(), today.isoformat(), today.isoformat(), due_soon_limit.isoformat(), user_id)
            ).fetchone()
            urgent_expenses = connection.execute(
                """SELECT e.*, c.name category_name, c.color FROM expenses e
                   LEFT JOIN categories c ON c.id=e.category_id
                   WHERE e.paid_at IS NULL AND e.due_on <= ? AND e.user_id=?
                   ORDER BY CASE WHEN e.due_on < ? THEN 0 ELSE 1 END, e.due_on, e.id LIMIT 6""",
                (due_soon_limit.isoformat(), user_id, today.isoformat()),
            ).fetchall()
        return render_template("dashboard.html", month=month, totals=totals, recent=recent, breakdown=breakdown, wallet=wallet, expense_overview=expense_overview, urgent_expenses=urgent_expenses, today=today.isoformat())

    @app.route("/transactions", methods=["GET", "POST"])
    def transactions():
        user_id = active_user_id()
        if request.method == "POST":
            try:
                kind = request.form["type"]
                if kind not in {"income", "expense"}:
                    raise ValueError("Tipo inválido")
                amount = Decimal(request.form["amount"].replace(",", "."))
                if amount <= 0:
                    raise ValueError("O valor deve ser positivo")
                amount_cents = int(amount * 100)
                description = request.form["description"].strip()
                if not description:
                    raise ValueError("Informe uma descrição")
                occurred_on = datetime.strptime(request.form["occurred_on"], "%Y-%m-%d").date().isoformat()
                category_id = request.form.get("category_id") or None
                with db() as connection:
                    if category_id and not connection.execute("SELECT 1 FROM categories WHERE id=? AND user_id=?", (category_id, user_id)).fetchone():
                        category_id = None
                    connection.execute(
                        "INSERT INTO transactions(user_id, description, amount_cents, type, category_id, occurred_on, notes, source) VALUES(?,?,?,?,?,?,?, 'manual')",
                        (user_id, description, amount_cents, kind, category_id, occurred_on, request.form.get("notes", "").strip()),
                    )
                flash("Transação salva com sucesso.", "success")
                return redirect(url_for("transactions"))
            except (ValueError, InvalidOperation, KeyError) as exc:
                flash(str(exc) or "Confira os dados informados.", "error")

        kind_filter, period = request.args.get("type", "all"), request.args.get("period", "month")
        reference = date.today()
        conditions, params = ["t.user_id=?"], [user_id]
        if kind_filter in {"income", "expense"}:
            conditions.append("t.type=?"); params.append(kind_filter)
        if period == "day":
            conditions.append("t.occurred_on=?"); params.append(reference.isoformat())
        elif period == "week":
            start = reference - timedelta(days=reference.weekday())
            conditions.append("t.occurred_on BETWEEN ? AND ?"); params.extend([start.isoformat(), (start + timedelta(days=6)).isoformat()])
        elif period == "month":
            conditions.append("substr(t.occurred_on,1,7)=?"); params.append(reference.strftime("%Y-%m"))
        sql_filter = "WHERE " + " AND ".join(conditions) if conditions else ""
        with db() as connection:
            rows = connection.execute(
                f"""SELECT t.*, c.name category_name, c.color FROM transactions t
                    LEFT JOIN categories c ON c.id=t.category_id {sql_filter}
                    ORDER BY t.occurred_on DESC, t.id DESC""", tuple(params)
            ).fetchall()
            categories = connection.execute("SELECT * FROM categories WHERE user_id=? ORDER BY name", (user_id,)).fetchall()
        return render_template("transactions.html", transactions=rows, categories=categories, today=date.today().isoformat(), kind_filter=kind_filter, period=period)

    @app.route("/expenses", methods=["GET", "POST"])
    def expenses():
        user_id = active_user_id()
        if request.method == "POST":
            try:
                installment_amount = Decimal(request.form["amount"].replace(",", "."))
                installments = int(request.form.get("installment_count", 1))
                description = request.form["description"].strip()
                due_on = datetime.strptime(request.form["due_on"], "%Y-%m-%d").date().isoformat()
                recurring_monthly = request.form.get("recurring_monthly") == "1"
                if recurring_monthly:
                    installments = 1
                if not description or installment_amount <= 0 or not 1 <= installments <= 360:
                    raise ValueError("Confira a descrição, o valor e as parcelas.")
                total_cents = int(installment_amount * 100) * installments
                with db() as connection:
                    category_id = request.form.get("category_id") or None
                    if category_id and not connection.execute("SELECT 1 FROM categories WHERE id=? AND user_id=?", (category_id, user_id)).fetchone():
                        category_id = None
                    connection.execute("""INSERT INTO expenses(
                                          user_id,description,amount_cents,category_id,due_on,installment_count,notes,
                                          recurring_monthly,recurrence_key,recurrence_day)
                                          VALUES(?,?,?,?,?,?,?,?,?,?)""", (
                                          user_id, description, total_cents, category_id,
                                          due_on, installments, request.form.get("notes", "").strip(),
                                          int(recurring_monthly), secrets.token_urlsafe(16) if recurring_monthly else None,
                                          int(due_on[-2:]) if recurring_monthly else None))
                flash("Despesa cadastrada sem alterar o saldo.", "success")
                return redirect(url_for("expenses"))
            except (ValueError, InvalidOperation, KeyError) as exc:
                flash(str(exc) or "Confira os dados.", "error")
        ensure_recurring_expenses(user_id)
        status_filter = request.args.get("status", "all")
        with db() as connection:
            rows = connection.execute(
                """SELECT e.*, c.name category_name, c.color FROM expenses e
                   LEFT JOIN categories c ON c.id=e.category_id WHERE e.user_id=? ORDER BY e.due_on, e.id DESC""",
                (user_id,)
            ).fetchall()
            categories = connection.execute("SELECT * FROM categories WHERE user_id=? ORDER BY name", (user_id,)).fetchall()
        today = date.today().isoformat()
        items, counts = [], {"paid": 0, "pending": 0, "overdue": 0}
        for row in rows:
            item = dict(row)
            item["display_status"] = "paid" if item["paid_at"] else ("overdue" if item["due_on"] < today else "pending")
            counts[item["display_status"]] += 1
            if status_filter == "all" or item["display_status"] == status_filter:
                items.append(item)
        return render_template("expenses.html", expenses=items, status_filter=status_filter, counts=counts, categories=categories, today=today)

    @app.post("/expenses/<int:transaction_id>/pay")
    def pay_expense(transaction_id: int):
        user_id = active_user_id()
        with db() as connection:
            expense = connection.execute("SELECT * FROM expenses WHERE id=? AND user_id=?", (transaction_id, user_id)).fetchone()
            balance = connection.execute("SELECT COALESCE(SUM(CASE WHEN type='income' THEN amount_cents ELSE -amount_cents END),0) FROM transactions WHERE user_id=?", (user_id,)).fetchone()[0]
            if not expense or expense["paid_at"]:
                flash("Essa despesa não está disponível para pagamento.", "error")
                return redirect(url_for("expenses"))
            installment_amount = round(expense["amount_cents"] / expense["installment_count"])
            if balance < installment_amount:
                flash(f"Saldo insuficiente. Faltam {money(installment_amount - balance)}.", "error")
                return redirect(url_for("expenses"))
            now = datetime.now()
            next_installment = expense["installments_paid"] + 1
            paid_at = now.isoformat(timespec="seconds") if next_installment >= expense["installment_count"] else None
            connection.execute("UPDATE expenses SET paid_at=?, installments_paid=? WHERE id=? AND user_id=?", (paid_at, next_installment, transaction_id, user_id))
            connection.execute("""INSERT INTO transactions(user_id,description,amount_cents,type,category_id,occurred_on,notes,source,expense_id)
                                  VALUES(?,?,?,'expense',?,?,?,'expense_payment',?)""", (user_id, f"Pagamento: {expense['description']} (parcela {next_installment}/{expense['installment_count']})", installment_amount, expense["category_id"], now.date().isoformat(), "Pagamento de parcela", transaction_id))
        flash("Parcela paga com sucesso.", "success")
        return redirect(url_for("expenses"))

    @app.post("/expenses/<int:transaction_id>/restore")
    def restore_expense(transaction_id: int):
        user_id = active_user_id()
        with db() as connection:
            expense = connection.execute("SELECT * FROM expenses WHERE id=? AND user_id=?", (transaction_id, user_id)).fetchone()
            if not expense or expense["installments_paid"] <= 0:
                flash("A despesa ainda não foi paga.", "error")
                return redirect(url_for("expenses"))
            now = datetime.now()
            restored_installment = expense["installments_paid"]
            installment_amount = round(expense["amount_cents"] / expense["installment_count"])
            connection.execute("UPDATE expenses SET paid_at=NULL, installments_paid=? WHERE id=? AND user_id=?", (restored_installment - 1, transaction_id, user_id))
            connection.execute("""INSERT INTO transactions(user_id,description,amount_cents,type,category_id,occurred_on,notes,source,expense_id)
                                  VALUES(?,?,?,'income',?,?,?,'expense_restore',?)""", (user_id, f"Estorno: {expense['description']} (parcela {restored_installment}/{expense['installment_count']})", installment_amount, expense["category_id"], now.date().isoformat(), "Restauração de parcela", transaction_id))
        flash("Parcela restaurada com sucesso.", "success")
        return redirect(url_for("expenses"))

    @app.post("/expenses/<int:transaction_id>/delete")
    def delete_expense(transaction_id: int):
        user_id = active_user_id()
        with db() as connection:
            expense = connection.execute("SELECT recurrence_key FROM expenses WHERE id=? AND user_id=?", (transaction_id, user_id)).fetchone()
            if expense and expense["recurrence_key"]:
                connection.execute("DELETE FROM expenses WHERE recurrence_key=? AND user_id=?", (expense["recurrence_key"], user_id))
                flash("Despesa e repetição mensal excluídas.", "success")
            else:
                connection.execute("DELETE FROM expenses WHERE id=? AND user_id=?", (transaction_id, user_id))
                flash("Despesa excluída.", "success")
        return redirect(url_for("expenses"))

    @app.post("/transactions/<int:transaction_id>/delete")
    def delete_transaction(transaction_id: int):
        user_id = active_user_id()
        with db() as connection:
            connection.execute("DELETE FROM transactions WHERE id=? AND user_id=?", (transaction_id, user_id))
        flash("Transação excluída.", "success")
        return redirect(url_for("transactions"))

    @app.route("/categories", methods=["GET", "POST"])
    def categories():
        user_id = active_user_id()
        if request.method == "POST":
            name = request.form.get("name", "").strip()
            color = request.form.get("color", "#8b5cf6")
            if not name:
                flash("Informe o nome da categoria.", "error")
            else:
                try:
                    with db() as connection:
                        connection.execute("INSERT INTO categories(user_id,name,color) VALUES(?,?,?)", (user_id, name, color))
                    flash("Categoria criada.", "success")
                    return redirect(url_for("categories"))
                except sqlite3.IntegrityError:
                    flash("Essa categoria já existe.", "error")
        with db() as connection:
            rows = connection.execute(
                """SELECT c.*, COUNT(DISTINCT t.id) transaction_count,
                          COUNT(DISTINCT e.id) expense_count
                   FROM categories c
                   LEFT JOIN transactions t ON t.category_id=c.id AND t.user_id=c.user_id
                   LEFT JOIN expenses e ON e.category_id=c.id AND e.user_id=c.user_id
                   WHERE c.user_id=? GROUP BY c.id ORDER BY c.name""",
                (user_id,)
            ).fetchall()
        return render_template("categories.html", categories=rows)

    @app.post("/categories/<int:category_id>/edit")
    def edit_category(category_id: int):
        user_id = active_user_id()
        name = request.form.get("name", "").strip()
        color = request.form.get("color", "#8b5cf6").lower()
        if not name or not re.fullmatch(r"#[0-9a-f]{6}", color):
            flash("Informe um nome e uma cor válidos.", "error")
            return redirect(url_for("categories"))
        try:
            with db() as connection:
                updated = connection.execute(
                    "UPDATE categories SET name=?, color=? WHERE id=? AND user_id=?", (name, color, category_id, user_id)
                )
            flash("Categoria atualizada." if updated.rowcount else "Categoria não encontrada.", "success" if updated.rowcount else "error")
        except sqlite3.IntegrityError:
            flash("Já existe uma categoria com esse nome.", "error")
        return redirect(url_for("categories"))

    @app.post("/categories/<int:category_id>/delete")
    def delete_category(category_id: int):
        user_id = active_user_id()
        with db() as connection:
            deleted = connection.execute("DELETE FROM categories WHERE id=? AND user_id=?", (category_id, user_id))
        if deleted.rowcount:
            flash("Categoria excluída. Os registros vinculados foram mantidos como sem categoria.", "success")
        else:
            flash("Categoria não encontrada.", "error")
        return redirect(url_for("categories"))

    @app.get("/api/summary")
    def api_summary():
        user_id = active_user_id()
        month = request.args.get("month", date.today().strftime("%Y-%m"))
        with db() as connection:
            row = connection.execute(
                """SELECT COALESCE(SUM(CASE WHEN type='income' THEN amount_cents END),0) income,
                          COALESCE(SUM(CASE WHEN type='expense' THEN amount_cents END),0) expense
                   FROM transactions WHERE substr(occurred_on,1,7)=? AND user_id=?""", (month, user_id)
            ).fetchone()
        return jsonify({"month": month, "income_cents": row["income"], "expense_cents": row["expense"], "balance_cents": row["income"] - row["expense"]})

    @app.get("/export")
    def export_data():
        user_id = active_user_id()
        with db() as connection:
            payload = {
                "exported_at": datetime.now().isoformat(timespec="seconds"),
                "categories": [dict(r) for r in connection.execute("SELECT * FROM categories WHERE user_id=?", (user_id,))],
                "transactions": [dict(r) for r in connection.execute("SELECT * FROM transactions WHERE user_id=?", (user_id,))],
                "expenses": [dict(r) for r in connection.execute("SELECT * FROM expenses WHERE user_id=?", (user_id,))],
            }
        response = app.response_class(json.dumps(payload, ensure_ascii=False, indent=2), mimetype="application/json")
        response.headers["Content-Disposition"] = "attachment; filename=financas-backup.json"
        return response

    return app


app = create_app()

if __name__ == "__main__":
    app.run(debug=True, host="127.0.0.1", port=5000)

