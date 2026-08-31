# Codex Box: następne kroki

Stan docelowy ma trzy repozytoria infrastruktury i pracy:

- prywatny `agent-playbook` — kanoniczne skills, workflowy, szablony, globalny `AGENTS.md` i dokumentacja lokalnego harnessu na Macu;
- publiczny `codex-box` — odtwarzalny serwer OCI, Codex, Tailscale i ręczny fallback DeepSeek.
- prywatny `personal-workspace` — trwałe notatki, szkice, inbox, rezultaty i stan pracy niezwiązany z jednym projektem.

Repozytoria konkretnych aplikacji pozostają osobno w `~/src`. Nie kopiuj ich do
`personal-workspace`.

`ai-workflow` nie jest już potrzebny jako osobne repozytorium. Nie wypychaj go.
Usuń lub zarchiwizuj je dopiero po udanym teście Agent Playbook na Macu i serwerze.

## 1. Wypchnij Agent Playbook

Na Macu:

```bash
cd /Users/erykiwinski/Projekty/agent-playbook
./tests/smoke.sh
git status --short
git log -3 --oneline
git push origin master
```

Repozytorium musi pozostać prywatne. Nie może zawierać kluczy API, tokenów,
sesji Codexa ani cache pluginów.

## 2. Lokalna instalacja na Macu — wykonana

Pierwsza migracja została wykonana 26 sierpnia 2026. Stare osobiste skills są w
odzyskiwalnym backupie pod `~/.config/agent-playbook/`, a aktywne symlinki w
`~/.agents/skills/` wskazują na `agent-playbook`.

Przy kolejnych lokalnych aktualizacjach wystarczy:

```bash
cd /Users/erykiwinski/Projekty/agent-playbook
./install.sh
```

Katalog `.system` pozostał nietknięty. Zamknij bieżące zadania Codexa i uruchom
nowe, aby odświeżyć discovery skills i `AGENTS.md`.

## 3. Wypchnij Personal Workspace

Na Macu, po utworzeniu prywatnego pustego repo `ieryk/personal-workspace`:

```bash
cd /Users/erykiwinski/Projekty/personal-workspace
git remote add origin git@github.com:ieryk/personal-workspace.git
git push -u origin master
git push -u origin develop
```

Repo musi pozostać prywatne. Przed każdym pushem sprawdź, czy nie ma w nim
sekretów ani danych, których nie chcesz przechowywać na GitHubie.

## 4. Wydaj Codex Box v0.3.0

Na Macu:

```bash
cd /Users/erykiwinski/Projekty/codex-box
./tests/smoke.sh
git status --short
git push origin main
git tag -a v0.3.0 -m "Codex Box v0.3.0"
git push origin v0.3.0
```

Najpierw wypchnij `agent-playbook`, ponieważ Codex Box będzie go klonował po
zalogowaniu do GitHuba.

## 5. Zaktualizuj działający serwer

W sesji SSH na serwerze:

```bash
sudo sed -i 's/^BOX_REPO_REF=.*/BOX_REPO_REF="v0.3.0"/' /etc/default/codex-box
box-update
box-playbook-sync
box-workspace-sync setup
box-doctor
```

`box-playbook-sync` klonuje prywatny `agent-playbook` do
`~/.local/share/agent-playbook`, a potem uruchamia jego instalator. Nie używa
`rsync`.

Po aktualizacji zamknij stare sesje Codexa na serwerze i uruchom nową sesję.

Timer zapisuje lokalne snapshoty co 15 minut. Po pracy wypchnij je świadomie:

```bash
box-workspace-sync push
```

## 6. Włącz Open WebUI Computer

Pierwsze przejście ze starszej wersji wymaga jawnego włączenia komponentu:

```bash
sudo env TARGET_USER=ubuntu INSTALL_COMPUTER=1 CPTR_VERSION=0.9.21 CPTR_PORT=8000 \
  BOX_REPO_REF=v0.3.0 /opt/codex-box/bootstrap.sh
box-computer setup
```

Po utworzeniu konta w przeglądarce dodaj profil Codex opisany w `README.md`.
Port 8000 pozostaje zamknięty w OCI; dostęp odbywa się przez Tailscale Serve.

Dodaj `/home/ubuntu/personal-workspace` w Computer jako workspace `Home`.

## 7. Test końcowy

Na Macu i serwerze sprawdź:

```bash
readlink ~/.codex/AGENTS.md
find -L ~/.agents/skills -mindepth 2 -maxdepth 2 -name SKILL.md | sort
box-workspace-sync status
```

Następnie uruchom Codexa w testowym repozytorium i sprawdź `/status`. Globalny
`AGENTS.md` powinien być aktywny, a osobiste skills dostępne bez duplikatów.

## 8. Dopiero wtedy wycofaj `ai-workflow`

Po udanym teście:

- zachowaj checklistę Maca w `agent-playbook/docs/setup/mac-ai-harness-checklist.html`;
- zarchiwizuj lokalny katalog i repozytorium GitHub `ai-workflow` albo usuń je,
  jeśli na pewno nie zawiera niczego więcej;
- nie instaluj równolegle całego repo AI Hero — służy tylko jako upstream do
  świadomego wybierania pojedynczych ulepszeń.

## Odłożone świadomie

- Hermes jako osobisty asystent do zadań i komunikacji;
- OmniRoute, Hermes, LM Studio i lokalne modele wyłącznie w lokalnym harnessie na Macu;
- Docker na serwerze dopiero wtedy, gdy wymaga go konkretny projekt;
- selektywna ocena nowych elementów AI Hero: `research`, `code-review` i zasada
  redagowania sekretów z `diagnosing-bugs`.
