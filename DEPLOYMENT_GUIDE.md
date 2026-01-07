# Guide de déploiement serveur

Ce guide couvre le déploiement complet de la stack sur un serveur distant (Hostinger, VPS, etc.).

## Table des matières

- [Démarrage rapide](#démarrage-rapide)
- [Prérequis serveur](#prérequis-serveur)
- [Installation pas à pas](#installation-pas-à-pas)
- [Configuration post-installation](#configuration-post-installation)
- [Sécurisation](#sécurisation)
- [Monitoring et logs](#monitoring-et-logs)
- [Sauvegarde automatique](#sauvegarde-automatique)
- [Troubleshooting](#troubleshooting)

---

## Démarrage rapide

### Installation automatique

```bash
# 1. Cloner le projet
git clone git@github.com:maximilienborneext/docker-self-hosted-ia-n8n.git
cd docker-self-hosted-ia-n8n

# 2. Lancer le script d'installation automatique
./scripts/deploy-to-server.sh
```

Le script configure automatiquement :
- Docker + Docker Compose
- Ollama (avec modèle llama3.1:8b)
- Tous les services (N8N, PostgreSQL, Qdrant, Grafana, Loki, NGINX)
- Export automatique des workflows (toutes les 6h)

### Services déployés

| Service | URL | Credentials |
|---------|-----|-------------|
| N8N | `http://VOTRE_IP:5678` | À créer |
| Grafana | `http://VOTRE_IP:3000` | `admin/admin` |
| NGINX Proxy | `http://VOTRE_IP:8080` | - |
| Prometheus | `http://VOTRE_IP:9090` | - |
| Ollama | `http://VOTRE_IP:11434` | - |

### Vérification rapide

```bash
# Tous les services tournent ?
docker-compose ps

# Ollama fonctionne ?
curl http://localhost:8080/api/ollama/api/tags

# Export automatique configuré ?
crontab -l
```

---

## Prérequis serveur

### Spécifications minimales

| Composant | Minimum | Recommandé |
|-----------|---------|------------|
| CPU | 4 cores | 8 cores |
| RAM | **16GB** | 24GB |
| Stockage | 100GB | 200GB+ |
| OS | Ubuntu 22.04 LTS | Ubuntu 22.04 LTS |

**Ollama nécessite au moins 8GB de RAM pour fonctionner correctement. Prévoyez 16GB total.**

### Plans Hostinger recommandés

| Plan | RAM | Statut |
|------|-----|--------|
| VPS 1-3 | 2-8GB | Insuffisant |
| VPS 4 | 16GB | **Minimum** |
| VPS 6 | 24GB | **Recommandé** |

### Logiciels requis

```bash
# Mise à jour système
sudo apt update && sudo apt upgrade -y

# Installation Docker + outils
sudo apt install -y docker.io docker-compose git jq

# Démarrer Docker
sudo systemctl enable docker
sudo systemctl start docker

# Ajouter votre user au groupe docker
sudo usermod -aG docker $USER
# Déconnexion/reconnexion requise
```

---

## Installation pas à pas

### 1. Cloner le repository

```bash
cd ~
git clone git@github.com:maximilienborneext/docker-self-hosted-ia-n8n.git
cd docker-self-hosted-ia-n8n
```

### 2. Configurer l'environnement

```bash
cp .env.example .env
nano .env
```

**Variables à configurer :**

```bash
# PostgreSQL (mots de passe forts)
POSTGRES_USER=n8n_user
POSTGRES_PASSWORD=CHANGEZ_MOI
POSTGRES_DB=n8n

# N8N Encryption (générer avec : openssl rand -hex 32)
N8N_ENCRYPTION_KEY=votre_clé_générée
N8N_USER_MANAGEMENT_JWT_SECRET=votre_clé_générée

# N8N API Key (à générer après premier démarrage)
N8N_API_KEY=

# Services externes (optionnel)
RAG_UPSTREAM_URL=https://votre-service-rag.com
BRAINTRUST_API_KEY=sk-votre-clé
SUPABASE_URL=https://votre-projet.supabase.co
SUPABASE_API_KEY=votre-clé

# Google Analytics (optionnel)
GOOGLE_ANALYTICS_MEASUREMENT_ID=G-XXXXXXXXX
GOOGLE_ANALYTICS_API_SECRET=votre-secret

# Export des workflows (optionnel)
ENABLE_HISTORY=true        # Activer l'historisation
HISTORY_RETENTION=10       # Nombre de snapshots à conserver
```

**Générer des clés sécurisées :**
```bash
openssl rand -hex 32  # Pour N8N_ENCRYPTION_KEY
openssl rand -hex 32  # Pour JWT_SECRET
openssl rand -base64 32  # Pour POSTGRES_PASSWORD
```

### 3. Installer Ollama

```bash
# Installation
curl -fsSL https://ollama.com/install.sh | sh

# Configuration pour Docker
sudo systemctl edit ollama
```

Ajouter :
```ini
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
```

```bash
# Redémarrer
sudo systemctl daemon-reload
sudo systemctl restart ollama

# Télécharger un modèle
ollama pull llama3.1:8b
```

### 4. Configurer le pare-feu

```bash
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 5678/tcp  # N8N
sudo ufw allow 8080/tcp  # NGINX Proxy
sudo ufw allow 3000/tcp  # Grafana
sudo ufw enable
```

### 5. Démarrer les services

```bash
docker-compose up -d
docker-compose ps
```

Services attendus "Up" :
- postgres, n8n, qdrant
- nginx, grafana, loki, promtail, prometheus

---

## Configuration post-installation

### Configurer N8N

1. Accéder à `http://VOTRE_IP:5678`
2. Créer le compte admin
3. **Settings** → **API** → **Create an API key**
4. Copier la clé et l'ajouter dans `.env` :
   ```bash
   N8N_API_KEY=la_clé_copiée
   ```

### Configurer le cron job

```bash
crontab -e
```

Ajouter :
```bash
0 */6 * * * cd /home/USER/docker-self-hosted-ia-n8n && docker exec n8n sh -c "cd /data && . /data/.env && sh /data/scripts/export-n8n-workflows-docker.sh" >> /tmp/n8n-export.log 2>&1
```

**Remplacer `/home/USER/` par le chemin réel** (utiliser `pwd` pour le trouver).

### Configurer Git

```bash
git config user.email "votre-email@example.com"
git config user.name "Votre Nom"

# Authentification SSH (recommandé)
ssh-keygen -t ed25519 -C "votre-email@example.com"
cat ~/.ssh/id_ed25519.pub
# Ajouter la clé sur GitHub : Settings → SSH Keys

ssh -T git@github.com  # Tester
```

---

## Sécurisation

### Changer les mots de passe par défaut

- **PostgreSQL** : Déjà configuré dans `.env`
- **Grafana** : Changer lors de la première connexion (`admin/admin`)

### Limiter l'accès aux ports

Modifier `docker-compose.yml` pour désactiver l'accès direct :

```yaml
n8n:
  ports:
    # - 5678:5678  # Commenter pour n'autoriser que via reverse proxy
```

### fail2ban pour SSH

```bash
sudo apt install fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

### Mises à jour automatiques

```bash
sudo apt install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

### SSL avec domaine (optionnel)

```bash
# Installer Certbot
sudo apt install -y nginx certbot python3-certbot-nginx

# Configurer le reverse proxy
sudo nano /etc/nginx/sites-available/n8n.votredomaine.com
```

Contenu :
```nginx
server {
    listen 80;
    server_name n8n.votredomaine.com;

    location / {
        proxy_pass http://localhost:5678;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

```bash
# Activer
sudo ln -s /etc/nginx/sites-available/n8n.votredomaine.com /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

# Obtenir le certificat SSL
sudo certbot --nginx -d n8n.votredomaine.com
```

---

## Monitoring et logs

### Grafana

Accéder à `http://VOTRE_IP:3000`
- Login : `admin`
- Password : `admin` (changez-le)

**Voir les logs N8N :**
```logql
{job="nginx", service="n8n"} | json
```

### Logs Docker

```bash
# Logs N8N
docker logs -f n8n

# Logs NGINX
docker exec nginx tail -f /var/log/nginx/n8n-access.log

# Tous les conteneurs
docker-compose logs -f

# Export automatique
tail -f /tmp/n8n-export.log
```

---

## Sauvegarde automatique

### Script de sauvegarde

Créer `/root/backup-n8n.sh` :

```bash
#!/bin/bash
BACKUP_DIR="/backup"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# PostgreSQL
docker exec postgres pg_dump -U n8n_user n8n | gzip > "$BACKUP_DIR/n8n_postgres_$DATE.sql.gz"

# Volumes
docker run --rm -v n8n_storage:/data -v $BACKUP_DIR:/backup alpine tar czf /backup/n8n_storage_$DATE.tar.gz /data
docker run --rm -v qdrant_storage:/data -v $BACKUP_DIR:/backup alpine tar czf /backup/qdrant_storage_$DATE.tar.gz /data

# Nettoyer > 7 jours
find $BACKUP_DIR -name "*.gz" -mtime +7 -delete

echo "Backup completed: $DATE"
```

```bash
chmod +x /root/backup-n8n.sh

# Ajouter au cron (quotidien à 3h)
sudo crontab -e
# Ajouter :
0 3 * * * /root/backup-n8n.sh >> /var/log/n8n-backup.log 2>&1
```

---

## Troubleshooting

### Services ne démarrent pas

```bash
docker-compose logs
docker-compose down
docker-compose up -d
```

### Ollama non accessible

```bash
# Vérifier l'écoute
sudo lsof -iTCP:11434 | grep LISTEN

# Reconfigurer si 127.0.0.1
sudo systemctl edit ollama
# Ajouter : Environment="OLLAMA_HOST=0.0.0.0:11434"
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

### Permissions Git

```bash
docker exec n8n git config --global --add safe.directory /data
docker exec n8n git config --global user.email "n8n@automated.local"
docker exec n8n git config --global user.name "N8N Export"
```

### Espace disque plein

```bash
df -h
docker system prune -a
sudo sh -c 'truncate -s 0 /var/lib/docker/containers/*/*-json.log'
```

### RAM insuffisante

```
ERROR: RAM insuffisante: 8GB détectés
```

**Solution** : Upgrader vers un serveur avec 16GB+ de RAM

---

## Checklist de déploiement

- [ ] Serveur avec spécifications minimales (16GB RAM)
- [ ] Docker et Docker Compose installés
- [ ] Repository cloné
- [ ] `.env` configuré avec clés sécurisées
- [ ] Ollama installé et configuré
- [ ] Pare-feu configuré
- [ ] Services démarrés (`docker-compose up -d`)
- [ ] N8N accessible, compte admin créé
- [ ] Clé API N8N générée et ajoutée dans `.env`
- [ ] Cron job configuré pour l'export automatique
- [ ] Historisation des workflows activée (`ENABLE_HISTORY=true`)
- [ ] Git configuré
- [ ] Grafana accessible, mot de passe changé
- [ ] Script de sauvegarde configuré

---

## Documentation associée

- **Configuration Ollama** : [OLLAMA_GUIDE.md](./OLLAMA_GUIDE.md)
- **Proxy NGINX** : [NGINX_PROXY_SETUP.md](./NGINX_PROXY_SETUP.md)
- **Export workflows** : [N8N_WORKFLOW_EXPORT.md](./N8N_WORKFLOW_EXPORT.md)

---

*Dernière mise à jour : 7 janvier 2026*
