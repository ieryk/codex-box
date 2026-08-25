# Sekrety

Ten katalog pozostaje pusty w Git. Nie dodawaj tu tokenów w postaci jawnego tekstu.

`~/.codex/auth.json` zawiera tokeny dostępu i musi pozostać poza repozytorium.
GitHub Actions Secrets są przeznaczone dla workflowów, nie do pobierania przez
zwykły serwer. Do sekretów aplikacyjnych użyj menedżera sekretów lub plików
zaszyfrowanych `age`, a klucz prywatny przechowuj poza repozytorium.

