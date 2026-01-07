# Guide NGINX Proxy

Le proxy NGINX centralise tous les appels vers les services externes et locaux, offrant une observabilité complète via Grafana/Loki.

## Table des matières

- [Vue d'ensemble](#vue-densemble)
- [Services proxifiés](#services-proxifiés)
- [Configuration](#configuration)
- [Utilisation](#utilisation)
- [Observabilité](#observabilité)
- [Troubleshooting](#troubleshooting)

---

## Vue d'ensemble

### Avantages

- **Interface unique** : Port 8080 pour tous les services
- **Observabilité** : Tous les appels loggés en JSON dans Grafana
- **Sécurité** : Credentials injectés automatiquement
- **Simplicité** : Plus besoin de gérer les URLs/tokens dans chaque service

### Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Application (N8N, etc.)                  │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
              ┌──────────────────────┐
              │   NGINX Proxy        │
              │   (localhost:8080)   │
              └──────────┬───────────┘
                         │
         ┌───────────────┼───────────────┐
         ▼               ▼               ▼
    Services         Services        Services
    Externes         Locaux          Analytics
         │               │               │
         └───────────────┼───────────────┘
                         ▼
                   Loki → Grafana
```

---

## Services proxifiés

### Services externes

| Service | Route | Description |
|---------|-------|-------------|
| RAG | `/api/rag/` | Service RAG via webhook ngrok |
| Braintrust | `/api/braintrust/` | API de logging et monitoring |
| SupaBase | `/api/supabase/` | Base de données |

### Google Analytics

| Route | Description |
|-------|-------------|
| `/api/ga/mp/collect` | Envoi d'événements GA4 |
| `/api/ga/mp/debug` | Validation des événements |
| `/api/ga/data/` | Récupération de données |
| `/api/ga/admin/` | Gestion des propriétés |

### Services locaux

| Service | Route | Backend |
|---------|-------|---------|
| Ollama | `/api/ollama/` | `host.docker.internal:11434` |
| N8N | `/api/n8n/` | `n8n:5678` |
| Qdrant | `/api/qdrant/` | `qdrant:6333` |
| Loki | `/api/loki/push` | `loki:3100/loki/api/v1/push` |
| Loki (autres) | `/api/loki/*` | `loki:3100/*` |

### Utilitaires

| Route | Description |
|-------|-------------|
| `/health` | Health check du proxy |
| `/nginx-status` | Statistiques NGINX |

---

## Configuration

### Structure des fichiers

```
nginx/
├── nginx.conf              # Configuration principale
├── api.conf                # Format de logs JSON
├── proxy.conf.template     # Template des routes
├── proxy.conf              # Généré au démarrage
└── docker-entrypoint.sh    # Script d'initialisation
```

### Variables d'environnement

Dans `.env` :

```bash
# Service RAG
RAG_UPSTREAM_URL=https://votre-url.ngrok-free.dev

# Braintrust API
BRAINTRUST_API_KEY=sk-votre-clé

# SupaBase
SUPABASE_URL=https://votre-projet.supabase.co
SUPABASE_API_KEY=votre-clé

# Google Analytics
GOOGLE_ANALYTICS_MEASUREMENT_ID=G-XXXXXXXXX
GOOGLE_ANALYTICS_API_SECRET=votre-secret
```

### Ajouter un nouveau service

1. Ajouter les variables dans `.env` et `.env.example`
2. Ajouter au `docker-compose.yml` (section nginx environment)
3. Créer la route dans `nginx/proxy.conf.template`
4. Ajouter le job Promtail dans `loki/promtail-config.yml`
5. Mettre à jour `nginx/docker-entrypoint.sh` pour `envsubst`
6. Redémarrer : `docker-compose up -d nginx`

---

## Utilisation

### Google Analytics - Envoyer un événement

```bash
curl -X POST http://localhost:8080/api/ga/mp/collect \
  -H "Content-Type: application/json" \
  -d '{
    "client_id": "123456.7890",
    "events": [{
      "name": "page_view",
      "params": {"page_title": "Home"}
    }]
  }'
```

Les credentials sont injectés automatiquement par le proxy.

### SupaBase - Récupérer des données

```bash
curl http://localhost:8080/api/supabase/Product
```

### Braintrust - Logger un événement

```bash
curl -X POST http://localhost:8080/api/braintrust/project_logs/PROJECT_ID/insert \
  -H "Content-Type: application/json" \
  -d '{
    "events": [{
      "input": "...",
      "output": "...",
      "metadata": {"ragScore": 0.95}
    }]
  }'
```

### RAG - Poser une question

```bash
curl -X POST http://localhost:8080/api/rag/webhook-test/rag-ask \
  -H "Content-Type: application/json" \
  -d '{"question": "Ma question"}'
```

### Ollama

Voir [OLLAMA_GUIDE.md](./OLLAMA_GUIDE.md) pour les exemples complets.

```bash
curl http://localhost:8080/api/ollama/api/tags
```

---

## Observabilité

### Format des logs

```json
{
  "time": "2026-01-06T13:52:37+00:00",
  "method": "POST",
  "request_uri": "/api/ga/mp/collect",
  "status": 204,
  "request_time": 0.066,
  "request_body": "{...}"
}
```

### Accéder à Grafana

1. Ouvrir `http://localhost:3000`
2. Login : `admin` / `admin`
3. Aller dans **Explore** → Sélectionner **Loki**

### Requêtes LogQL

```logql
# Tous les logs NGINX
{job="nginx"}

# Filtrer par service
{job="nginx", service="rag"}
{job="nginx", service="braintrust"}
{job="nginx", service="ollama"}

# Voir les POST
{job="nginx", method="POST"} | json

# Erreurs (4xx, 5xx)
{job="nginx"} | json | status >= 400

# Requêtes lentes (> 1 seconde)
{job="nginx"} | json | request_time > 1

# Rechercher dans le body
{job="nginx"} | json | request_body =~ "client_id"

# Compter par service (5 min)
sum by (service) (count_over_time({job="nginx"}[5m]))
```

### Labels Promtail

- `job="nginx"` : Tous les logs NGINX
- `service="<nom>"` : Service appelé (rag, braintrust, ollama, etc.)
- `method="<method>"` : Méthode HTTP (GET, POST)
- `status="<code>"` : Code HTTP (200, 204, 400, etc.)

---

## Gestion des services

```bash
# Démarrer
docker compose up -d

# Redémarrer NGINX
docker restart nginx

# Logs en temps réel
docker logs -f nginx

# Tester la configuration
docker exec nginx nginx -t

# Voir la configuration générée
docker exec nginx cat /etc/nginx/conf.d/proxy.conf
```

---

## Troubleshooting

### Le proxy ne démarre pas

```bash
# Vérifier les logs
docker logs nginx

# Vérifier les variables d'environnement
docker exec nginx env | grep -E "(RAG|BRAINTRUST|SUPABASE|GOOGLE)"

# Tester la configuration
docker exec nginx nginx -t
```

### Erreur 500 sur un endpoint

```bash
# Logs d'erreur
docker exec nginx tail -50 /var/log/nginx/error.log

# Logs spécifiques
docker exec nginx tail -20 /var/log/nginx/rag-error.log

# Vérifier l'URL backend
docker exec nginx cat /etc/nginx/conf.d/proxy.conf | grep -A 10 "rag_backend"
```

### Les logs n'apparaissent pas dans Grafana

```bash
# Vérifier Promtail
docker logs promtail

# Vérifier les fichiers de logs
docker exec nginx ls -lh /var/log/nginx/

# Tester une requête
curl http://localhost:8080/health

# Vérifier dans Grafana
{job="nginx"}
```

### Changer l'URL d'un service

1. Modifier `.env`
2. Recréer le conteneur : `docker compose up -d nginx`
3. Vérifier : `docker exec nginx cat /etc/nginx/conf.d/proxy.conf | grep URL`

### Erreur 413 (Request Entity Too Large)

Modifier `nginx/proxy.conf.template` :

```nginx
client_max_body_size 50m;  # Au lieu de 10m
```

Redémarrer : `docker restart nginx`

---

## Sécurité

### Données sensibles dans les logs

Le body des requêtes peut contenir des données sensibles.

**Recommandations :**
- Configurer une rétention courte dans Loki
- Limiter l'accès à Grafana
- Nettoyer régulièrement les anciens logs

### Rotation des credentials

1. Mettre à jour `.env`
2. Recréer NGINX : `docker compose up -d nginx`

---

## Documentation associée

- **Configuration Ollama** : [OLLAMA_GUIDE.md](./OLLAMA_GUIDE.md)
- **Export workflows** : [N8N_WORKFLOW_EXPORT.md](./N8N_WORKFLOW_EXPORT.md)
- **Déploiement serveur** : [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)

---

*Dernière mise à jour : 7 janvier 2026*
