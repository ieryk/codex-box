# Codex Box: następne kroki

Stan docelowy ma dwa aktywne repozytoria:

- prywatny `agent-playbook` — kanoniczne skills, workflowy, szablony, globalny `AGENTS.md` i dokumentacja lokalnego harnessu na Macu;
- publiczny `codex-box` — odtwarzalny serwer OCI, Codex, Tailscale i ręczny fallback DeepSeek.

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

## 3. Wydaj Codex Box v0.1.2

Na Macu:

```bash
cd /Users/erykiwinski/Projekty/codex-box
./tests/smoke.sh
git status --short
git push origin main
git tag -a v0.1.2 -m "Codex Box v0.1.2"
git push origin v0.1.2
```

Najpierw wypchnij `agent-playbook`, ponieważ Codex Box będzie go klonował po
zalogowaniu do GitHuba.

## 4. Zaktualizuj działający serwer

W sesji SSH na serwerze:

```bash
sudo sed -i 's/^BOX_REPO_REF=.*/BOX_REPO_REF="v0.1.2"/' /etc/default/codex-box
box-update
box-playbook-sync
box-doctor
```

`box-playbook-sync` klonuje prywatny `agent-playbook` do
`~/.local/share/agent-playbook`, a potem uruchamia jego instalator. Nie używa
`rsync`.

Po aktualizacji zamknij stare sesje Codexa na serwerze i uruchom nową sesję.

## 5. Test końcowy

Na Macu i serwerze sprawdź:

```bash
readlink ~/.codex/AGENTS.md
find ~/.agents/skills -mindepth 2 -maxdepth 2 -name SKILL.md | sort
```

Następnie uruchom Codexa w testowym repozytorium i sprawdź `/status`. Globalny
`AGENTS.md` powinien być aktywny, a osobiste skills dostępne bez duplikatów.

## 6. Dopiero wtedy wycofaj `ai-workflow`

Po udanym teście:

- zachowaj checklistę Maca w `agent-playbook/docs/setup/mac-ai-harness-checklist.html`;
- zarchiwizuj lokalny katalog i repozytorium GitHub `ai-workflow` albo usuń je,
  jeśli na pewno nie zawiera niczego więcej;
- nie instaluj równolegle całego repo AI Hero — służy tylko jako upstream do
  świadomego wybierania pojedynczych ulepszeń.

## Odłożone świadomie

- Hermes jako osobisty asystent do zadań i komunikacji;
- Open WebUI Computer jako opcjonalny, mobilny interfejs do Codexa — dopiero po
  ustabilizowaniu bazowego boxa i wyłącznie przez Tailscale, bez publicznego portu;
- OmniRoute, Hermes, LM Studio i lokalne modele wyłącznie w lokalnym harnessie na Macu;
- Docker na serwerze dopiero wtedy, gdy wymaga go konkretny projekt;
- selektywna ocena nowych elementów AI Hero: `research`, `code-review` i zasada
  redagowania sekretów z `diagnosing-bugs`.
