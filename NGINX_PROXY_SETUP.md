# NGINX Proxy - Documentation

Ce document explique la configuration du proxy NGINX qui sert d'interface unique pour tous les services externes utilisés par l'application.

## Table des matières

- [Vue d'ensemble](#vue-densemble)
- [Architecture](#architecture)
- [Services proxifiés](#services-proxifiés)
- [Configuration](#configuration)
- [Observabilité](#observabilité)
- [Utilisation](#utilisation)
- [Troubleshooting](#troubleshooting)

---

## Vue d'ensemble

Le proxy NGINX centralise tous les appels vers les services externes et locaux, offrant :

- **Interface unique** : Un seul point d'entrée sur le port 8080
- **Observabilité complète** : Tous les appels sont loggés en JSON et envoyés à Loki/Grafana
- **Sécurité** : Gestion centralisée des credentials et tokens
- **Simplicité** : Plus besoin de gérer les URLs et tokens dans chaque service

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Application (n8n, etc.)                   │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ↓
              ┌──────────────────────┐
              │   NGINX Proxy        │
              │   (localhost:8080)   │
              └──────────┬───────────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
         ↓               ↓               ↓
    Services         Services        Services
    Externes         Locaux          Analytics
    (RAG,            (N8N,           (Google
    Braintrust,      Qdrant)         Analytics)
    SupaBase)
         │               │               │
         ↓               ↓               ↓
    ┌─────────────────────────────────────┐
    │         Loki (Logs centralisés)      │
    └─────────────────────────────────────┘
                     ↓
            ┌─────────────────┐
            │     Grafana      │
            │ (Visualisation)  │
            └─────────────────┘
```

---

## Services proxifiés

### Services Externes

| Service | Route | Backend | Description |
|---------|-------|---------|-------------|
| **RAG** | `/api/rag/` | `https://nonconsorting-cathy-royally.ngrok-free.dev` | Service RAG via webhook ngrok |
| **Braintrust** | `/api/braintrust/` | `https://api.braintrust.dev/v1/` | API de logging et monitoring |
| **SupaBase** | `/api/supabase/` | `https://sevlkcjutnlrnzifreox.supabase.co/rest/v1/` | Base de données |

### Google Analytics

| Service | Route | Backend | Description |
|---------|-------|---------|-------------|
| **Measurement Protocol** | `/api/ga/mp/collect` | `https://www.google-analytics.com/mp/collect` | Envoi d'événements GA4 |
| **Debug Mode** | `/api/ga/mp/debug` | `https://www.google-analytics.com/debug/mp/collect` | Validation des événements |
| **Data API** | `/api/ga/data/` | `https://analyticsdata.googleapis.com` | Récupération de données |
| **Admin API** | `/api/ga/admin/` | `https://analyticsadmin.googleapis.com` | Gestion des propriétés GA |

### Services Locaux

| Service | Route | Backend | Description |
|---------|-------|---------|-------------|
| **Ollama** | `/api/ollama/` | `http://host.docker.internal:11434` | LLM local (Llama, Mistral, etc.) |
| **N8N** | `/api/n8n/` | `http://n8n:5678` | Automation workflows |
| **Qdrant** | `/api/qdrant/` | `http://qdrant:6333` | Base de données vectorielle |

### Utilitaires

| Route | Description |
|-------|-------------|
| `/health` | Health check du proxy NGINX |
| `/nginx-status` | Statistiques NGINX (accès restreint au réseau Docker) |

---

## Configuration

### Fichiers de configuration

```
nginx/
├── nginx.conf              # Configuration principale NGINX
├── api.conf                # Format de logs JSON
├── proxy.conf.template     # Template des routes proxy
├── proxy.conf              # Généré automatiquement au démarrage
└── docker-entrypoint.sh    # Script d'initialisation
```

### Variables d'environnement

Toutes les variables sont définies dans le fichier `.env` :

```bash
# Service RAG
RAG_UPSTREAM_URL=https://nonconsorting-cathy-royally.ngrok-free.dev

# Braintrust API
BRAINTRUST_API_KEY=sk-Q8fBY8L7i376cVN0A2X1H0WCZJyrSdLQXrxoQTOZZX9Yoe0f

# SupaBase
SUPABASE_URL=https://sevlkcjutnlrnzifreox.supabase.co
SUPABASE_API_KEY=sb_publishable_T1zKEEVa3fizfGR0MKDE3A_jj5gzYMB

# Google Analytics
GOOGLE_ANALYTICS_MEASUREMENT_ID=G-NJ8YGSFZ9N
GOOGLE_ANALYTICS_API_SECRET=VCFmlgdAQk2iftBfdtH-YQ
GOOGLE_ANALYTICS_TOKEN=your-google-oauth2-token  # Optionnel (Data/Admin APIs)
```

### Génération de la configuration

Au démarrage du conteneur NGINX :

1. Le script `docker-entrypoint.sh` est exécuté
2. Les variables d'environnement sont injectées dans `proxy.conf.template`
3. Le fichier `proxy.conf` est généré avec `envsubst`
4. NGINX démarre avec la configuration générée

---

## Observabilité

### Format des logs

Tous les appels sont loggés en JSON avec les champs suivants :

```json
{
  "time": "2026-01-06T13:52:37+00:00",
  "remote_addr": "172.67.68.102",
  "request_id": "3921873af14a9c8edddbec700d023704",
  "method": "POST",
  "host": "localhost",
  "request_uri": "/api/ga/mp/collect",
  "uri": "/api/ga/mp/collect",
  "args": "",
  "status": 204,
  "request_time": 0.066,
  "upstream_status": "204",
  "request_body": "{...}",
  "content_type": "application/json",
  "content_length": "174"
}
```

**Champs importants :**

- `request_uri` : URI complète de la requête (ex: `/api/ga/mp/collect`)
- `uri` : URI après rewrite (envoyée au backend)
- `request_body` : Corps de la requête (pour les POST)
- `request_time` : Temps de réponse en secondes
- `status` : Code HTTP de la réponse

### Stack d'observabilité

**Promtail** → Collecte les logs NGINX
**Loki** → Stocke les logs
**Grafana** → Visualise les logs

#### Accéder à Grafana

1. Ouvrez **http://localhost:3000**
2. Connectez-vous :
   - Username: `admin`
   - Password: `admin`
3. Allez dans **Explore** (icône boussole)
4. Sélectionnez **Loki** comme source de données

### Requêtes LogQL utiles

#### Voir tous les logs NGINX
```logql
{job="nginx"}
```

#### Filtrer par service
```logql
{job="nginx", service="rag"}
{job="nginx", service="braintrust"}
{job="nginx", service="supabase"}
{job="nginx", service="google_analytics_mp"}
```

#### Voir uniquement les POST
```logql
{job="nginx", method="POST"} | json
```

#### Voir les erreurs (4xx, 5xx)
```logql
{job="nginx"} | json | status >= 400
```

#### Rechercher dans le body des requêtes
```logql
{job="nginx"} | json | request_body =~ "client_id"
```

#### Requêtes lentes (> 1 seconde)
```logql
{job="nginx"} | json | request_time > 1
```

#### Afficher uniquement certains champs
```logql
{job="nginx"} | json | line_format "{{.request_uri}} - {{.status}} - {{.request_time}}s"
```

#### Compter les appels par service (sur 5 minutes)
```logql
sum by (service) (count_over_time({job="nginx"}[5m]))
```

---

## Utilisation

### Exemples d'appels

#### 1. Google Analytics - Envoyer un événement

**Production :**
```bash
curl -X POST http://localhost:8080/api/ga/mp/collect \
  -H "Content-Type: application/json" \
  -d '{
    "client_id": "123456.7890",
    "events": [{
      "name": "page_view",
      "params": {
        "page_title": "Home",
        "page_location": "https://example.com"
      }
    }]
  }'
```

**Debug (validation) :**
```bash
curl -X POST http://localhost:8080/api/ga/mp/debug \
  -H "Content-Type: application/json" \
  -d '{
    "client_id": "123456.7890",
    "events": [{
      "name": "test_event",
      "params": {
        "test_param": "value"
      }
    }]
  }'
```

**Notes :**
- Les credentials (`measurement_id` et `api_secret`) sont **automatiquement ajoutés** par le proxy
- Pas besoin de les inclure dans l'URL ou le body

#### 2. SupaBase - Récupérer des données

```bash
curl http://localhost:8080/api/supabase/Product
```

Équivalent à :
```bash
curl https://sevlkcjutnlrnzifreox.supabase.co/rest/v1/Product?apikey=sb_publishable_...
```

#### 3. Braintrust - Logger un événement

```bash
curl -X POST http://localhost:8080/api/braintrust/project_logs/0966c78f-481a-401a-a039-0b2e276446bd/insert \
  -H "Content-Type: application/json" \
  -d '{
    "events": [{
      "input": "...",
      "output": "...",
      "metadata": {
        "ragScore": 0.95
      }
    }]
  }'
```

**Note :** Le token d'authentification est automatiquement ajouté par le proxy.

#### 4. RAG - Poser une question

```bash
curl -X POST http://localhost:8080/api/rag/webhook-test/rag-ask \
  -H "Content-Type: application/json" \
  -d '{
    "question": "URL du launcher de production SFR"
  }'
```

---

## Gestion des services

### Démarrer les services

```bash
docker compose up -d
```

### Redémarrer uniquement NGINX

```bash
docker restart nginx
```

### Voir les logs NGINX en temps réel

```bash
docker logs -f nginx
```

### Tester la configuration NGINX

```bash
docker exec nginx nginx -t
```

### Voir la configuration générée

```bash
docker exec nginx cat /etc/nginx/conf.d/proxy.conf
```

---

## Troubleshooting

### Le proxy ne démarre pas

1. Vérifier les logs :
```bash
docker logs nginx
```

2. Vérifier que toutes les variables d'environnement sont définies :
```bash
docker exec nginx env | grep -E "(RAG|BRAINTRUST|SUPABASE|GOOGLE)"
```

3. Tester la configuration :
```bash
docker exec nginx nginx -t
```

### Erreur 500 sur un endpoint

1. Vérifier les logs d'erreur :
```bash
docker exec nginx tail -50 /var/log/nginx/error.log
```

2. Vérifier les logs spécifiques du service :
```bash
docker exec nginx tail -20 /var/log/nginx/rag-error.log
docker exec nginx tail -20 /var/log/nginx/ga-mp-error.log
```

3. Vérifier que l'URL du backend est correcte :
```bash
docker exec nginx cat /etc/nginx/conf.d/proxy.conf | grep -A 10 "rag_backend"
```

### Les logs n'apparaissent pas dans Grafana

1. Vérifier que Promtail fonctionne :
```bash
docker logs promtail
```

2. Vérifier que les logs NGINX sont bien écrits :
```bash
docker exec nginx ls -lh /var/log/nginx/
```

3. Vérifier la configuration Promtail :
```bash
docker exec promtail cat /etc/promtail/config.yml
```

4. Tester une requête dans Grafana Explore :
```logql
{job="nginx"}
```

### Changer l'URL d'un service externe

1. Modifier le fichier `.env` :
```bash
RAG_UPSTREAM_URL=https://nouvelle-url.ngrok.io
```

2. Recréer le conteneur NGINX pour recharger les variables :
```bash
docker compose up -d nginx
```

3. Vérifier que la nouvelle URL est prise en compte :
```bash
docker exec nginx cat /etc/nginx/conf.d/proxy.conf | grep RAG_UPSTREAM_URL
```

### Limite de taille du body dépassée

Si vous recevez une erreur `413 Request Entity Too Large` :

1. Augmenter la limite dans `nginx/proxy.conf.template` :
```nginx
client_max_body_size 50m;  # Au lieu de 10m
```

2. Redémarrer NGINX :
```bash
docker restart nginx
```

### Les credentials Google Analytics ne fonctionnent pas

1. Vérifier que les credentials sont correctement définis dans `.env` :
```bash
grep GOOGLE_ANALYTICS .env
```

2. Vérifier qu'ils sont injectés dans la configuration :
```bash
docker exec nginx cat /etc/nginx/conf.d/proxy.conf | grep -A 5 "ga_query"
```

3. Tester en mode debug :
```bash
curl -v -X POST http://localhost:8080/api/ga/mp/debug \
  -H "Content-Type: application/json" \
  -d '{"client_id":"test.123","events":[{"name":"test"}]}'
```

---

## Sécurité et bonnes pratiques

### Données sensibles dans les logs

⚠️ **Attention :** Le body des requêtes peut contenir des données sensibles (tokens, données utilisateur, etc.).

**Recommandations :**

1. **Configurer une rétention courte** des logs dans Loki
2. **Limiter l'accès** à Grafana avec authentification forte
3. **Nettoyer régulièrement** les anciens logs

### Rotation des credentials

Quand vous changez un token ou une clé API :

1. Mettre à jour le fichier `.env`
2. Recréer le conteneur NGINX :
```bash
docker compose up -d nginx
```

### Monitoring de performance

Surveiller ces métriques dans Grafana :

- **Temps de réponse moyen** par service
- **Taux d'erreur** (4xx, 5xx)
- **Nombre de requêtes** par service
- **Taille des requêtes** (content_length)

---

## Architecture technique

### Flux de traitement d'une requête

1. **Client** → Envoie une requête à `http://localhost:8080/api/ga/mp/collect`
2. **NGINX** →
   - Reçoit la requête
   - Lit le body (si POST)
   - Applique le `rewrite` (supprime `/api/ga/mp`)
   - Ajoute les credentials (measurement_id, api_secret)
   - Logue la requête en JSON
3. **Backend** → `https://www.google-analytics.com/mp/collect?measurement_id=...&api_secret=...`
4. **Réponse** → Retourne au client
5. **Promtail** → Lit le fichier de log NGINX
6. **Loki** → Stocke le log
7. **Grafana** → Permet de visualiser le log

### Isolation réseau

Tous les services communiquent via le réseau Docker `demo` :

```yaml
networks:
  demo:
```

Seul NGINX expose un port vers l'extérieur (8080).

---

## Annexes

### Structure des fichiers de logs

Chaque service a son propre fichier de log :

```
/var/log/nginx/
├── rag-access.log           # Logs du service RAG
├── rag-error.log
├── braintrust-access.log    # Logs Braintrust
├── braintrust-error.log
├── supabase-access.log      # Logs SupaBase
├── supabase-error.log
├── ga-mp-access.log         # Logs Google Analytics MP
├── ga-mp-error.log
├── ga-data-access.log       # Logs Google Analytics Data API
├── ga-data-error.log
├── ga-admin-access.log      # Logs Google Analytics Admin API
├── ga-admin-error.log
├── n8n-access.log           # Logs N8N
├── n8n-error.log
├── qdrant-access.log        # Logs Qdrant
└── qdrant-error.log
```

### Labels Promtail

Chaque log est tagué avec :

- `job="nginx"` : Tous les logs NGINX
- `service="<nom>"` : Le service appelé (rag, braintrust, supabase, google_analytics_mp, etc.)
- `method="<method>"` : La méthode HTTP (GET, POST, etc.)
- `status="<code>"` : Le code de statut HTTP (200, 204, 400, etc.)

---

## Contribuer

Pour ajouter un nouveau service au proxy :

1. **Ajouter les variables d'environnement** dans `.env` et `.env.example`
2. **Ajouter le service dans** `docker-compose.yml` (section environment du service nginx)
3. **Créer la route dans** `nginx/proxy.conf.template`
4. **Ajouter le job Promtail dans** `loki/promtail-config.yml`
5. **Mettre à jour** `nginx/docker-entrypoint.sh` pour inclure la nouvelle variable dans `envsubst`
6. **Redémarrer** les services

---

## Support

Pour toute question ou problème :

1. Vérifier les logs : `docker logs nginx`
2. Consulter la section [Troubleshooting](#troubleshooting)
3. Vérifier la configuration générée : `docker exec nginx cat /etc/nginx/conf.d/proxy.conf`

---

**Dernière mise à jour :** 6 janvier 2026
