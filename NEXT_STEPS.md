# Codex Box — następne kroki

Stan na 25 sierpnia 2026 r. Repozytorium lokalne znajduje się w:

```text
/Users/erykiwinski/.codex/.chatgpt-projects/g-p-6a862730d3d881918b8b4c50880696ec/codex-box
```

Docelowe publiczne repozytorium:

```text
https://github.com/ieryk/codex-box
```

## 1. Napraw logowanie GitHub CLI

Aktualne konto `ieryk` jest rozpoznane przez GitHub CLI, ale zapisany token jest
nieważny. Wykonaj na Macu:

```bash
gh auth login --hostname github.com --git-protocol ssh --web
gh auth status
```

W przeglądarce zaloguj się na konto `ieryk` i zaakceptuj dostęp GitHub CLI.

## 2. Sprawdź lokalne repozytorium

```bash
cd "/Users/erykiwinski/.codex/.chatgpt-projects/g-p-6a862730d3d881918b8b4c50880696ec/codex-box"
./tests/smoke.sh
git status --short
git config user.name
git config user.email
```

Jeżeli dwie ostatnie komendy niczego nie pokażą, ustaw prawdziwe dane autora:

```bash
git config user.name "TWOJE IMIĘ I NAZWISKO"
git config user.email "TWÓJ ADRES E-MAIL POWIĄZANY Z GITHUBEM"
```

## 3. Utwórz pierwszy commit

```bash
git add .
git diff --cached --check
git diff --cached --stat
git commit -m "Initial Codex Box bootstrap"
```

Przed commitem sprawdź wyświetloną listę. W repozytorium nie może być klucza
DeepSeek, `~/.codex/auth.json` ani innych sekretów.

## 4. Utwórz publiczne repozytorium i wypchnij `main`

```bash
gh repo create codex-box --public --source=. --remote=origin --push
git remote -v
gh repo view --web
```

Polecenie `gh repo create` tworzy `https://github.com/ieryk/codex-box`, ustawia
`origin` i wypycha aktualną gałąź `main`.

## 5. Utwórz pierwsze stabilne wydanie

```bash
git tag -a v0.1.0 -m "First deployable Codex Box"
git push origin v0.1.0
git ls-remote --tags origin
```

Plik `cloud-init.yaml` jest już przypięty do `v0.1.0`.

## 6. Wdróż na działającej instancji OCI

Połącz się z serwerem:

```bash
ssh ubuntu@PUBLICZNY_ADRES_IP
```

Na serwerze wykonaj:

```bash
sudo git clone --branch v0.1.0 --depth 1 https://github.com/ieryk/codex-box.git /opt/codex-box
sudo env TARGET_USER=ubuntu BOX_REPO_REF=v0.1.0 INSTALL_DOCKER=0 /opt/codex-box/bootstrap.sh
exec bash -l
box-doctor
box-login
```

`box-login` przeprowadzi przez GitHub, oficjalny Codex, opcjonalny klucz DeepSeek
i Tailscale. DeepSeek można pominąć Enterem i skonfigurować później.

## 7. Sprawdź oba tryby Codexa

Oficjalny Codex przez konto ChatGPT:

```bash
mkdir -p ~/src/codex-box-test
cd ~/src/codex-box-test
git init
codex
```

Ręczny fallback/workhorse DeepSeek V4 Flash:

```bash
cd ~/src/codex-box-test
codex-deepseek
```

Codex nie przełącza providera automatycznie. `codex-deepseek` uruchamia natywny
profil DeepSeek bez OmniRoute.

## 8. Potwierdź Tailscale przed zamknięciem publicznego SSH

```bash
tailscale status
tailscale ip -4
```

Z Maca otwórz drugą, niezależną sesję:

```bash
ssh ubuntu@ADRES_TAILSCALE
```

Dopiero gdy druga sesja działa, można usunąć publiczną regułę TCP/22 w OCI.
Nie zamykaj publicznego SSH przed tym testem.

## 9. Kolejne aktualizacje

Zmiany rozwijaj na `main`, testuj, a wdrażalne wersje oznaczaj nowym tagiem:

```bash
git add .
git commit -m "Describe the change"
git push origin main
git tag -a v0.2.0 -m "Codex Box v0.2.0"
git push origin v0.2.0
```

Na serwerze zmień `BOX_REPO_REF` w `/etc/default/codex-box` na nowy tag, a potem:

```bash
box-update
box-doctor
```

## Odłożone na później

- Hermes jako osobisty asystent do zadań, przypomnień i komunikatorów.
- Docker, dopóki konkretny projekt go nie potrzebuje.
- OmniRoute — nie jest częścią obecnej architektury.
