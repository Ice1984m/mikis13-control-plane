#!/data/data/com.termux/files/usr/bin/bash
set -Eeuo pipefail

export GIT_PAGER=cat
export GH_PAGER=cat
export PAGER=cat
export LESS='-FRX'

REPO="Ice1984m/mikis13-control-plane"
DIR="$HOME/mikis13-control-plane"
BACKUP="$HOME/.mikis13/control-plane-backups"
STATE="$HOME/.mikis13/control-plane-state"

STAMP="$(date +%Y%m%d-%H%M%S)"
LOG="$STATE/repair-$STAMP.log"
LOCK="$STATE/repair.lock"

STASH_NAME="mikis13-control-plane-auto-backup-$STAMP"
STASH_CREATED=0
RUN_ID=""
RUN_RC=0

mkdir -p "$BACKUP" "$STATE"

exec > >(tee -a "$LOG") 2>&1

cleanup() {
  rm -f "$LOCK" 2>/dev/null || true
}

trap cleanup EXIT

trap '
  echo
  echo "❌ Repair Bot fout op regel $LINENO"
' ERR

echo "===================================================="
echo " MIKIS13 CONTROL PLANE REPAIR BOT V4"
echo "===================================================="

# ------------------------------------------------------------
# LOCK
# ------------------------------------------------------------

if [ -e "$LOCK" ]; then
  OLD_PID="$(cat "$LOCK" 2>/dev/null || true)"

  if [ -n "$OLD_PID" ] &&
     kill -0 "$OLD_PID" 2>/dev/null
  then
    echo "❌ Repair Bot draait reeds met PID $OLD_PID"
    exit 1
  fi

  rm -f "$LOCK"
fi

printf '%s\n' "$$" > "$LOCK"

# ------------------------------------------------------------
# TOOLS
# ------------------------------------------------------------

for CMD in \
  git \
  gh \
  jq \
  curl \
  timeout \
  awk \
  sed
do
  command -v "$CMD" >/dev/null 2>&1 || {
    echo "❌ Ontbreekt: $CMD"
    exit 1
  }
done

echo "✅ Tools OK"

# ------------------------------------------------------------
# GITHUB LOGIN
# ------------------------------------------------------------

if ! gh auth status >/dev/null 2>&1
then
  echo "❌ GitHub login ontbreekt"
  echo "Voer uit: gh auth login"
  exit 1
fi

echo "✅ GitHub login OK"

# ------------------------------------------------------------
# REPOSITORY
# ------------------------------------------------------------

if [ ! -d "$DIR/.git" ]
then
  gh repo clone "$REPO" "$DIR"
fi

cd "$DIR"

git config core.pager cat
git config pager.diff false
git config pager.log false
git config pager.branch false

echo
echo "=== HUIDIGE STATUS ==="
git --no-pager status --short || true

# ------------------------------------------------------------
# LOKALE WIJZIGINGEN BACKUP
# ------------------------------------------------------------

if [ -n "$(git status --porcelain)" ]
then
  echo
  echo "⚠️ Lokale wijzigingen gevonden"

  git --no-pager status --short \
    > "$BACKUP/status-$STAMP.txt" || true

  git --no-pager diff \
    > "$BACKUP/working-tree-$STAMP.patch" || true

  git --no-pager diff --cached \
    > "$BACKUP/staged-$STAMP.patch" || true

  git ls-files \
    --others \
    --exclude-standard \
    > "$BACKUP/untracked-$STAMP.txt" || true

  git stash push \
    --include-untracked \
    -m "$STASH_NAME"

  STASH_CREATED=1

  echo "✅ Lokale wijzigingen veilig gestashed"
else
  echo "✅ Working tree schoon"
fi

# ------------------------------------------------------------
# MAIN SYNC
# ------------------------------------------------------------

echo
echo "=== MAIN SYNCHRONISEREN ==="

git fetch origin --prune
git checkout main

if ! git pull --ff-only origin main
then
  LOCAL="$(git rev-parse main)"
  REMOTE="$(git rev-parse origin/main)"

  if git merge-base \
    --is-ancestor \
    "$LOCAL" \
    "$REMOTE"
  then
    git reset --hard "$REMOTE"
  else
    echo "❌ Lokale commits aanwezig op main."
    echo "Automatische reset geweigerd."
    exit 1
  fi
fi

echo "✅ main OK"

# ------------------------------------------------------------
# CONFIG
# ------------------------------------------------------------

mkdir -p \
  config \
  public \
  reports \
  history \
  state

cat > config/system.json <<'JSON'
{
  "site_dir": "public"
}
JSON

jq empty config/system.json

echo "✅ config/system.json OK"

# ------------------------------------------------------------
# CONTROL PLANE HTML
# ------------------------------------------------------------

test -s public/index.html || {
  echo "❌ public/index.html ontbreekt"
  exit 1
}

if [ ! -s public/control-plane.html ]
then
cat > public/control-plane.html <<'HTML'
<!doctype html>
<html lang="nl">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Mikis13 Control Plane</title>
</head>
<body>
<main>
<h1>Mikis13 Control Plane</h1>
<p>
Automatische bewaking voor repositories,
workflows, hosting, security en status.
</p>
<ul>
<li>Repository status</li>
<li>GitHub Actions monitoring</li>
<li>Security scan</li>
<li>Drift detection</li>
<li>E2E website controle</li>
<li>History en rapporten</li>
</ul>
<p><a href="index.html">Terug naar dashboard</a></p>
</main>
</body>
</html>
HTML
fi

echo "✅ Dashboard OK"

# ------------------------------------------------------------
# PERMISSIONS
# ------------------------------------------------------------

chmod +x scripts/*.sh 2>/dev/null || true
chmod +x tests/*.sh 2>/dev/null || true

# ------------------------------------------------------------
# DOCTOR
# ------------------------------------------------------------

echo
echo "=== DOCTOR ==="

timeout 180 ./scripts/doctor.sh

echo "✅ DOCTOR PASS"

# ------------------------------------------------------------
# COMMIT CONFIG FIX
# ------------------------------------------------------------

git add \
  config/system.json \
  public/control-plane.html

if ! git diff --cached --quiet
then
  git config user.name >/dev/null 2>&1 ||
    git config user.name "Mikis13 Repair Bot"

  git config user.email >/dev/null 2>&1 ||
    git config user.email \
      "mikis13-repair-bot@users.noreply.github.com"

  git commit \
    -m "Maintain Control Plane CI configuration"

  git push origin main

  echo "✅ Config repair gepusht"
else
  echo "ℹ️ Config reeds correct"
fi

# ------------------------------------------------------------
# DEPLOY REPAIR BOT ZELF NAAR REPO
# ------------------------------------------------------------

mkdir -p scripts

cp "$HOME/repair-mikis13-control-plane-v4.sh" \
   scripts/control-plane-repair-v4.sh

chmod +x scripts/control-plane-repair-v4.sh

git add scripts/control-plane-repair-v4.sh

if ! git diff --cached --quiet
then
  git commit \
    -m "Deploy Control Plane repair bot V4"

  git push origin main

  echo "✅ Repair Bot V4 naar GitHub gedeployed"
else
  echo "✅ Repair Bot V4 reeds actueel"
fi

# ------------------------------------------------------------
# WORKFLOW START
# ------------------------------------------------------------

echo
echo "=== WORKFLOW STARTEN ==="

BEFORE_ID="$(
  gh run list \
    --repo "$REPO" \
    --workflow "Mikis13 Control Plane" \
    --limit 1 \
    --json databaseId \
    --jq '.[0].databaseId // empty' \
    2>/dev/null || true
)"

gh workflow run \
  control-plane.yml \
  --repo "$REPO"

for TRY in $(seq 1 30)
do
  RUN_ID="$(
    gh run list \
      --repo "$REPO" \
      --workflow "Mikis13 Control Plane" \
      --event workflow_dispatch \
      --limit 1 \
      --json databaseId \
      --jq '.[0].databaseId // empty' \
      2>/dev/null || true
  )"

  if [ -n "$RUN_ID" ] &&
     [ "$RUN_ID" != "$BEFORE_ID" ]
  then
    break
  fi

  sleep 2
done

if [ -z "$RUN_ID" ] ||
   [ "$RUN_ID" = "$BEFORE_ID" ]
then
  echo "❌ Nieuwe workflow-run niet gevonden"
  RUN_RC=1
else
  echo "✅ Run ID: $RUN_ID"

  set +e

  gh run watch \
    "$RUN_ID" \
    --repo "$REPO" \
    --exit-status

  RUN_RC=$?

  set -e

  gh run view \
    "$RUN_ID" \
    --repo "$REPO" \
    --json status,conclusion,url,headSha,workflowName \
    --jq '.'

  if [ "$RUN_RC" -ne 0 ]
  then
    echo
    echo "========== FAILED LOG =========="

    gh run view \
      "$RUN_ID" \
      --repo "$REPO" \
      --log-failed || true
  else
    echo "✅ CONTROL PLANE WORKFLOW PASS"
  fi
fi

# ------------------------------------------------------------
# ROBUUST STASH HERSTEL
# ------------------------------------------------------------

echo
echo "=== LOKALE WIJZIGINGEN HERSTELLEN ==="

if [ "$STASH_CREATED" -eq 1 ]
then
  STASH_REF=""

  # Geen pipefail-probleem:
  # hele stashlijst eerst in variabele lezen.
  STASH_LIST="$(
    git stash list \
      --format='%gd%x09%s' \
      2>/dev/null || true
  )"

  while IFS=$'\t' read -r REF MSG
  do
    [ -n "$REF" ] || continue

    case "$MSG" in
      *"$STASH_NAME"*)
        STASH_REF="$REF"
        break
        ;;
    esac
  done <<< "$STASH_LIST"

  if [ -z "$STASH_REF" ]
  then
    echo "⚠️ Eigen stash niet gevonden."
    echo "Bestaande stashes blijven onaangeraakt."
  else
    echo "Eigen stash gevonden: $STASH_REF"

    set +e

    git stash apply "$STASH_REF"
    APPLY_RC=$?

    set -e

    if [ "$APPLY_RC" -eq 0 ]
    then
      git stash drop "$STASH_REF" || true
      echo "✅ Lokale wijzigingen succesvol teruggezet"
    else
      echo
      echo "⚠️ Conflict tijdens stash-herstel"
      echo "De stash wordt NIET verwijderd."
      echo "Je werk blijft veilig."
      echo
      git --no-pager status --short || true
      echo
      echo "Stash:"
      echo "  $STASH_REF"
    fi
  fi
else
  echo "ℹ️ Geen nieuwe stash gemaakt"
fi

# ------------------------------------------------------------
# OUDE AUTO-STASHES TONEN
# ------------------------------------------------------------

echo
echo "=== OVERGEBLEVEN MIKIS13 STASHES ==="

git stash list \
  --format='%gd %s' |
grep 'mikis13-control-plane-auto-backup' ||
true

# ------------------------------------------------------------
# INSTALL COMMAND
# ------------------------------------------------------------

cat > "$PREFIX/bin/mikis-control-repair" <<CMD
#!/data/data/com.termux/files/usr/bin/bash
exec "$HOME/repair-mikis13-control-plane-v4.sh"
CMD

chmod +x \
  "$PREFIX/bin/mikis-control-repair"

hash -r 2>/dev/null || true

# ------------------------------------------------------------
# STATUS COMMAND
# ------------------------------------------------------------

cat > "$PREFIX/bin/mikis-control-status" <<CMD
#!/data/data/com.termux/files/usr/bin/bash

export GH_PAGER=cat
export PAGER=cat

gh run list \
  --repo "$REPO" \
  --workflow "Mikis13 Control Plane" \
  --limit 5
CMD

chmod +x \
  "$PREFIX/bin/mikis-control-status"

# ------------------------------------------------------------
# END
# ------------------------------------------------------------

echo
echo "===================================================="
echo " MIKIS13 CONTROL PLANE V4 KLAAR"
echo "===================================================="

echo
echo "Repair:"
echo "  mikis-control-repair"

echo
echo "Status:"
echo "  mikis-control-status"

echo
echo "Run:"
echo "  ${RUN_ID:-geen}"

echo
echo "Log:"
echo "  $LOG"

echo
echo "Backup:"
echo "  $BACKUP"

if [ "$RUN_RC" -eq 0 ]
then
  echo
  echo "✅ CONTROL PLANE VOLLEDIG HERSTELD"
else
  echo
  echo "⚠️ Repair uitgevoerd maar workflow bevat nog een fout"
fi

exit "$RUN_RC"

