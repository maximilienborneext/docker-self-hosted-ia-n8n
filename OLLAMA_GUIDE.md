# Guide Ollama - Configuration et utilisation

Ce guide couvre l'installation, la configuration et l'utilisation d'Ollama avec la stack Docker (N8N, NGINX Proxy, etc.).

## Table des matières

- [Vue d'ensemble](#vue-densemble)
- [Installation](#installation)
- [Configuration pour Docker](#configuration-pour-docker)
- [Utilisation dans N8N](#utilisation-dans-n8n)
- [Exemples d'appels API](#exemples-dappels-api)
- [Observabilité dans Grafana](#observabilité-dans-grafana)
- [Troubleshooting](#troubleshooting)

---

## Vue d'ensemble

**Ollama** permet d'exécuter des LLM localement (Llama, Mistral, etc.). Dans cette stack, Ollama est accessible via le proxy NGINX, ce qui permet :

- Tous les prompts/réponses loggés dans Grafana/Loki
- Temps de génération trackés pour chaque requête
- URL unifiée depuis N8N : `http://nginx:80/api/ollama/`

### Architecture

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   N8N Workflow  │────▶│   NGINX Proxy   │────▶│     Ollama      │
│   (Docker)      │     │   (port 8080)   │     │   (port 11434)  │
└─────────────────┘     └─────────────────┘     └─────────────────┘
                               │
                               ▼
                        ┌─────────────────┐
                        │ Grafana / Loki  │
                        │ (Logs complets) │
                        └─────────────────┘
```

---

## Installation

### macOS

```bash
# Installer via Homebrew
brew install ollama

# Ou télécharger depuis https://ollama.com/download
```

### Linux

```bash
curl -fsSL https://ollama.com/install.sh | sh
```

### Vérifier l'installation

```bash
ollama --version
```

### Télécharger un modèle

```bash
# Modèle recommandé pour commencer
ollama pull llama3.1:8b

# Autres modèles populaires
ollama pull mistral:7b
ollama pull nomic-embed-text:latest  # Pour les embeddings
```

---

## Configuration pour Docker

Par défaut, Ollama écoute sur `127.0.0.1:11434` (localhost uniquement). Pour que les conteneurs Docker puissent y accéder, il faut configurer Ollama pour écouter sur toutes les interfaces.

### Démarrage rapide

```bash
# 1. Arrêter Ollama
killall ollama

# 2. Démarrer avec la bonne configuration
OLLAMA_HOST=0.0.0.0:11434 ollama serve

# 3. Vérifier
lsof -iTCP:11434 | grep LISTEN
```

**Résultat attendu :**
```
ollama  12345 user  3u  IPv6 0x...  TCP *:11434 (LISTEN)
                                        ^^^
                                        Écoute sur toutes les interfaces
```

### Configuration permanente

#### macOS/Linux (Zsh ou Bash)

```bash
# Ajouter dans ~/.zshrc ou ~/.bash_profile
echo 'export OLLAMA_HOST=0.0.0.0:11434' >> ~/.zshrc

# Recharger
source ~/.zshrc

# Redémarrer Ollama
killall ollama
ollama serve &
```

#### Linux avec systemd

```bash
# Éditer le service
sudo systemctl edit ollama

# Ajouter :
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"

# Redémarrer
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

#### macOS avec launchd (démarrage automatique)

Créer `~/Library/LaunchAgents/com.ollama.serve.plist` :

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.ollama.serve</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/ollama</string>
        <string>serve</string>
    </array>
    <key>EnvironmentVariables</key>
    <dict>
        <key>OLLAMA_HOST</key>
        <string>0.0.0.0:11434</string>
    </dict>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
</dict>
</plist>
```

Charger le service :
```bash
launchctl load ~/Library/LaunchAgents/com.ollama.serve.plist
```

---

## Utilisation dans N8N

### URL à utiliser

Depuis n'importe quel node N8N, utilisez :
```
http://nginx:80/api/ollama/
```

### Node HTTP Request - Lister les modèles

| Paramètre | Valeur |
|-----------|--------|
| Method | GET |
| URL | `http://nginx:80/api/ollama/api/tags` |

### Node HTTP Request - Générer du texte

| Paramètre | Valeur |
|-----------|--------|
| Method | POST |
| URL | `http://nginx:80/api/ollama/api/generate` |
| Body Type | JSON |

**Body :**
```json
{
  "model": "llama3.1:8b",
  "prompt": "{{ $json.question }}",
  "stream": false,
  "options": {
    "temperature": 0.7
  }
}
```

### Node HTTP Request - Chat avec contexte

| Paramètre | Valeur |
|-----------|--------|
| Method | POST |
| URL | `http://nginx:80/api/ollama/api/chat` |
| Body Type | JSON |

**Body :**
```json
{
  "model": "llama3.1:8b",
  "messages": [
    {"role": "system", "content": "Tu es un assistant utile."},
    {"role": "user", "content": "{{ $json.question }}"}
  ],
  "stream": false
}
```

### Node HTTP Request - Embeddings

| Paramètre | Valeur |
|-----------|--------|
| Method | POST |
| URL | `http://nginx:80/api/ollama/api/embeddings` |
| Body Type | JSON |

**Body :**
```json
{
  "model": "nomic-embed-text:latest",
  "prompt": "{{ $json.text }}"
}
```

---

## Exemples d'appels API

### Depuis l'hôte (curl)

```bash
# Lister les modèles
curl http://localhost:8080/api/ollama/api/tags

# Générer du texte
curl -X POST http://localhost:8080/api/ollama/api/generate \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.1:8b",
    "prompt": "Explique Docker en 3 phrases",
    "stream": false
  }'

# Chat
curl -X POST http://localhost:8080/api/ollama/api/chat \
  -H "Content-Type: application/json" \
  -d '{
    "model": "llama3.1:8b",
    "messages": [{"role": "user", "content": "Bonjour"}],
    "stream": false
  }'
```

### Options de génération

```json
{
  "model": "llama3.1:8b",
  "prompt": "...",
  "stream": false,
  "options": {
    "temperature": 0.7,      // Créativité (0.0 - 2.0)
    "top_p": 0.9,            // Nucleus sampling
    "top_k": 40,             // Top-K sampling
    "repeat_penalty": 1.1,   // Pénalité répétition
    "num_predict": 500       // Max tokens générés
  }
}
```

---

## Observabilité dans Grafana

Tous les appels Ollama sont loggés. Accédez à Grafana : `http://localhost:3000`

### Requêtes LogQL utiles

```logql
# Tous les appels Ollama
{job="nginx", service="ollama"} | json

# Voir les prompts envoyés
{job="nginx", service="ollama", method="POST"} | json | line_format "{{.request_body}}"

# Requêtes lentes (> 10 secondes)
{job="nginx", service="ollama"} | json | request_time > 10

# Temps moyen sur 5 minutes
avg(avg_over_time({job="nginx", service="ollama"} | json | unwrap request_time [5m]))

# Nombre de requêtes (5 min)
sum(count_over_time({job="nginx", service="ollama"}[5m]))
```

### Exemple de log capturé

```json
{
  "time": "2026-01-06T17:58:28+00:00",
  "method": "POST",
  "request_uri": "/api/ollama/api/generate",
  "status": 200,
  "request_time": 7.627,
  "request_body": "{\"model\":\"llama3.1:8b\",\"prompt\":\"Explique Docker\",\"stream\":false}"
}
```

---

## Troubleshooting

### Ollama n'écoute pas sur la bonne interface

```bash
# Vérifier
lsof -iTCP:11434 | grep LISTEN

# Si localhost:11434 (mauvais), reconfigurer :
export OLLAMA_HOST=0.0.0.0:11434
killall ollama
ollama serve &
```

### Connection refused depuis Docker

```bash
# Tester l'accès depuis N8N
docker exec n8n wget -qO- http://host.docker.internal:11434/api/tags

# Tester via le proxy
docker exec n8n wget -qO- http://nginx:80/api/ollama/api/tags
```

### Timeout sur les requêtes longues

Les timeouts sont configurés à 300 secondes (5 min) dans NGINX. Pour augmenter, modifier `nginx/proxy.conf.template` :

```nginx
location /api/ollama/ {
    proxy_connect_timeout 600s;  # 10 minutes
    proxy_send_timeout 600s;
    proxy_read_timeout 600s;
}
```

Puis redémarrer :
```bash
docker restart nginx
```

### Ollama redémarre automatiquement

Si Ollama redémarre après un `killall`, c'est un service système :

**macOS :**
```bash
launchctl list | grep -i ollama
launchctl unload ~/Library/LaunchAgents/com.ollama.serve.plist
```

**Linux :**
```bash
sudo systemctl stop ollama
sudo systemctl disable ollama
```

---

## Sécurité

Configurer Ollama sur `0.0.0.0:11434` signifie qu'il accepte les connexions depuis toutes les interfaces réseau.

**C'est sûr si :**
- Vous êtes derrière un routeur avec NAT
- Le firewall de votre OS est activé
- Vous êtes sur un réseau privé/domestique

**Recommandations :**
- Ne pas exposer le port 11434 sur Internet
- Utiliser un firewall pour limiter l'accès
- Surveiller les logs dans Grafana

---

## Liens utiles

- **Documentation Ollama** : https://github.com/ollama/ollama
- **API Ollama** : https://github.com/ollama/ollama/blob/main/docs/api.md
- **Modèles disponibles** : https://ollama.com/library

---

*Dernière mise à jour : 7 janvier 2026*
