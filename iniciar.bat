@echo off
setlocal
cd /d "%~dp0"

title Nexo - Financas Pessoais

if not exist ".venv\Scripts\python.exe" (
  echo Preparando o Nexo pela primeira vez...
  python -m venv .venv
  .venv\Scripts\python.exe -m pip install -r requirements.txt
)

echo Iniciando a versao atual do Nexo...
echo Acesse: http://127.0.0.1:5000
start "" http://127.0.0.1:5000
.venv\Scripts\python.exe app.py

endlocal

