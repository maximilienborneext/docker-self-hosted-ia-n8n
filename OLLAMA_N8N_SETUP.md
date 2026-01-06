# Ollama + N8N via NGINX Proxy

Ce document explique comment utiliser Ollama depuis N8N via le proxy NGINX pour avoir une observabilité complète des prompts et réponses LLM.

## 🎯 Avantages

- ✅ **Tous les prompts/réponses loggés** dans Grafana/Loki
- ✅ **Temps de génération trackés** pour chaque requête
- ✅ **URL unifiée** : `http://nginx:80/api/ollama/`
- ✅ **Pas besoin de gérer** `host.docker.internal` dans N8N

---

## 📋 Prérequis

### Configuration d'Ollama

Ollama doit écouter sur toutes les interfaces pour être accessible depuis Docker :

```bash
# Vérifier la configuration actuelle
lsof -iTCP:11434 | grep LISTEN

# Devrait montrer : *:11434 (ou 0.0.0.0:11434)
# Si ça montre 127.0.0.1:11434, configurer OLLAMA_HOST
```

### Rendre la configuration permanente

**Sur macOS, ajouter dans `~/.zshrc` ou `~/.bash_profile` :**

```bash
export OLLAMA_HOST=0.0.0.0:11434
```

Puis :
```bash
source ~/.zshrc
killall ollama
ollama serve &
```

**Sur Linux avec systemd :**

```bash
sudo systemctl edit ollama

# Ajouter :
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"

# Sauvegarder et redémarrer
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

---

## 🔧 Configuration dans N8N

### URL à utiliser dans N8N

**Depuis n'importe quel node N8N :**
```
http://nginx:80/api/ollama/
```

---

## 💡 Exemples d'utilisation

### 1. Node HTTP Request - Lister les modèles

**Configuration :**
- **Method :** GET
- **URL :** `http://nginx:80/api/ollama/api/tags`

**Réponse :**
```json
{
  "models": [
    {
      "name": "llama3.1:8b",
      "size": 4920753328,
      "details": {
        "parameter_size": "8.0B"
      }
    }
  ]
}
```

---

### 2. Node HTTP Request - Générer du texte (sans streaming)

**Configuration :**
- **Method :** POST
- **URL :** `http://nginx:80/api/ollama/api/generate`
- **Body Type :** JSON
- **Body :**

```json
{
  "model": "llama3.1:8b",
  "prompt": "{{ $json.question }}",
  "stream": false,
  "options": {
    "temperature": 0.7,
    "top_p": 0.9
  }
}
```

**Utilisation des variables N8N :**
```json
{
  "model": "{{ $json.model || 'llama3.1:8b' }}",
  "prompt": "{{ $json.prompt }}",
  "stream": false
}
```

**Réponse :**
```json
{
  "model": "llama3.1:8b",
  "response": "Voici la réponse générée...",
  "done": true,
  "total_duration": 5423789000,
  "load_duration": 1234567,
  "prompt_eval_count": 25,
  "eval_count": 150
}
```

---

### 3. Node HTTP Request - Chat avec contexte

**Configuration :**
- **Method :** POST
- **URL :** `http://nginx:80/api/ollama/api/chat`
- **Body :**

```json
{
  "model": "llama3.1:8b",
  "messages": [
    {
      "role": "system",
      "content": "Tu es un assistant utile et précis."
    },
    {
      "role": "user",
      "content": "{{ $json.question }}"
    }
  ],
  "stream": false
}
```

**Avec historique de conversation :**
```json
{
  "model": "llama3.1:8b",
  "messages": {{ $json.conversation_history }},
  "stream": false
}
```

**Réponse :**
```json
{
  "message": {
    "role": "assistant",
    "content": "Je suis là pour vous aider..."
  },
  "done": true
}
```

---

### 4. Node HTTP Request - Embeddings

**Configuration :**
- **Method :** POST
- **URL :** `http://nginx:80/api/ollama/api/embeddings`
- **Body :**

```json
{
  "model": "nomic-embed-text:latest",
  "prompt": "{{ $json.text }}"
}
```

**Réponse :**
```json
{
  "embedding": [0.123, 0.456, 0.789, ...]
}
```

---

## 🔄 Workflow N8N complet : Agent IA + Logging

Voici un workflow type pour utiliser Ollama avec logging automatique dans Braintrust :

### Node 1 : Webhook Trigger
- Reçoit `{ "question": "..." }`

### Node 2 : HTTP Request - Ollama
- **URL :** `http://nginx:80/api/ollama/api/generate`
- **Body :**
```json
{
  "model": "llama3.1:8b",
  "prompt": "{{ $json.question }}",
  "stream": false
}
```

### Node 3 : Code Node - Format Response
```javascript
return {
  json: {
    question: $input.first().json.question,
    answer: $json.response,
    model: $json.model,
    generation_time: ($json.total_duration / 1000000000).toFixed(2) + 's',
    tokens: $json.eval_count
  }
};
```

### Node 4 : HTTP Request - Log to Braintrust
- **URL :** `http://nginx:80/api/braintrust/project_logs/YOUR_PROJECT_ID/insert`
- **Body :**
```json
{
  "events": [{
    "input": "{{ $('Node 3').item.json.question }}",
    "output": "{{ $('Node 3').item.json.answer }}",
    "metadata": {
      "model": "{{ $('Node 3').item.json.model }}",
      "generation_time": "{{ $('Node 3').item.json.generation_time }}",
      "tokens": "{{ $('Node 3').item.json.tokens }}"
    }
  }]
}
```

### Node 5 : Respond to Webhook
- Retourne la réponse à l'utilisateur

---

## 📊 Observabilité dans Grafana

### Voir tous les appels Ollama

**Dans Grafana Explore (http://localhost:3000) :**

```logql
{job="nginx", service="ollama"} | json
```

### Voir les prompts envoyés

```logql
{job="nginx", service="ollama", method="POST"}
| json
| line_format "Prompt: {{.request_body}}"
```

### Analyser les temps de génération

**Temps moyen sur 5 minutes :**
```logql
avg(avg_over_time({job="nginx", service="ollama"} | json | unwrap request_time [5m]))
```

**Requêtes lentes (> 10 secondes) :**
```logql
{job="nginx", service="ollama"} | json | request_time > 10
```

### Compter les requêtes par modèle

```logql
{job="nginx", service="ollama"}
| json
| request_body =~ "model"
| line_format "{{.request_body}}"
```

### Dashboard Grafana suggéré

**Panel 1 : Nombre de requêtes (5 min)**
```logql
sum(count_over_time({job="nginx", service="ollama"}[5m]))
```

**Panel 2 : Temps de génération moyen**
```logql
avg(avg_over_time({job="nginx", service="ollama"} | json | unwrap request_time [5m]))
```

**Panel 3 : Distribution des temps de réponse**
```logql
histogram_quantile(0.95,
  sum(rate({job="nginx", service="ollama"} | json | unwrap request_time [5m])) by (le)
)
```

**Panel 4 : Taux d'erreur**
```logql
sum(rate({job="nginx", service="ollama"} | json | status >= 400 [5m]))
/
sum(rate({job="nginx", service="ollama"}[5m]))
```

---

## 🔍 Exemple de logs capturés

```json
{
  "time": "2026-01-06T17:58:28+00:00",
  "remote_addr": "172.18.0.6",
  "request_id": "8cbd07b76e4857ad7cb0dffe9acf0d86",
  "method": "POST",
  "host": "nginx",
  "request_uri": "/api/ollama/api/generate",
  "uri": "/api/generate",
  "status": 200,
  "request_time": 7.627,
  "upstream_status": "200",
  "request_body": "{\"model\":\"llama3.1:8b\",\"prompt\":\"Explique Docker\",\"stream\":false}",
  "content_type": "application/json",
  "content_length": "95"
}
```

**Informations loggées :**
- ✅ Prompt complet
- ✅ Modèle utilisé
- ✅ Temps de génération (7.627 secondes)
- ✅ Statut de la réponse
- ✅ ID de requête unique

---

## 🚀 Tests rapides

### Depuis l'hôte (votre machine)

```bash
# Lister les modèles
curl http://localhost:8080/api/ollama/api/tags

# Générer du texte
curl http://localhost:8080/api/ollama/api/generate -d '{
  "model": "llama3.1:8b",
  "prompt": "Bonjour",
  "stream": false
}'

# Chat
curl http://localhost:8080/api/ollama/api/chat -d '{
  "model": "llama3.1:8b",
  "messages": [{"role": "user", "content": "Hello"}],
  "stream": false
}'
```

### Depuis N8N (conteneur Docker)

Dans un node HTTP Request :
- **URL :** `http://nginx:80/api/ollama/api/tags`
- **Method :** GET

---

## ⚙️ Options de génération avancées

### Température et créativité

```json
{
  "model": "llama3.1:8b",
  "prompt": "Écris une histoire",
  "stream": false,
  "options": {
    "temperature": 0.9,     // Plus élevé = plus créatif (0.0 - 2.0)
    "top_p": 0.95,          // Nucleus sampling (0.0 - 1.0)
    "top_k": 40,            // Top-K sampling
    "repeat_penalty": 1.1,  // Pénalité pour répétition
    "num_predict": 500      // Nombre max de tokens générés
  }
}
```

### Contexte et prompt system

```json
{
  "model": "llama3.1:8b",
  "prompt": "Question utilisateur",
  "system": "Tu es un expert en Docker et Kubernetes",
  "stream": false
}
```

---

## 🔒 Sécurité

### Attention avec OLLAMA_HOST=0.0.0.0

Configurer Ollama sur `0.0.0.0:11434` signifie qu'il accepte les connexions depuis n'importe quelle interface réseau.

**C'est sûr si :**
- ✅ Vous êtes derrière un routeur/firewall
- ✅ Le firewall de votre OS est activé
- ✅ Vous ne partagez pas votre connexion

**Pour plus de sécurité :**
- Configurer des règles de firewall pour autoriser uniquement Docker
- Utiliser un VPN ou tunnel pour les connexions externes
- Ne pas exposer le port 11434 sur Internet

---

## 🐛 Troubleshooting

### Erreur : Connection refused

```bash
# Vérifier qu'Ollama écoute sur toutes les interfaces
lsof -iTCP:11434 | grep LISTEN
# Doit montrer : *:11434 (pas 127.0.0.1:11434)

# Si ce n'est pas le cas, reconfigurer
export OLLAMA_HOST=0.0.0.0:11434
killall ollama
ollama serve &
```

### Erreur 403 depuis N8N

```bash
# Tester depuis N8N
docker exec n8n wget -qO- http://nginx:80/health

# Si ça ne fonctionne pas, vérifier le réseau Docker
docker network inspect self-hosted-ai-starter-kit_demo
```

### Logs ne s'affichent pas dans Grafana

```bash
# Vérifier que Promtail collecte les logs Ollama
docker logs promtail | grep ollama

# Vérifier les logs NGINX
docker exec nginx ls -lh /var/log/nginx/ | grep ollama

# Tester une requête
curl http://localhost:8080/api/ollama/api/tags

# Vérifier le log
docker exec nginx tail -1 /var/log/nginx/ollama-access.log
```

### Ollama ne répond pas / timeout

Les timeouts sont configurés à 300 secondes (5 minutes) dans NGINX. Pour les ajuster :

Modifier `nginx/proxy.conf.template` :
```nginx
location /api/ollama/ {
    proxy_connect_timeout 600s;  # 10 minutes
    proxy_send_timeout 600s;
    proxy_read_timeout 600s;
    # ...
}
```

Puis redémarrer :
```bash
docker restart nginx
```

---

## 📖 Documentation officielle

- **Ollama API :** https://github.com/ollama/ollama/blob/main/docs/api.md
- **N8N HTTP Request :** https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.httprequest/
- **Grafana LogQL :** https://grafana.com/docs/loki/latest/logql/

---

**Dernière mise à jour :** 6 janvier 2026
