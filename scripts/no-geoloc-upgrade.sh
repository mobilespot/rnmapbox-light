#!/usr/bin/env bash
set -euo pipefail

echo "Vérification branche actuelle..."
curr=$(git rev-parse --abbrev-ref HEAD)
if [ "$curr" != "no-geoloc" ]; then
  echo "Veuillez être sur la branche 'no-geoloc' avant d'exécuter (actuellement: $curr)."
  exit 1
fi

echo "Création branche de travail 'no-geoloc-upgrade'..."
git checkout -b no-geoloc-upgrade

echo "Fetch remotes and tags..."
git fetch --all --tags --prune

# prefer specific tag if present
TARGET_TAG="v10.3.2-rc.1"
if git rev-parse --verify --quiet "refs/tags/$TARGET_TAG" >/dev/null; then
  TARGET_REF="$TARGET_TAG"
  echo "Utiliser le tag upstream: $TARGET_REF"
else
  TARGET_REF="upstream/main"
  echo "Tag $TARGET_TAG introuvable — utilisation de $TARGET_REF"
fi

echo "Comparaisons initiales..."
git rev-list --left-right --count "${TARGET_REF}...no-geoloc" || true
git diff --name-status "${TARGET_REF}...no-geoloc" > /tmp/diff-no-geoloc.txt || true
git log --oneline "${TARGET_REF}..no-geoloc" > /tmp/commits-no-geoloc.txt || true
echo "Diff enregistré: /tmp/diff-no-geoloc.txt"
echo "Commits locaux: /tmp/commits-no-geoloc.txt"

echo "Liste candidate fichiers liés à la géolocalisation..."
grep -RIn --null "Location\|UserLocation\|LocationProvider\|LocationManager\|NativeUserLocation\|ACCESS_FINE_LOCATION\|ACCESS_COARSE_LOCATION\|requestPermission\|geolocation" src ios android docs __tests__ || true \
  | cut -d: -f1 | sort -u > /tmp/geoloc-files.txt || true
echo "Fichiers géoloc listés dans /tmp/geoloc-files.txt"
echo "VERIFIEZ ce fichier et ajustez-le avant de continuer si besoin."

read -p "Voulez-vous continuer la fusion de ${TARGET_REF} dans no-geoloc-upgrade maintenant ? (y/N) " confirm
if [ "$confirm" != "y" ]; then
  echo "Annulé par l'utilisateur."
  exit 0
fi

echo "Lancement merge en mode non-commit..."
git merge --no-commit --no-ff "${TARGET_REF}" || true

if git diff --name-only --diff-filter=U | grep . >/dev/null 2>&1; then
  echo "Conflits détectés. Application automatique de la règle pour fichiers géoloc protégés..."
  while IFS= read -r f; do
    if [ -n "$f" ] && [ -f "$f" ]; then
      if git diff --name-only --diff-filter=U | grep -xF "$f" >/dev/null 2>&1; then
        echo "Protéger (ours) -> $f"
        git checkout --ours -- "$f"
        git add "$f"
      fi
    fi
  done < /tmp/geoloc-files.txt || true

  echo "Liste des conflits restants (à résoudre manuellement):"
  git diff --name-only --diff-filter=U || true
  echo "Ouvrez votre éditeur, résolvez les conflits en gardant vos logiques locales, puis:"
  echo "  git add <file>..."
  echo "  git commit -m \"chore: merge ${TARGET_REF} into no-geoloc-upgrade — preserve no-geoloc\""
  echo "Le script s'arrête ici pour éviter tout écrasement automatique."
  exit 0
else
  echo "Aucun conflit, finalisation du commit de merge automatique."
  git commit -m "chore: merge ${TARGET_REF} into no-geoloc-upgrade — preserve no-geoloc"
fi

echo "Mise à jour des dépendances et génération (codegen)..."
if command -v yarn >/dev/null 2>&1; then
  yarn install
  yarn generate || yarn prepare || true
else
  echo "Yarn introuvable — installez Yarn et exécutez 'yarn install' puis 'yarn generate' manuellement."
fi

echo "iOS: pod install (si dossier ios présent)..."
if [ -d ios ]; then
  (cd ios && pod install --repo-update) || true
fi

echo "Android: build (si dossier android présent)..."
if [ -d android ]; then
  (cd android && ./gradlew assembleDebug) || true
fi

echo "Vérifications rapides pour réintroductions de géoloc:"
grep -RIn --exclude-dir=node_modules "Location\|ACCESS_FINE_LOCATION\|requestPermission\|navigator.geolocation" . || true

echo "Push optionnel: tapez 'git push origin no-geoloc-upgrade' si vous êtes prêt."
echo "Script terminé."
