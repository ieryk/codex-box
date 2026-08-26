# Codex Box

Odtwarzalne środowisko developerskie dla Ubuntu 24.04 ARM64 na Oracle Cloud
Infrastructure (Ampere A1). Repozytorium nie zawiera sekretów.

## Co instaluje

- Codex CLI (oficjalny instalator OpenAI)
- natywny profil DeepSeek V4 Flash jako ręcznie wybierany fallback
- `mise` oraz domyślny Node.js LTS
- Git, Git LFS i GitHub CLI
- Tailscale
- `tmux`, `ripgrep`, `fd`, `fzf`, `jq`, `direnv`, `shellcheck`, `age`
- kompilatory i podstawowe biblioteki deweloperskie
- 4 GB swapu i automatyczne aktualizacje bezpieczeństwa
- opcjonalnie Docker Engine
- prywatny Agent Playbook z globalnym `AGENTS.md`, workflowami i osobistymi skills

Bootstrap jest idempotentny: można go uruchamiać ponownie po zmianie repozytorium.

## Pierwsze wdrożenie na działającej instancji

Na serwerze wykonaj:

```bash
sudo git clone https://github.com/ieryk/codex-box.git /opt/codex-box
sudo env TARGET_USER=ubuntu BOX_REPO_REF=main /opt/codex-box/bootstrap.sh
box-doctor
box-login
```

Po uwierzytelnieniu GitHuba `box-login` klonuje prywatne repozytorium
`ieryk/agent-playbook`, uruchamia jego instalator i podłącza:

- globalne instrukcje jako `~/.codex/AGENTS.md`;
- osobiste skills jako dowiązania w `~/.agents/skills/`.

Późniejsze aktualizacje playbooka wykonuje polecenie:

```bash
box-playbook-sync
```

Agent Playbook pozostaje prywatny. Nie zawiera tokenów, sesji Codexa,
reguł zatwierdzeń ani cache pluginów.

OmniRoute, Hermes, LM Studio i lokalne modele pozostają elementami środowiska
na Macu. Codex Box ich nie instaluje.

Skrypty `box-*` same dodają do ścieżki programy użytkownika, więc zadziałają także
w tej samej sesji SSH. Aby używać bezpośrednio `codex`, `mise` i `node`, otwórz
nową sesję albo wykonaj `exec bash -l`.

### Codex i DeepSeek Flash

Zwykłe polecenie pozostaje oficjalną ścieżką z logowaniem ChatGPT:

```bash
codex
```

Alternatywny profil korzysta bezpośrednio z DeepSeek Responses API, bez
OmniRoute i bez dodatkowego procesu pośredniczącego:

```bash
codex-deepseek
# równoważne: codex --profile deepseek-flash
```

`box-login` może zapisać `DEEPSEEK_API_KEY` w lokalnym pliku
`~/.config/codex-box/secrets.env` z uprawnieniami `600`. Klucz nie trafia do Git.

Codex obsługuje natywne profile providerów, ale nie udostępnia automatycznego
przełączania z providera OpenAI na DeepSeek po błędzie. Dlatego fallback jest
świadomym, ręcznym wyborem jednym poleceniem. Retry wewnątrz DeepSeek są
skonfigurowane niezależnie.

Jeżeli repozytorium jest już w `/opt/codex-box`, zamiast klonowania użyj
`sudo git -C /opt/codex-box pull --ff-only`.

Po zalogowaniu:

```bash
box-clone ieryk/nazwa-repo
cd ~/src/nazwa-repo
codex
```

## Nowa instancja przez cloud-init

1. Skopiuj `cloud-init.yaml` do pliku poza repozytorium.
2. Sprawdź `BOX_REPO_URL` i przypnij `BOX_REPO_REF` do wydanego tagu,
   np. `v0.1.2`.
3. Wklej plik jako initialization script podczas tworzenia instancji OCI.
4. Po pierwszym SSH poczekaj na zakończenie:

```bash
cloud-init status --wait
sudo tail -100 /var/log/codex-box-bootstrap.log
box-doctor
box-login
```

Zalecany obraz to Ubuntu 24.04 Minimal `aarch64`. Repo nie zakłada konkretnego
rozmiaru instancji; obecny box użytkownika ma 2 OCPU, 12 GB RAM i około 193 GB
dysku.

## Wersjonowanie i aktualizacja

Przed użyciem cloud-init wydaj sprawdzoną wersję:

```bash
git tag v0.1.2
git push origin main --tags
```

`box-update` pobiera ref zapisany w `/etc/default/codex-box` i ponownie uruchamia
bootstrap. Dla stabilnych serwerów używaj tagu; `main` jest wygodny podczas prac.

```bash
box-update
box-doctor
```

## Docker

Docker jest domyślnie wyłączony. Włącz go przy instalacji:

```bash
sudo env TARGET_USER=ubuntu INSTALL_DOCKER=1 /opt/codex-box/bootstrap.sh
```

albo później:

```bash
sudo /opt/codex-box/scripts/install-docker.sh ubuntu
```

Po dodaniu użytkownika do grupy `docker` wyloguj się i zaloguj ponownie.

## Sekrety

Nie zapisuj tutaj tokenów, kluczy API ani `~/.codex/auth.json`. GitHub Actions
Secrets są dostępne dla workflowów, ale serwer nie może ich pobierać jak z sejfu.
Logowania interaktywne wykonuje `box-login`. Sekrety aplikacji trzymaj w
menedżerze sekretów albo w zaszyfrowanych plikach `age` poza tym publicznym repo.

## Bezpieczeństwo sieci

Bootstrap nie zamyka publicznego portu SSH. Najpierw uruchom Tailscale, potwierdź
drugą sesję SSH przez adres Tailscale, a dopiero później usuń publiczną regułę
TCP/22 w OCI. Nie rób tych dwóch zmian w jednej sesji.

## Testy lokalne

```bash
./tests/smoke.sh
```

## Dokumentacja źródłowa

- [Codex CLI](https://learn.chatgpt.com/docs/codex/cli)
- [Codex configuration reference](https://learn.chatgpt.com/docs/config-file/config-reference)
- [DeepSeek — integracja z Codex](https://api-docs.deepseek.com/quick_start/agent_integrations/codex/)
- [Logowanie Codex na urządzeniach headless](https://learn.chatgpt.com/docs/auth#login-on-headless-devices)
- [mise](https://mise.jdx.dev/getting-started.html)
- [Tailscale na Linuxie](https://tailscale.com/kb/1031/install-linux)
- [Docker Engine na Ubuntu](https://docs.docker.com/engine/install/ubuntu/)
