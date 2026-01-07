#!/bin/bash

################################################################################
# Script de déploiement automatique sur serveur distant
# Usage: ./scripts/deploy-to-server.sh
################################################################################

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

################################################################################
# 1. Vérifications préalables
################################################################################

log "=== Vérification des prérequis ==="

# Vérifier que Docker est installé
if ! command -v docker &> /dev/null; then
    error "Docker n'est pas installé"
    info "Installation de Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    log "Docker installé avec succès"
    warning "Veuillez vous déconnecter et reconnecter pour que les changements prennent effet"
    exit 0
fi

# Vérifier que Docker Compose est installé
if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null 2>&1; then
    error "Docker Compose n'est pas installé"
    info "Installation de Docker Compose..."
    sudo apt update
    sudo apt install -y docker-compose
    log "Docker Compose installé avec succès"
fi

# Vérifier que jq est installé
if ! command -v jq &> /dev/null; then
    info "Installation de jq..."
    sudo apt install -y jq
fi

# Vérifier que git est installé
if ! command -v git &> /dev/null; then
    info "Installation de git..."
    sudo apt install -y git
fi

# Vérifier que lsof est installé (nécessaire pour vérifier Ollama)
if ! command -v lsof &> /dev/null; then
    info "Installation de lsof..."
    sudo apt install -y lsof
fi

log "✓ Tous les prérequis sont installés"

################################################################################
# 2. Installation et configuration d'Ollama (OBLIGATOIRE)
################################################################################

log "=== Installation et configuration d'Ollama ==="

# Vérifier la RAM disponible
TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
if [ "$TOTAL_RAM" -lt 16 ]; then
    error "RAM insuffisante: ${TOTAL_RAM}GB détectés"
    error "Ollama nécessite au moins 16GB de RAM pour fonctionner correctement"
    error "Veuillez upgrader votre serveur avant de continuer"
    exit 1
fi

log "✓ RAM suffisante: ${TOTAL_RAM}GB détectés"

# Vérifier si Ollama est déjà installé
if command -v ollama &> /dev/null; then
    log "✓ Ollama est déjà installé"
    OLLAMA_VERSION=$(ollama --version 2>&1 | head -1)
    info "Version: $OLLAMA_VERSION"
else
    log "Installation d'Ollama..."
    curl -fsSL https://ollama.com/install.sh | sh
    log "✓ Ollama installé avec succès"
fi

# Configurer Ollama pour écouter sur toutes les interfaces (requis pour Docker)
log "Configuration d'Ollama pour Docker..."

if systemctl is-active --quiet ollama; then
    # Ollama est géré par systemd
    sudo systemctl stop ollama

    # Créer le fichier de configuration
    sudo mkdir -p /etc/systemd/system/ollama.service.d/
    sudo tee /etc/systemd/system/ollama.service.d/environment.conf > /dev/null <<EOF
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
EOF

    sudo systemctl daemon-reload
    sudo systemctl start ollama
    sudo systemctl enable ollama

    log "✓ Ollama configuré avec systemd"
else
    # Démarrer Ollama manuellement
    export OLLAMA_HOST=0.0.0.0:11434
    nohup ollama serve > /tmp/ollama.log 2>&1 &
    sleep 3
    log "✓ Ollama démarré manuellement"
fi

# Vérifier qu'Ollama écoute sur la bonne interface
sleep 2
if lsof -iTCP:11434 -sTCP:LISTEN &> /dev/null; then
    OLLAMA_LISTEN=$(lsof -iTCP:11434 -sTCP:LISTEN | grep -v COMMAND | awk '{print $9}')
    if echo "$OLLAMA_LISTEN" | grep -q "\*:11434"; then
        log "✓ Ollama écoute sur toutes les interfaces (*:11434)"
    else
        warning "Ollama écoute sur : $OLLAMA_LISTEN"
        warning "Attendu : *:11434 ou 0.0.0.0:11434"
    fi
else
    error "Ollama ne semble pas écouter sur le port 11434"
    info "Vérifiez les logs : tail -f /tmp/ollama.log"
fi

# Télécharger le modèle par défaut (optionnel mais recommandé)
info "Téléchargement du modèle llama3.1:8b (peut prendre plusieurs minutes)..."
ollama pull llama3.1:8b || warning "Échec du téléchargement du modèle - vous pourrez le faire plus tard"

log "✓ Ollama configuré et prêt"

################################################################################
# 3. Configuration des variables d'environnement
################################################################################

log "=== Configuration des variables d'environnement ==="

if [ ! -f .env ]; then
    if [ -f .env.example ]; then
        cp .env.example .env
        log "Fichier .env créé depuis .env.example"
    else
        error "Fichier .env.example introuvable"
        exit 1
    fi
fi

# Générer des clés sécurisées si elles n'existent pas
if ! grep -q "N8N_ENCRYPTION_KEY=" .env || grep -q "N8N_ENCRYPTION_KEY=$" .env; then
    ENCRYPTION_KEY=$(openssl rand -hex 32)
    sed -i "s/N8N_ENCRYPTION_KEY=.*/N8N_ENCRYPTION_KEY=$ENCRYPTION_KEY/" .env
    log "✓ N8N_ENCRYPTION_KEY générée"
fi

if ! grep -q "N8N_USER_MANAGEMENT_JWT_SECRET=" .env || grep -q "N8N_USER_MANAGEMENT_JWT_SECRET=$" .env; then
    JWT_SECRET=$(openssl rand -hex 32)
    sed -i "s/N8N_USER_MANAGEMENT_JWT_SECRET=.*/N8N_USER_MANAGEMENT_JWT_SECRET=$JWT_SECRET/" .env
    log "✓ N8N_USER_MANAGEMENT_JWT_SECRET générée"
fi

if ! grep -q "POSTGRES_PASSWORD=" .env || grep -q "POSTGRES_PASSWORD=password" .env; then
    PG_PASSWORD=$(openssl rand -base64 32 | tr -d '/+=')
    sed -i "s/POSTGRES_PASSWORD=.*/POSTGRES_PASSWORD=$PG_PASSWORD/" .env
    log "✓ POSTGRES_PASSWORD générée"
fi

log "✓ Variables d'environnement configurées"
warning "Vérifiez et modifiez .env avec vos propres valeurs pour :"
warning "  - RAG_UPSTREAM_URL"
warning "  - BRAINTRUST_API_KEY"
warning "  - SUPABASE_URL et SUPABASE_API_KEY"
warning "  - GOOGLE_ANALYTICS_* (si utilisé)"

################################################################################
# 3. Configuration Git
################################################################################

log "=== Configuration Git ==="

if [ -z "$(git config user.email)" ]; then
    read -p "Email Git : " GIT_EMAIL
    git config user.email "$GIT_EMAIL"
    log "✓ Email Git configuré : $GIT_EMAIL"
fi

if [ -z "$(git config user.name)" ]; then
    read -p "Nom Git : " GIT_NAME
    git config user.name "$GIT_NAME"
    log "✓ Nom Git configuré : $GIT_NAME"
fi

################################################################################
# 4. Démarrage des services Docker
################################################################################

log "=== Démarrage des services Docker ==="

# Arrêter les conteneurs existants
if docker-compose ps &> /dev/null; then
    info "Arrêt des conteneurs existants..."
    docker-compose down
fi

# Démarrer tous les services
log "Démarrage de tous les services..."
docker-compose up -d

# Attendre que les services soient prêts
info "Attente du démarrage des services (30 secondes)..."
sleep 30

# Vérifier que tous les services tournent
RUNNING=$(docker-compose ps --services --filter "status=running" | wc -l)
TOTAL=$(docker-compose ps --services | wc -l)

if [ "$RUNNING" -eq "$TOTAL" ]; then
    log "✓ Tous les services sont démarrés ($RUNNING/$TOTAL)"
else
    warning "Seulement $RUNNING/$TOTAL services sont démarrés"
    info "Vérifiez les logs avec : docker-compose logs"
fi

################################################################################
# 5. Attente de N8N et récupération de l'URL
################################################################################

log "=== Configuration de N8N ==="

# Attendre que N8N soit accessible
info "Attente de la disponibilité de N8N..."
MAX_ATTEMPTS=30
ATTEMPT=0

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
    if curl -s http://localhost:5678 > /dev/null 2>&1; then
        log "✓ N8N est accessible"
        break
    fi
    ATTEMPT=$((ATTEMPT + 1))
    sleep 2
done

if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    error "N8N n'est pas accessible après $MAX_ATTEMPTS tentatives"
    info "Vérifiez les logs : docker logs n8n"
else
    # Obtenir l'IP du serveur
    SERVER_IP=$(hostname -I | awk '{print $1}')

    log "✓ N8N est prêt !"
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo -e "${GREEN}N8N accessible sur :${NC}"
    echo -e "  ${BLUE}http://localhost:5678${NC}  (local)"
    echo -e "  ${BLUE}http://$SERVER_IP:5678${NC}  (externe)"
    echo ""
    echo -e "${YELLOW}⚠️  Créez un compte admin lors de la première visite${NC}"
    echo -e "${YELLOW}⚠️  Puis créez une clé API : Settings → API → Create${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
fi

################################################################################
# 6. Affichage des URLs des services
################################################################################

log "=== Services déployés ==="

SERVER_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}Services accessibles :${NC}"
echo ""
echo -e "  ${BLUE}N8N :${NC}         http://$SERVER_IP:5678"
echo -e "  ${BLUE}Grafana :${NC}     http://$SERVER_IP:3000  (admin/admin)"
echo -e "  ${BLUE}NGINX Proxy :${NC} http://$SERVER_IP:8080"
echo -e "  ${BLUE}Prometheus :${NC}  http://$SERVER_IP:9090"
echo ""
echo -e "${GREEN}Services internes (via Docker network) :${NC}"
echo ""
echo -e "  ${BLUE}PostgreSQL :${NC}  postgres:5432"
echo -e "  ${BLUE}Qdrant :${NC}      http://qdrant:6333"
echo -e "  ${BLUE}Loki :${NC}        http://loki:3100"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

################################################################################
# 7. Configuration du cron job pour l'export
################################################################################

log "=== Configuration de l'export automatique des workflows ==="

# Obtenir le chemin absolu du projet
PROJECT_DIR=$(pwd)

# Créer l'entrée cron
CRON_ENTRY="0 */6 * * * cd $PROJECT_DIR && docker exec n8n sh -c \"cd /data && . /data/.env && sh /data/scripts/export-n8n-workflows-docker.sh\" >> /tmp/n8n-export.log 2>&1"

# Vérifier si l'entrée existe déjà
if crontab -l 2>/dev/null | grep -q "n8n-export"; then
    warning "Le cron job d'export existe déjà"
else
    # Ajouter au crontab
    (crontab -l 2>/dev/null; echo "# Export automatique workflows N8N toutes les 6 heures") | crontab -
    (crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -
    log "✓ Cron job configuré (export toutes les 6 heures)"
fi

################################################################################
# 8. Instructions finales
################################################################################

log "=== Déploiement terminé avec succès ! ==="

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "${GREEN}Prochaines étapes :${NC}"
echo ""
echo "1. ${YELLOW}Configurer N8N${NC}"
echo "   - Ouvrir http://$SERVER_IP:5678"
echo "   - Créer un compte admin"
echo "   - Settings → API → Create an API key"
echo "   - Ajouter la clé dans .env : N8N_API_KEY=..."
echo ""
echo "2. ${YELLOW}Configurer Grafana${NC}"
echo "   - Ouvrir http://$SERVER_IP:3000"
echo "   - Login : admin/admin"
echo "   - Changer le mot de passe"
echo "   - Explorer les logs : {job=\"nginx\"} | json"
echo ""
echo "3. ${YELLOW}Tester l'export des workflows${NC}"
echo "   docker exec n8n sh -c \"cd /data && . /data/.env && sh /data/scripts/export-n8n-workflows-docker.sh\""
echo ""
echo "4. ${YELLOW}Vérifier les services${NC}"
echo "   docker-compose ps"
echo "   docker-compose logs -f"
echo ""
echo "5. ${YELLOW}Configurer le pare-feu (recommandé)${NC}"
echo "   sudo ufw allow 22/tcp   # SSH"
echo "   sudo ufw allow 80/tcp   # HTTP"
echo "   sudo ufw allow 443/tcp  # HTTPS"
echo "   sudo ufw allow 5678/tcp # N8N"
echo "   sudo ufw allow 3000/tcp # Grafana"
echo "   sudo ufw allow 8080/tcp # Proxy"
echo "   sudo ufw enable"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${GREEN}Documentation complète :${NC} DEPLOYMENT_GUIDE.md"
echo ""

log "=== Déploiement terminé ! ==="
