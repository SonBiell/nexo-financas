# Nexo Nativo

Nova aplicação multiusuário para Windows e Android. Este diretório é independente
do aplicativo web atual.

## Preparar o ambiente

1. Instale o Flutter com suporte a Android e Windows.
2. Dentro desta pasta, execute:
   - `flutter create --platforms=android,windows --project-name nexo_financas .`
   - `flutter pub get`
3. Execute com `flutter run`.

A URL padrão da API é a hospedagem atual. Para desenvolvimento local, use:

`flutter run --dart-define=NEXO_API_URL=http://127.0.0.1:5000/api/v2`

## Fase atual

- Design system dark mode.
- Login nativo.
- Criação de conta.
- Token armazenado no cofre seguro do sistema.
- API isolada e banco preparado para múltiplos usuários.

