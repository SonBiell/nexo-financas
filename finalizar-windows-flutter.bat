@echo off
setlocal
title Testar e gerar Nexo para Windows
set "PATH=%~dp0tools-bin;%PATH%"
set "CMAKE_GENERATOR_INSTANCE=C:\Program Files (x86)\Microsoft Visual Studio\18\BuildTools"
set "CMAKE_GENERATOR=Visual Studio 18 2026"

subst N: /d >nul 2>&1
subst N: "%~dp0"
if errorlevel 1 goto :failure

pushd "N:\native"

echo [1/5] Preparando componentes do Flutter para Windows...
call flutter precache --windows
if errorlevel 1 goto :failure_project

echo.
echo [2/5] Atualizando dependencias do projeto...
call flutter pub get --offline
if errorlevel 1 goto :failure_project

echo.
echo [3/5] Analisando todo o codigo Flutter...
call flutter analyze
if errorlevel 1 goto :failure_project

echo.
echo [4/5] Executando testes de interface...
call flutter test --reporter expanded
if errorlevel 1 goto :failure_project

echo.
echo [5/5] Gerando aplicativo Windows em modo Release...
if exist "build\windows" rmdir /s /q "build\windows"
call flutter build windows --release -v > "%~dp0build-windows.log" 2>&1
if errorlevel 1 goto :failure_project

rem Remove apenas metadados temporarios que guardam o caminho N:\.
if exist ".dart_tool\hooks_runner" rmdir /s /q ".dart_tool\hooks_runner"

popd
subst N: /d >nul 2>&1

echo.
echo [OK] Analise, testes e compilacao concluidos sem erros.
echo Local: native\build\windows\x64\runner\Release\nexo_financas.exe
pause
exit /b 0

:failure_project
popd
subst N: /d >nul 2>&1
echo O diagnostico da compilacao foi salvo em build-windows.log.
:failure
echo.
echo [ERRO] O processo foi interrompido para nao gerar um aplicativo com falhas.
pause
exit /b 1
