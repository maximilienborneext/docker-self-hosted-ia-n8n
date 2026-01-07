# Guide de déploiement sur serveur distant (Hostinger, VPS, etc.)

Ce guide explique comment déployer l'ensemble de la stack sur un serveur distant.

## 📋 Prérequis serveur

### Spécifications minimales recommandées

- **CPU** : 4 cores minimum (8 cores recommandé)
- **RAM** : **16GB minimum** (Ollama requis)
- **Stockage** : 100GB minimum (200GB+ recommandé - modèles Ollama volumineux)
- **OS** : Ubuntu 22.04 LTS ou Debian 11+

**⚠️ IMPORTANT** : Ollama est **obligatoire** et nécessite au moins 8GB de RAM pour fonctionner correctement. Prévoyez 16GB total pour le serveur.

### Logiciels requis

```bash
# Docker & Docker Compose
sudo apt update
sudo apt install -y docker.io docker-compose git jq

# Démarrer Docker
sudo systemctl enable docker
sudo systemctl start docker

# Ajouter votre user au groupe docker (évite sudo)
sudo usermod -aG docker $USER
# Puis se déconnecter/reconnecter
```

---

## 🚀 Déploiement étape par étape

### 1. Cloner le repository

```bash
cd ~
git clone git@github.com:maximilienborneext/docker-self-hosted-ia-n8n.git
cd docker-self-hosted-ia-n8n
```

### 2. Copier et configurer les variables d'environnement

```bash
cp .env.example .env
nano .env
```

**Variables à configurer :**

```bash
# PostgreSQL (générer des mots de passe forts)
POSTGRES_USER=n8n_user
POSTGRES_PASSWORD=CHANGEZ_MOI_AVEC_UN_MOT_DE_PASSE_FORT
POSTGRES_DB=n8n

# N8N Encryption (générer une clé aléatoire)
N8N_ENCRYPTION_KEY=$(openssl rand -hex 32)
N8N_USER_MANAGEMENT_JWT_SECRET=$(openssl rand -hex 32)

# N8N API Key (à générer après le premier démarrage)
N8N_API_KEY=your-n8n-api-key-here

# Services externes
RAG_UPSTREAM_URL=https://votre-ngrok-ou-service-rag.com
BRAINTRUST_API_KEY=sk-votre-braintrust-api-key
SUPABASE_URL=https://votre-projet.supabase.co
SUPABASE_API_KEY=votre-supabase-api-key

# Google Analytics
GOOGLE_ANALYTICS_MEASUREMENT_ID=G-XXXXXXXXX
GOOGLE_ANALYTICS_API_SECRET=votre-api-secret
GOOGLE_ANALYTICS_TOKEN=votre-oauth2-token
```

**Générer des clés sécurisées :**
```bash
# Générer N8N_ENCRYPTION_KEY
openssl rand -hex 32

# Générer N8N_USER_MANAGEMENT_JWT_SECRET
openssl rand -hex 32

# Générer un mot de passe PostgreSQL fort
openssl rand -base64 32
```

---

### 3. Installer et configurer Ollama (OBLIGATOIRE)

#### Méthode recommandée : Ollama sur le serveur distant

**Installation :**
```bash
curl -fsSL https://ollama.com/install.sh | sh
```

**Configuration pour Docker :**
```bash
# Éditer le fichier service
sudo systemctl edit ollama

# Ajouter :
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"

# Redémarrer
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

**Modifier docker-compose.yml :**
```yaml
x-n8n: &service-n8n
  environment:
    # Changer de host.docker.internal à l'IP du serveur
    - OLLAMA_HOST=http://172.17.0.1:11434  # Gateway Docker
    # OU
    - OLLAMA_HOST=http://IP_DU_SERVEUR:11434
```

#### Méthode alternative : Ollama dans Docker

**Ajouter au docker-compose.yml :**
```yaml
services:
  ollama:
    image: ollama/ollama:latest
    container_name: ollama
    networks: ['demo']
    ports:
      - "11434:11434"
    volumes:
      - ollama_data:/root/.ollama
    restart: unless-stopped

volumes:
  ollama_data:
```

**Puis modifier la config N8N :**
```yaml
x-n8n: &service-n8n
  environment:
    - OLLAMA_HOST=http://ollama:11434
```

---

### 4. Configuration du pare-feu

```bash
# UFW (Ubuntu Firewall)
sudo ufw allow 22/tcp      # SSH
sudo ufw allow 80/tcp      # HTTP
sudo ufw allow 443/tcp     # HTTPS
sudo ufw allow 5678/tcp    # N8N (optionnel, peut rester interne)
sudo ufw allow 8080/tcp    # NGINX Proxy
sudo ufw allow 3000/tcp    # Grafana
sudo ufw enable
```

---

### 5. Démarrer les services

```bash
# Démarrer tous les conteneurs
docker-compose up -d

# Vérifier que tout tourne
docker-compose ps

# Voir les logs
docker-compose logs -f
```

**Services qui devraient être "Up" :**
- postgres
- n8n
- qdrant
- nginx
- grafana
- loki
- promtail
- prometheus

---

### 6. Configuration initiale de N8N

**Accéder à N8N :**
```
http://IP_DU_SERVEUR:5678
```

**Créer le compte admin :**
1. Remplir email/mot de passe
2. Configurer les préférences

**Créer une clé API N8N :**
1. Settings → API
2. Create an API key
3. Copier la clé
4. L'ajouter dans `.env` :
   ```bash
   nano .env
   # Ajouter/modifier :
   N8N_API_KEY=la_clé_copiée
   ```

---

### 7. Configurer le cron job pour l'export automatique

```bash
# Éditer le crontab
crontab -e

# Ajouter cette ligne :
0 */6 * * * cd /home/votre_user/docker-self-hosted-ia-n8n && docker exec n8n sh -c "cd /data && . /data/.env && sh /data/scripts/export-n8n-workflows-docker.sh" >> /tmp/n8n-export.log 2>&1
```

**⚠️ Important :** Remplacer `/home/votre_user/docker-self-hosted-ia-n8n` par le chemin absolu réel.

**Trouver le chemin absolu :**
```bash
cd ~/docker-self-hosted-ia-n8n
pwd
# Copier le résultat dans le cron
```

---

### 8. Configurer Git pour les commits automatiques

```bash
# Configurer l'identité Git
git config user.email "votre-email@example.com"
git config user.name "Votre Nom"

# Configurer l'authentification SSH (recommandé)
ssh-keygen -t ed25519 -C "votre-email@example.com"
cat ~/.ssh/id_ed25519.pub
# Copier la clé et l'ajouter sur GitHub : Settings → SSH Keys

# Tester la connexion
ssh -T git@github.com
```

**Optionnel : Activer le push automatique vers GitHub**

Éditer le script d'export :
```bash
nano scripts/export-n8n-workflows-docker.sh

# Décommenter la ligne 185 :
# git push origin main
# Devient :
git push origin main
```

---

### 9. Configuration DNS et domaine (optionnel mais recommandé)

#### Avec domaine personnalisé

**Pointer le domaine vers votre serveur :**
```
A record : n8n.votredomaine.com → IP_DU_SERVEUR
A record : grafana.votredomaine.com → IP_DU_SERVEUR
A record : proxy.votredomaine.com → IP_DU_SERVEUR
```

**Installer Nginx Reverse Proxy avec SSL (Certbot) :**
```bash
# Installer Nginx et Certbot
sudo apt install -y nginx certbot python3-certbot-nginx

# Créer la config pour N8N
sudo nano /etc/nginx/sites-available/n8n.votredomaine.com
```

**Contenu :**
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
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

**Activer et configurer SSL :**
```bash
# Créer le lien symbolique
sudo ln -s /etc/nginx/sites-available/n8n.votredomaine.com /etc/nginx/sites-enabled/

# Tester la config
sudo nginx -t

# Recharger Nginx
sudo systemctl reload nginx

# Obtenir le certificat SSL
sudo certbot --nginx -d n8n.votredomaine.com
```

**Répéter pour Grafana et le Proxy NGINX.**

---

### 10. Configuration avancée : NGINX Proxy avec domaines

**Modifier nginx/proxy.conf.template pour utiliser des domaines :**

```nginx
server {
    listen 80;
    server_name proxy.votredomaine.com;

    # Tout le reste de la config reste identique
    location /api/rag/ {
        # ...
    }

    # etc.
}
```

---

## 🔒 Sécurisation

### 1. Changer les mots de passe par défaut

```bash
# PostgreSQL
# Déjà fait dans .env avec un mot de passe fort

# Grafana (par défaut admin/admin)
# Lors de la première connexion à http://IP:3000
```

### 2. Limiter l'accès aux services

**Modifier docker-compose.yml pour ne pas exposer tous les ports :**

```yaml
# Exemple : N8N uniquement accessible via nginx reverse proxy
n8n:
  ports:
    # - 5678:5678  # Commenter pour désactiver l'accès direct
  # Garder uniquement l'accès via nginx reverse proxy
```

### 3. Configurer fail2ban pour SSH

```bash
sudo apt install fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban
```

### 4. Activer les mises à jour automatiques

```bash
sudo apt install unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

---

## 📊 Monitoring

### Accéder à Grafana

```
http://IP_DU_SERVEUR:3000
```

**Login par défaut :**
- User: `admin`
- Password: `admin` (changez-le lors de la première connexion)

### Vérifier les logs

```bash
# Logs NGINX Proxy
docker exec nginx tail -f /var/log/nginx/n8n-access.log

# Logs N8N
docker logs -f n8n

# Logs export automatique
tail -f /tmp/n8n-export.log

# Tous les conteneurs
docker-compose logs -f
```

---

## 🔄 Sauvegarde

### Script de sauvegarde automatique

**Créer `/root/backup-n8n.sh` :**

```bash
#!/bin/bash

BACKUP_DIR="/backup"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Sauvegarde PostgreSQL
docker exec postgres pg_dump -U n8n_user n8n | gzip > "$BACKUP_DIR/n8n_postgres_$DATE.sql.gz"

# Sauvegarde volumes
docker run --rm -v n8n_storage:/data -v $BACKUP_DIR:/backup alpine tar czf /backup/n8n_storage_$DATE.tar.gz /data

# Sauvegarde Qdrant
docker run --rm -v qdrant_storage:/data -v $BACKUP_DIR:/backup alpine tar czf /backup/qdrant_storage_$DATE.tar.gz /data

# Nettoyer les sauvegardes > 7 jours
find $BACKUP_DIR -name "*.gz" -mtime +7 -delete

echo "Backup completed: $DATE"
```

**Rendre exécutable et ajouter au cron :**

```bash
chmod +x /root/backup-n8n.sh

# Ajouter au crontab (sauvegarde quotidienne à 3h)
sudo crontab -e

# Ajouter :
0 3 * * * /root/backup-n8n.sh >> /var/log/n8n-backup.log 2>&1
```

---

## 🐛 Dépannage

### Les conteneurs ne démarrent pas

```bash
# Voir les erreurs
docker-compose logs

# Redémarrer tous les services
docker-compose down
docker-compose up -d
```

### Ollama non accessible depuis N8N

```bash
# Vérifier qu'Ollama écoute sur la bonne interface
sudo lsof -iTCP:11434 | grep LISTEN

# Devrait montrer : *:11434 ou 0.0.0.0:11434

# Si 127.0.0.1:11434, reconfigurer :
sudo systemctl edit ollama
# Ajouter :
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"

sudo systemctl daemon-reload
sudo systemctl restart ollama
```

### Problèmes de permissions Git

```bash
# Dans le conteneur N8N
docker exec n8n git config --global --add safe.directory /data
docker exec n8n git config --global user.email "n8n@automated.local"
docker exec n8n git config --global user.name "N8N Export"
```

### Espace disque plein

```bash
# Vérifier l'espace
df -h

# Nettoyer les images Docker inutilisées
docker system prune -a

# Nettoyer les logs Docker
sudo sh -c 'truncate -s 0 /var/lib/docker/containers/*/*-json.log'
```

---

## ✅ Checklist de déploiement

- [ ] Serveur provisionné avec spécifications minimales
- [ ] Docker et Docker Compose installés
- [ ] Repository cloné
- [ ] `.env` configuré avec toutes les variables
- [ ] Clés de sécurité générées (encryption, JWT, passwords)
- [ ] Ollama installé et configuré (si utilisé)
- [ ] Pare-feu configuré
- [ ] `docker-compose up -d` exécuté avec succès
- [ ] N8N accessible et compte admin créé
- [ ] Clé API N8N générée et ajoutée dans `.env`
- [ ] Cron job configuré pour l'export automatique
- [ ] Git configuré pour les commits automatiques
- [ ] Grafana accessible et mot de passe changé
- [ ] Domaines configurés (optionnel)
- [ ] SSL activé avec Certbot (optionnel)
- [ ] Script de sauvegarde configuré
- [ ] Tous les services testés et fonctionnels

---

## 📚 Ressources

- **Documentation N8N :** https://docs.n8n.io/
- **Documentation Docker :** https://docs.docker.com/
- **Documentation Ollama :** https://github.com/ollama/ollama
- **Documentation Grafana :** https://grafana.com/docs/

---

## 🚨 Important pour Hostinger spécifiquement

### Limitations connues de Hostinger VPS

1. **RAM limitée** : Les plans de base ont souvent 2-4GB de RAM
   - ⚠️ **Ollama nécessite au moins 8GB de RAM pour fonctionner**
   - **Solution obligatoire** : Upgrader vers un plan avec minimum 16GB de RAM

2. **Bande passante** : Vérifier les limites mensuelles
   - Les exports fréquents + logs peuvent consommer de la bande passante

3. **Accès root** : Vérifier que vous avez bien un accès root complet

### Configuration spécifique Hostinger

**Plans Hostinger recommandés :**
- **Minimum** : VPS 4 (4 vCPU, 16GB RAM, 200GB SSD)
- **Recommandé** : VPS 6 (6 vCPU, 24GB RAM, 300GB SSD)

**⚠️ Les plans VPS 1-3 (2-8GB RAM) ne sont PAS suffisants pour Ollama**

**Après connexion SSH à votre VPS Hostinger :**

```bash
# Vérifier les ressources
free -h  # RAM disponible - doit afficher au moins 16GB
df -h    # Espace disque - minimum 100GB libre
lscpu    # CPU info - minimum 4 cores
```

---

**Dernière mise à jour :** 7 janvier 2026
