# 🚀 Démarrage rapide - Déploiement serveur

Guide ultra-rapide pour déployer toute la stack sur un serveur distant (Hostinger, VPS, etc.).

---

## ⚡ Installation en une commande

```bash
# Cloner le projet
git clone git@github.com:maximilienborneext/docker-self-hosted-ia-n8n.git
cd docker-self-hosted-ia-n8n

# Lancer le script d'installation automatique
./scripts/deploy-to-server.sh
```

**Le script va automatiquement :**
- ✅ Installer Docker + Docker Compose
- ✅ Installer et configurer Ollama
- ✅ Générer les clés de sécurité
- ✅ Configurer Git
- ✅ Démarrer tous les services (N8N, PostgreSQL, Qdrant, Grafana, Loki, Prometheus, NGINX)
- ✅ Configurer l'export automatique des workflows
- ✅ Afficher les URLs d'accès

---

## 📋 Prérequis serveur

| Composant | Minimum | Recommandé |
|-----------|---------|------------|
| **CPU** | 4 cores | 8 cores |
| **RAM** | 16GB ⚠️ | 24GB |
| **Stockage** | 100GB | 200GB+ |
| **OS** | Ubuntu 22.04 LTS | Ubuntu 22.04 LTS |

**⚠️ IMPORTANT** : **16GB de RAM minimum** (Ollama est obligatoire)

### Plans Hostinger recommandés

- ❌ **VPS 1-3** : Insuffisant (2-8GB RAM)
- ✅ **VPS 4** : Minimum (4 vCPU, 16GB RAM, 200GB SSD)
- ✅ **VPS 6** : Recommandé (6 vCPU, 24GB RAM, 300GB SSD)

---

## 🔧 Configuration post-installation

### 1. Configurer N8N (2 minutes)

```
http://VOTRE_IP:5678
```

1. Créer un compte admin
2. Settings → API → Create an API key
3. Copier la clé API
4. L'ajouter dans `.env` :
   ```bash
   nano .env
   # Modifier :
   N8N_API_KEY=votre_clé_api_ici
   ```

### 2. Accéder à Grafana (1 minute)

```
http://VOTRE_IP:3000
```

- Login : `admin`
- Password : `admin` (changez-le)

**Voir les logs N8N :**
```logql
{job="nginx", service="n8n"} | json
```

### 3. Configurer les services externes (optionnel)

Éditer `.env` avec vos propres credentials :

```bash
nano .env
```

Variables à modifier :
- `RAG_UPSTREAM_URL` : URL de votre service RAG
- `BRAINTRUST_API_KEY` : Clé Braintrust
- `SUPABASE_URL` + `SUPABASE_API_KEY` : SupaBase
- `GOOGLE_ANALYTICS_*` : Google Analytics

---

## 🎯 Services déployés

| Service | URL | Credentials |
|---------|-----|-------------|
| **N8N** | `http://VOTRE_IP:5678` | À créer |
| **Grafana** | `http://VOTRE_IP:3000` | `admin/admin` |
| **NGINX Proxy** | `http://VOTRE_IP:8080` | - |
| **Prometheus** | `http://VOTRE_IP:9090` | - |
| **Ollama** | `http://VOTRE_IP:11434` | - |

---

## 🔒 Sécurisation recommandée

### Pare-feu

```bash
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 5678/tcp  # N8N
sudo ufw allow 3000/tcp  # Grafana
sudo ufw allow 8080/tcp  # Proxy
sudo ufw enable
```

### SSL avec domaine (optionnel)

Si vous avez un domaine :

```bash
# Installer Certbot
sudo apt install -y certbot python3-certbot-nginx

# Obtenir un certificat SSL
sudo certbot --nginx -d n8n.votredomaine.com
```

---

## 📊 Vérifications

### Tous les services tournent ?

```bash
docker-compose ps
```

Devrait afficher 8 services "Up" :
- postgres
- n8n
- qdrant
- nginx
- grafana
- loki
- promtail
- prometheus

### Ollama fonctionne ?

```bash
# Depuis le serveur
curl http://localhost:11434/api/tags

# Depuis N8N (via proxy)
curl http://localhost:8080/api/ollama/api/tags
```

### Export automatique configuré ?

```bash
# Voir le cron job
crontab -l

# Tester manuellement
docker exec n8n sh -c "cd /data && . /data/.env && sh /data/scripts/export-n8n-workflows-docker.sh"

# Voir les logs
tail -f /tmp/n8n-export.log
```

---

## 🐛 Problèmes courants

### Erreur : RAM insuffisante

```
ERROR: RAM insuffisante: 8GB détectés
Ollama nécessite au moins 16GB de RAM
```

**Solution** : Upgrader votre serveur vers un plan avec 16GB+ de RAM

---

### Services ne démarrent pas

```bash
# Voir les logs
docker-compose logs

# Redémarrer
docker-compose down
docker-compose up -d
```

---

### Ollama non accessible

```bash
# Vérifier qu'Ollama écoute
sudo lsof -iTCP:11434 | grep LISTEN

# Redémarrer Ollama
sudo systemctl restart ollama

# Voir les logs
sudo journalctl -u ollama -f
```

---

## 📚 Documentation complète

- **Guide complet** : [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)
- **Export automatique** : [N8N_WORKFLOW_EXPORT.md](./N8N_WORKFLOW_EXPORT.md)
- **Configuration Ollama** : [OLLAMA_SETUP.md](./OLLAMA_SETUP.md)
- **Proxy NGINX** : [NGINX_PROXY_SETUP.md](./NGINX_PROXY_SETUP.md)

---

## ✅ Résumé

**Ce qui est automatiquement configuré :**
- ✅ Docker + Docker Compose
- ✅ Ollama (avec modèle llama3.1:8b)
- ✅ N8N + PostgreSQL + Qdrant
- ✅ Grafana + Loki + Promtail + Prometheus
- ✅ NGINX Proxy avec logging complet
- ✅ Export automatique des workflows (toutes les 6h)
- ✅ Commits Git automatiques

**Ce que vous devez faire manuellement :**
- 🔧 Créer le compte admin N8N
- 🔧 Générer la clé API N8N
- 🔧 Configurer les services externes (optionnel)
- 🔒 Configurer le pare-feu
- 🔒 Configurer SSL (si domaine)

**Temps total estimé :** 15-20 minutes (installation automatique + configuration manuelle)

---

**Dernière mise à jour :** 7 janvier 2026
