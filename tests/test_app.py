import tempfile
import unittest
import sqlite3
from datetime import date

from app import create_app


class FinanceAppTest(unittest.TestCase):
    def setUp(self):
        self.db_file = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
        self.db_file.close()
        self.app = create_app({"TESTING": True, "DATABASE": self.db_file.name, "SECRET_KEY": "test"})
        self.client = self.app.test_client()

    def test_dashboard_loads(self):
        response = self.client.get("/dashboard")
        self.assertEqual(response.status_code, 200)
        self.assertIn("VisÃ£o geral".encode(), response.data)
        self.assertIn(b"dashboard-recent", response.data)
        self.assertIn(b"expenses-desktop.css", response.data)

    def test_dashboard_highlights_overdue_expenses(self):
        self.client.post("/expenses", data={
            "description": "Conta vencida", "amount": "99,90", "due_on": "2020-01-01",
            "installment_count": "1", "category_id": "", "notes": "",
        })
        response = self.client.get("/dashboard")
        self.assertIn("VisÃ£o das despesas".encode(), response.data)
        self.assertIn(b"Conta vencida", response.data)
        self.assertIn("Atrasada".encode(), response.data)

    def test_create_transaction_and_summary(self):
        response = self.client.post("/transactions", data={
            "type": "income", "description": "Freelance", "amount": "1500,50",
            "occurred_on": "2026-08-05", "category_id": "", "notes": "",
        }, follow_redirects=True)
        self.assertIn("TransaÃ§Ã£o salva".encode(), response.data)
        summary = self.client.get("/api/summary?month=2026-08").get_json()
        self.assertEqual(summary["income_cents"], 150050)
        self.assertEqual(summary["balance_cents"], 150050)

    def test_create_category(self):
        response = self.client.post("/categories", data={"name": "SaÃºde", "color": "#ef4444"}, follow_redirects=True)
        self.assertIn("SaÃºde".encode(), response.data)

    def test_edit_and_delete_category_preserves_linked_records(self):
        self.client.post("/categories", data={"name": "Lazer", "color": "#8b5cf6"})
        connection = sqlite3.connect(self.db_file.name)
        category_id = connection.execute("SELECT id FROM categories WHERE name='Lazer'").fetchone()[0]
        connection.close()
        self.client.post("/transactions", data={
            "type": "income", "description": "Reembolso", "amount": "50,00",
            "occurred_on": "2026-08-05", "category_id": str(category_id), "notes": "",
        })
        edited = self.client.post(f"/categories/{category_id}/edit", data={"name": "DiversÃ£o", "color": "#22c55e"}, follow_redirects=True)
        self.assertIn("DiversÃ£o".encode(), edited.data)
        deleted = self.client.post(f"/categories/{category_id}/delete", follow_redirects=True)
        self.assertNotIn("DiversÃ£o".encode(), deleted.data)
        self.assertIn(b"Reembolso", self.client.get("/transactions?period=all").data)

    def test_pwa_manifest_is_available(self):
        response = self.client.get("/static/manifest.webmanifest")
        self.assertEqual(response.status_code, 200)
        self.assertIn(b"Nexo", response.data)

    def test_expense_payment_restore_and_delete(self):
        self.client.post("/expenses", data={
            "description": "Notebook", "amount": "120,00", "due_on": "2099-08-10",
            "installment_count": "12", "category_id": "", "notes": "",
        })
        page = self.client.get("/expenses")
        self.assertIn(b"12 x R$ 120,00", page.data)
        self.assertIn(b"R$ 1.440,00 total", page.data)
        self.assertIn("Pendente".encode(), page.data)
        self.assertIn(b'data-label="Vencimento"', page.data)
        insufficient = self.client.post("/expenses/1/pay", follow_redirects=True)
        self.assertIn("Saldo insuficiente".encode(), insufficient.data)
        self.client.post("/transactions", data={
            "type": "income", "description": "DepÃ³sito", "amount": "2000,00",
            "occurred_on": date.today().isoformat(), "category_id": "", "notes": "",
        })
        self.client.post("/expenses/1/pay")
        paid_once = self.client.get("/expenses").data
        self.assertIn(b"1 / 12", paid_once)
        self.assertIn("Pendente".encode(), paid_once)
        summary = self.client.get(f"/api/summary?month={date.today():%Y-%m}").get_json()
        self.assertEqual(summary["balance_cents"], 188000)
        self.client.post("/expenses/1/restore")
        restored = self.client.get("/expenses").data
        self.assertIn(b"0 / 12", restored)
        self.assertIn("Pendente".encode(), restored)
        summary = self.client.get(f"/api/summary?month={date.today():%Y-%m}").get_json()
        self.assertEqual(summary["balance_cents"], 200000)
        self.client.post("/expenses/1/delete")
        self.assertNotIn(b"Notebook", self.client.get("/expenses").data)
        summary = self.client.get(f"/api/summary?month={date.today():%Y-%m}").get_json()
        self.assertEqual(summary["balance_cents"], 200000)

    def test_monthly_recurring_expense_creates_next_occurrence(self):
        self.client.post("/expenses", data={
            "description": "Internet", "amount": "120,00", "due_on": date.today().isoformat(),
            "installment_count": "6", "category_id": "", "notes": "Mensal",
            "recurring_monthly": "1",
        })
        self.client.get("/expenses")
        connection = sqlite3.connect(self.db_file.name)
        rows = connection.execute(
            "SELECT id, amount_cents, installment_count, recurrence_key FROM expenses WHERE description='Internet' ORDER BY due_on"
        ).fetchall()
        connection.close()
        self.assertEqual(len(rows), 2)
        self.assertTrue(all(row[1] == 12000 and row[2] == 1 and row[3] for row in rows))
        self.client.post(f"/expenses/{rows[0][0]}/delete")
        connection = sqlite3.connect(self.db_file.name)
        remaining = connection.execute("SELECT COUNT(*) FROM expenses WHERE description='Internet'").fetchone()[0]
        connection.close()
        self.assertEqual(remaining, 0)


class AuthenticationTest(unittest.TestCase):
    def setUp(self):
        self.db_file = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
        self.db_file.close()
        self.app = create_app({"TESTING": False, "DATABASE": self.db_file.name, "SECRET_KEY": "auth-test"})
        self.client = self.app.test_client()

    def token(self):
        with self.client.session_transaction() as session:
            return session["csrf_token"]

    def test_setup_login_and_protected_dashboard(self):
        landing = self.client.get("/")
        self.assertEqual(landing.status_code, 200)
        self.assertIn(b"Criar conta", landing.data)
        self.assertIn(b"remember", landing.data)
        self.client.get("/setup")
        response = self.client.post("/setup", data={
            "csrf_token": self.token(), "full_name": "Thiago Silva", "document": "123.456.789-00",
            "birth_date": "1990-05-10", "email": "thiago@example.com", "username": "thiago",
            "password": "segura123", "password_confirmation": "segura123",
        })
        self.assertEqual(response.location, "/dashboard")
        dashboard = self.client.get("/dashboard")
        self.assertIn(b"mobile-logout", dashboard.data)
        connection = sqlite3.connect(self.db_file.name)
        stored = connection.execute("SELECT password_hash FROM users").fetchone()[0]
        connection.close()
        self.assertNotIn("segura123", stored)
        self.client.get("/dashboard")
        self.client.post("/logout", data={"csrf_token": self.token()})
        self.assertEqual(self.client.get("/dashboard").location, "/login?next=/dashboard")
        self.client.get("/login")
        invalid = self.client.post("/login", data={"csrf_token": self.token(), "username": "thiago", "password": "errada"}, follow_redirects=True)
        self.assertIn("invÃ¡lidos".encode(), invalid.data)
        valid = self.client.post("/login", data={"csrf_token": self.token(), "username": "thiago", "password": "segura123"})
        self.assertEqual(valid.location, "/dashboard")

    def test_financial_data_is_private_per_user(self):
        def register(suffix):
            self.client.get("/setup")
            return self.client.post("/setup", data={
                "csrf_token": self.token(), "full_name": f"UsuÃ¡rio Completo {suffix}",
                "document": f"1234567890{suffix}", "birth_date": "1990-05-10",
                "email": f"user{suffix}@example.com", "username": f"user{suffix}",
                "password": "segura123", "password_confirmation": "segura123",
            })

        register("1")
        self.client.get("/transactions")
        self.client.post("/transactions", data={
            "csrf_token": self.token(), "type": "income", "description": "Privado do usuÃ¡rio 1",
            "amount": "500,00", "occurred_on": date.today().isoformat(), "category_id": "", "notes": "",
        })
        self.client.get("/dashboard")
        self.client.post("/logout", data={"csrf_token": self.token()})
        register("2")
        second_view = self.client.get("/transactions?period=all")
        self.assertNotIn("Privado do usuÃ¡rio 1".encode(), second_view.data)
        self.client.get("/transactions")
        self.client.post("/transactions/1/delete", data={"csrf_token": self.token()})
        self.client.get("/dashboard")
        self.client.post("/logout", data={"csrf_token": self.token()})
        self.client.get("/")
        self.client.post("/", data={"csrf_token": self.token(), "username": "user1", "password": "segura123"})
        self.assertIn("Privado do usuÃ¡rio 1".encode(), self.client.get("/transactions?period=all").data)


class NativeApiAuthenticationTest(unittest.TestCase):
    def setUp(self):
        self.db_file = tempfile.NamedTemporaryFile(suffix=".db", delete=False)
        self.db_file.close()
        self.app = create_app({"TESTING": True, "DATABASE": self.db_file.name, "SECRET_KEY": "native-test"})
        self.client = self.app.test_client()

    def register(self, suffix):
        return self.client.post("/api/v2/auth/register", json={
            "full_name": f"UsuÃ¡rio Teste {suffix}", "email": f"user{suffix}@example.com",
            "username": f"user{suffix}", "password": "segura123",
        })

    def test_register_login_and_logout(self):
        registered = self.register("a")
        self.assertEqual(registered.status_code, 201)
        token = registered.get_json()["token"]
        me = self.client.get("/api/v2/auth/me", headers={"Authorization": f"Bearer {token}"})
        self.assertEqual(me.get_json()["user"]["username"], "usera")
        self.client.post("/api/v2/auth/logout", headers={"Authorization": f"Bearer {token}"})
        self.assertEqual(self.client.get("/api/v2/auth/me", headers={"Authorization": f"Bearer {token}"}).status_code, 401)
        login = self.client.post("/api/v2/auth/login", json={"identity": "usera", "password": "segura123"})
        self.assertEqual(login.status_code, 200)

    def test_each_user_receives_separate_categories(self):
        first, second = self.register("one"), self.register("two")
        self.assertEqual(first.status_code, 201)
        self.assertEqual(second.status_code, 201)
        connection = sqlite3.connect(self.db_file.name)
        users = connection.execute("SELECT id FROM users WHERE username IN ('userone','usertwo') ORDER BY username").fetchall()
        counts = [connection.execute("SELECT COUNT(*) FROM categories WHERE user_id=?", (user[0],)).fetchone()[0] for user in users]
        connection.close()
        self.assertEqual(counts, [4, 4])

    def test_native_dashboard_is_isolated_by_user(self):
        first, second = self.register("dashone"), self.register("dashtwo")
        first_token = first.get_json()["token"]
        second_token = second.get_json()["token"]
        connection = sqlite3.connect(self.db_file.name)
        first_user = connection.execute("SELECT id FROM users WHERE username='userdashone'").fetchone()
        connection.execute("""INSERT INTO transactions(user_id,description,amount_cents,type,occurred_on)
                              VALUES(?,?,?,?,?)""", (first_user[0], "Saldo privado", 75000, "income", date.today().isoformat()))
        connection.commit()
        connection.close()
        first_dashboard = self.client.get("/api/v2/dashboard", headers={"Authorization": f"Bearer {first_token}"}).get_json()
        second_dashboard = self.client.get("/api/v2/dashboard", headers={"Authorization": f"Bearer {second_token}"}).get_json()
        self.assertEqual(first_dashboard["balance_cents"], 75000)
        self.assertEqual(len(first_dashboard["recent_transactions"]), 1)
        self.assertEqual(second_dashboard["balance_cents"], 0)
        self.assertEqual(second_dashboard["recent_transactions"], [])

    def test_native_crud_uses_shared_financial_tables(self):
        registered = self.register("crud")
        headers = {"Authorization": f"Bearer {registered.get_json()['token']}"}
        category = self.client.post("/api/v2/categories", headers=headers, json={"name": "SaÃºde", "color": "#14B8A6"})
        self.assertEqual(category.status_code, 201)
        income = self.client.post("/api/v2/transactions", headers=headers, json={
            "description": "Entrada inicial", "amount_cents": 100000, "type": "income",
            "occurred_on": date.today().isoformat(), "category_id": category.get_json()["id"],
        })
        self.assertEqual(income.status_code, 201)
        expense = self.client.post("/api/v2/expenses", headers=headers, json={
            "description": "Conta compartilhada", "amount_cents": 25000,
            "due_on": date.today().isoformat(), "installment_count": 2,
            "category_id": category.get_json()["id"],
        })
        self.assertEqual(expense.status_code, 201)
        paid = self.client.post(f"/api/v2/expenses/{expense.get_json()['id']}/pay", headers=headers)
        self.assertEqual(paid.status_code, 200)
        connection = sqlite3.connect(self.db_file.name)
        self.assertEqual(connection.execute("SELECT COUNT(*) FROM expenses WHERE description='Conta compartilhada'").fetchone()[0], 1)
        self.assertEqual(connection.execute("SELECT COUNT(*) FROM transactions WHERE source='expense_payment'").fetchone()[0], 1)
        connection.close()


if __name__ == "__main__":
    unittest.main()
