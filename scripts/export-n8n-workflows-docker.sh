#!/bin/sh

################################################################################
# Script d'export automatique des workflows N8N (version Docker avec wget)
# Ce script exporte tous les workflows N8N en fichiers JSON individuels
################################################################################

set -e

# Configuration
N8N_HOST="${N8N_HOST:-http://localhost:5678}"
N8N_API_KEY="${N8N_API_KEY:-}"
EXPORT_DIR="${EXPORT_DIR:-/data/n8n/workflows}"
COMMIT_CHANGES="${COMMIT_CHANGES:-true}"

# Couleurs pour les logs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction de log
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR:${NC} $1" >&2
}

warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING:${NC} $1"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO:${NC} $1"
}

# Vérifier que jq est installé
if ! command -v jq > /dev/null 2>&1; then
    error "jq n'est pas installé"
    exit 1
fi

# Vérifier que wget est installé
if ! command -v wget > /dev/null 2>&1; then
    error "wget n'est pas installé"
    exit 1
fi

# Créer le dossier d'export s'il n'existe pas
mkdir -p "$EXPORT_DIR"

log "Début de l'export des workflows N8N (Docker version)"
info "N8N Host: $N8N_HOST"
info "Export directory: $EXPORT_DIR"

# Vérifier que la clé API est fournie
if [ -z "$N8N_API_KEY" ]; then
    error "N8N_API_KEY n'est pas définie"
    error "Pour créer une clé API :"
    error "  1. Ouvrez N8N : $N8N_HOST"
    error "  2. Allez dans Settings → API"
    error "  3. Créez une clé API"
    error "  4. Exportez-la : export N8N_API_KEY=votre_clé"
    error "  Ou ajoutez-la dans .env : N8N_API_KEY=votre_clé"
    exit 1
fi

# Récupérer tous les workflows
log "Récupération de la liste des workflows..."

WORKFLOWS=$(wget -q -O - --header="X-N8N-API-KEY: $N8N_API_KEY" "$N8N_HOST/api/v1/workflows")

# Vérifier si l'API a retourné une erreur
if echo "$WORKFLOWS" | jq -e '.message' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$WORKFLOWS" | jq -r '.message')
    error "Erreur API N8N: $ERROR_MSG"
    exit 1
fi

# Vérifier si la requête a réussi
if [ -z "$WORKFLOWS" ]; then
    error "Impossible de récupérer les workflows depuis N8N"
    error "Vérifiez que N8N est accessible sur $N8N_HOST"
    exit 1
fi

# Compter le nombre de workflows
WORKFLOW_COUNT=$(echo "$WORKFLOWS" | jq '.data | length')

if [ "$WORKFLOW_COUNT" -eq 0 ]; then
    warning "Aucun workflow trouvé dans N8N"
    exit 0
fi

log "Nombre de workflows trouvés: $WORKFLOW_COUNT"

# Exporter chaque workflow
EXPORTED_COUNT=0
FAILED_COUNT=0

echo "$WORKFLOWS" | jq -c '.data[]' | while read -r workflow; do
    WORKFLOW_ID=$(echo "$workflow" | jq -r '.id')
    WORKFLOW_NAME=$(echo "$workflow" | jq -r '.name')

    # Nettoyer le nom du workflow pour le nom de fichier
    # Remplacer les caractères spéciaux par des underscores
    SAFE_NAME=$(echo "$WORKFLOW_NAME" | sed 's/[^a-zA-Z0-9_-]/_/g' | sed 's/__*/_/g')

    # Nom du fichier : id_nom.json
    FILENAME="${WORKFLOW_ID}_${SAFE_NAME}.json"
    FILEPATH="$EXPORT_DIR/$FILENAME"

    info "Export du workflow: $WORKFLOW_NAME (ID: $WORKFLOW_ID)"

    # Récupérer le workflow complet
    FULL_WORKFLOW=$(wget -q -O - --header="X-N8N-API-KEY: $N8N_API_KEY" "$N8N_HOST/api/v1/workflows/$WORKFLOW_ID")

    if [ -z "$FULL_WORKFLOW" ]; then
        error "Échec de l'export du workflow $WORKFLOW_NAME"
        FAILED_COUNT=$((FAILED_COUNT + 1))
        continue
    fi

    # Sauvegarder le workflow dans un fichier JSON formaté
    echo "$FULL_WORKFLOW" | jq '.' > "$FILEPATH"

    if [ $? -eq 0 ]; then
        log "✓ Exporté: $FILENAME"
        EXPORTED_COUNT=$((EXPORTED_COUNT + 1))
    else
        error "✗ Échec: $FILENAME"
        FAILED_COUNT=$((FAILED_COUNT + 1))
    fi
done

log "Export terminé: $EXPORTED_COUNT workflows exportés, $FAILED_COUNT échecs"

# Créer un fichier index avec la liste des workflows
log "Création du fichier index..."
cat > "$EXPORT_DIR/index.json" <<EOF
{
  "export_date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "workflow_count": $WORKFLOW_COUNT,
  "workflows": $(echo "$WORKFLOWS" | jq '[.data[] | {id: .id, name: .name, active: .active, updatedAt: .updatedAt}]')
}
EOF

log "✓ Fichier index créé: $EXPORT_DIR/index.json"

# Commit automatique des changements (si activé)
if [ "$COMMIT_CHANGES" = "true" ]; then
    log "Commit des changements dans Git..."

    cd /data

    # Vérifier si git est disponible
    if ! command -v git > /dev/null 2>&1; then
        warning "Git n'est pas installé, skip du commit automatique"
    else
        # Configurer git pour autoriser le dossier /data
        git config --global --add safe.directory /data 2>/dev/null || true

        # Configurer l'identité Git (requis pour les commits)
        git config --global user.email "n8n-export@automated.local" 2>/dev/null || true
        git config --global user.name "N8N Workflow Export" 2>/dev/null || true

        # Ajouter tous les fichiers JSON (nouveaux et modifiés)
        git add "$EXPORT_DIR"/*.json 2>/dev/null || true

        # Vérifier s'il y a des changements à committer (compatible ancienne version Git)
        if git diff --cached --quiet 2>/dev/null; then
            info "Aucun changement détecté dans les workflows"
        else
            COMMIT_MSG="Auto-export N8N workflows - $(date +'%Y-%m-%d %H:%M:%S')

Exported $WORKFLOW_COUNT workflows:
$(echo "$WORKFLOWS" | jq -r '.data[] | "- \(.name) (ID: \(.id))"')

🤖 Generated with [Claude Code](https://claude.com/claude-code)
"

            git commit -m "$COMMIT_MSG"

            log "✓ Changements committés"

            # Optionnel : Push automatique (décommenter si souhaité)
            # git push origin main
            # log "✓ Changements poussés vers GitHub"
        fi
    fi
fi

log "=== Export terminé avec succès ==="
