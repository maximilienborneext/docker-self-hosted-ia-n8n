# Guide d'export des workflows N8N

Ce guide couvre l'export automatique des workflows N8N en fichiers JSON pour le versionnement Git.

## Table des matières

- [Vue d'ensemble](#vue-densemble)
- [Configuration](#configuration)
- [Utilisation](#utilisation)
- [Automatisation](#automatisation)
- [Restauration](#restauration)
- [Troubleshooting](#troubleshooting)

---

## Vue d'ensemble

L'export automatique permet de :
- Versionner les workflows dans Git
- Sauvegarder automatiquement à chaque modification
- Restaurer facilement en cas de problème
- Suivre l'historique des changements

### Structure des fichiers exportés

```
n8n/workflows/
├── index.json                    # Métadonnées de tous les workflows
├── {id}_workflow_name.json       # Fichiers de workflows
├── ...
└── history/                      # Historique des exports
    ├── 2026-01-07_10-30-00/      # Snapshot horodaté
    │   ├── index.json
    │   └── *.json
    ├── 2026-01-07_16-30-00/
    └── ...
```

---

## Configuration

### 1. Créer une clé API N8N

1. Ouvrir N8N : http://localhost:5678
2. **Settings** (engrenage) → **API**
3. **Create an API key**
4. Copier la clé

### 2. Ajouter la clé dans `.env`

```bash
N8N_API_KEY=votre-clé-api-n8n
```

### 3. Installer jq (si nécessaire)

```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq
```

---

## Utilisation

### Export manuel

```bash
source .env
./scripts/export-n8n-workflows.sh
```

**Résultat :**
```
Workflows exportés dans n8n/workflows/
- {id}_workflow-name.json (un fichier par workflow)
- index.json (liste de tous les workflows)
```

### Variables de configuration

| Variable | Description | Défaut |
|----------|-------------|--------|
| `N8N_HOST` | URL de N8N | `http://localhost:8080/api/n8n` |
| `N8N_API_KEY` | Clé API N8N | **(requis)** |
| `EXPORT_DIR` | Dossier destination | `./n8n/workflows` |
| `COMMIT_CHANGES` | Commit auto Git | `true` |
| `ENABLE_HISTORY` | Activer l'historisation | `true` |
| `HISTORY_DIR` | Dossier des archives | `./n8n/workflows/history` |
| `HISTORY_RETENTION` | Nombre d'historiques à garder | `10` |

**Exemple avec options :**
```bash
COMMIT_CHANGES=false ./scripts/export-n8n-workflows.sh
```

---

## Automatisation

### Cron job (configuré par défaut)

Export automatique toutes les 6 heures (00:00, 06:00, 12:00, 18:00).

**Voir la configuration :**
```bash
crontab -l
```

**Voir les logs :**
```bash
tail -f /tmp/n8n-export.log
```

**Modifier la fréquence :**
```bash
crontab -e

# Toutes les heures
0 * * * * cd /chemin/projet && source .env && ./scripts/export-n8n-workflows.sh >> /tmp/n8n-export.log 2>&1

# Tous les jours à 3h
0 3 * * * cd /chemin/projet && source .env && ./scripts/export-n8n-workflows.sh >> /tmp/n8n-export.log 2>&1
```

### macOS avec launchd

Créer `~/Library/LaunchAgents/com.n8n.workflow-export.plist` :

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.n8n.workflow-export</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>cd /chemin/projet && source .env && ./scripts/export-n8n-workflows.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>3600</integer>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
```

```bash
launchctl load ~/Library/LaunchAgents/com.n8n.workflow-export.plist
```

---

## Historisation

À chaque export, une copie horodatée est sauvegardée dans `history/`.

### Fonctionnement

- Activé par défaut (`ENABLE_HISTORY=true`)
- Crée un dossier `YYYY-MM-DD_HH-MM-SS` à chaque export
- Conserve les 10 derniers exports (configurable via `HISTORY_RETENTION`)
- Les anciens historiques sont automatiquement supprimés

### Désactiver l'historisation

```bash
ENABLE_HISTORY=false ./scripts/export-n8n-workflows.sh
```

### Modifier la rétention

```bash
# Garder 20 historiques
HISTORY_RETENTION=20 ./scripts/export-n8n-workflows.sh

# Garder tous les historiques (illimité)
HISTORY_RETENTION=0 ./scripts/export-n8n-workflows.sh
```

### Restaurer depuis l'historique

```bash
# Lister les historiques disponibles
ls -la n8n/workflows/history/

# Restaurer un workflow spécifique
cp n8n/workflows/history/2026-01-07_10-30-00/workflow.json n8n/workflows/
```

---

## Commit automatique Git

Le script commit automatiquement par défaut.

**Message de commit généré :**
```
Auto-export N8N workflows - 2026-01-07 10:30:00

Exported 5 workflows:
- Mon premier workflow (ID: 1)
- Integration Ollama (ID: 2)
...
```

**Désactiver :**
```bash
COMMIT_CHANGES=false ./scripts/export-n8n-workflows.sh
```

**Activer le push automatique :**

Décommenter dans `scripts/export-n8n-workflows.sh` :
```bash
# git push origin main
```

---

## Restauration

### Via l'interface N8N

1. Ouvrir N8N
2. **Import from File**
3. Sélectionner le fichier JSON

### Via l'API

```bash
curl -X POST http://localhost:5678/api/v1/workflows \
  -H "X-N8N-API-KEY: $N8N_API_KEY" \
  -H "Content-Type: application/json" \
  -d @n8n/workflows/1_Mon_workflow.json
```

---

## Monitoring

### Voir les exports

```bash
ls -lh n8n/workflows/
jq -r '.workflows[] | "\(.id) - \(.name)"' n8n/workflows/index.json
```

### Historique Git

```bash
# Voir les commits d'export
git log --oneline -- n8n/workflows/

# Voir les changements d'un workflow
git log -p n8n/workflows/1_Mon_workflow.json

# Comparer deux versions
git diff HEAD~1 HEAD -- n8n/workflows/1_Mon_workflow.json
```

---

## Troubleshooting

### N8N_API_KEY non définie

```bash
# Vérifier
echo $N8N_API_KEY

# Recharger
source .env
```

### jq non installé

```bash
# macOS
brew install jq

# Linux
sudo apt-get install jq
```

### Erreur API : 'X-N8N-API-KEY' header required

La clé API est invalide ou expirée.

1. Créer une nouvelle clé dans N8N
2. Mettre à jour `.env`

### Impossible de récupérer les workflows

```bash
# Vérifier que N8N est accessible
curl http://localhost:5678/healthz

# Vérifier les conteneurs
docker ps | grep n8n

# Tester l'API
curl -H "X-N8N-API-KEY: $N8N_API_KEY" http://localhost:5678/api/v1/workflows
```

### Le cron ne s'exécute pas

```bash
# Vérifier le cron
crontab -l

# Tester manuellement
cd /chemin/projet && source .env && ./scripts/export-n8n-workflows.sh

# Vérifier les permissions
chmod +x scripts/export-n8n-workflows.sh
```

---

## Sécurité

- **Ne jamais committer `.env`** contenant la clé API
- Vérifier que `.env` est dans `.gitignore`
- Utiliser des clés API avec permissions minimales
- Changer régulièrement les clés API

---

## Documentation associée

- **Configuration Ollama** : [OLLAMA_GUIDE.md](./OLLAMA_GUIDE.md)
- **Proxy NGINX** : [NGINX_PROXY_SETUP.md](./NGINX_PROXY_SETUP.md)
- **Déploiement serveur** : [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md)

---

*Dernière mise à jour : 7 janvier 2026*
