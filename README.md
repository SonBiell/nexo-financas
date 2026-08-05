# Nexo — Finanças Pessoais

Aplicação web pessoal para controlar carteira, entradas, saídas, contas a pagar, categorias e vencimentos. Desenvolvida com Python, Flask, HTML, CSS, JSON e SQLite.

## Recursos

- Dashboard mensal e saldo disponível da carteira.
- Extrato diário, semanal, mensal ou completo.
- Cadastro de despesas parceladas com vencimento e status.
- Pagamento condicionado ao saldo disponível e estorno ao restaurar.
- Alertas para contas atrasadas ou próximas do vencimento.
- Login de usuário único, senha protegida por hash e sessões seguras.
- Exportação de backup em JSON.
- Layout responsivo em dark mode.

## Executar no Windows

Depois de instalar o Python 3.11 ou superior, abra `iniciar.bat`. Na primeira execução, o ambiente será preparado automaticamente e o navegador abrirá em `http://127.0.0.1:5000`.

O banco local fica em `instance/financas.db`. Essa pasta é ignorada pelo Git e nunca deve ser publicada.

## Estrutura

- `app.py`: regras de negócio, autenticação, rotas e consultas.
- `schema.sql`: banco de dados, restrições e índices.
- `templates/`: páginas HTML.
- `static/`: estilos e comportamento da interface.
- `tests/`: testes automatizados dos fluxos críticos.

## Hospedagem gratuita no PythonAnywhere

O PythonAnywhere Free mantém o SQLite no armazenamento privado da conta e fornece HTTPS. O arquivo `pythonanywhere_wsgi.py` cria automaticamente uma chave secreta e o banco em `~/.nexo-private`, fora do repositório público.

1. Crie uma conta gratuita no PythonAnywhere.
2. Abra um console Bash e execute:
   - `git clone https://github.com/SonBiell/nexo-financas.git`
   - `cd nexo-financas`
   - `python3.13 -m venv .venv`
   - `.venv/bin/pip install -r requirements.txt`
3. Na aba **Web**, crie um app em **Manual configuration** com Python 3.13.
4. Configure o virtualenv como `/home/SEU_USUARIO/nexo-financas/.venv`.
5. No arquivo WSGI do painel, use:
   - `import sys`
   - `sys.path.insert(0, '/home/SEU_USUARIO/nexo-financas')`
   - `from pythonanywhere_wsgi import application`
6. Em **Static files**, configure `/static/` para `/home/SEU_USUARIO/nexo-financas/static`.
7. Recarregue o app e abra o endereço HTTPS fornecido.

Contas gratuitas possuem 512 MiB, um web worker e expiração mensal do app; renove gratuitamente pelo painel antes do vencimento.

## Alternativa: Railway com volume persistente

O repositório contém `Dockerfile` e `railway.json` prontos para implantação.

1. Conecte este repositório a um novo projeto no Railway.
2. Adicione um volume persistente montado em `/data`.
3. Configure as variáveis:
   - `FINANCE_ENV=production`
   - `FINANCE_SECRET=` uma chave longa e aleatória
   - `DATABASE_PATH=/data/financas.db`
4. Gere um domínio HTTPS no painel do serviço.
5. Abra o endereço e crie o primeiro acesso.

Sem o volume `/data`, o SQLite será perdido após uma nova implantação. Nunca coloque a chave secreta, o banco ou dados pessoais no GitHub.

## Segurança

Em produção, a aplicação exige uma chave secreta externa, usa cookie seguro, proteção CSRF, HTTPS, cabeçalhos de segurança e senha armazenada somente como hash. O código pode ser público; o arquivo do banco e os valores de produção permanecem privados.

## Testes

```text
python -m unittest discover -s tests -v
```

O GitHub Actions executa essa suíte automaticamente em cada envio.

