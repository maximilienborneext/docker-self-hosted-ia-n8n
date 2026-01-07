# Export automatique des workflows N8N vers Git

Ce guide explique comment exporter automatiquement tous vos workflows N8N en fichiers JSON pour les versionner dans Git.

## 🎯 Objectif

Sauvegarder automatiquement tous les workflows N8N dans des fichiers JSON individuels pour :
- ✅ **Versionner les workflows** dans Git
- ✅ **Sauvegarder automatiquement** à chaque modification
- ✅ **Restaurer facilement** en cas de problème
- ✅ **Suivre l'historique** des changements

---

## 📋 Prérequis

### 1. Créer une clé API N8N

**Étapes :**
1. Ouvrez N8N : http://localhost:5678
2. Cliquez sur l'icône d'**engrenage** (Settings) en haut à droite
3. Allez dans **API**
4. Cliquez sur **Create an API key**
5. Copiez la clé générée

**Ajouter la clé dans `.env` :**
```bash
# Éditer le fichier .env
nano .env

# Ajouter cette ligne
N8N_API_KEY=votre-clé-api-n8n-ici
```

### 2. Installer jq (si pas déjà installé)

```bash
# Sur macOS
brew install jq

# Sur Ubuntu/Debian
sudo apt-get install jq

# Sur CentOS/RHEL
sudo yum install jq
```

---

## ⚡ Utilisation rapide

### Export manuel

```bash
# Charger les variables d'environnement
source .env

# Exporter tous les workflows
./scripts/export-n8n-workflows.sh
```

**Résultat :**
```
✅ Workflows exportés dans n8n/workflows/
   - {id}_workflow-name.json (un fichier par workflow)
   - index.json (liste de tous les workflows)
```

---

## 🔧 Configuration du script

Le script utilise des variables d'environnement pour la configuration :

| Variable | Description | Défaut |
|----------|-------------|--------|
| `N8N_HOST` | URL de l'instance N8N | `http://localhost:5678` |
| `N8N_API_KEY` | Clé API N8N | **(requis)** |
| `EXPORT_DIR` | Dossier de destination | `./n8n/workflows` |
| `COMMIT_CHANGES` | Commit automatique dans Git | `true` |

**Exemple avec variables personnalisées :**
```bash
N8N_HOST=http://localhost:5678 \
N8N_API_KEY=votre_clé \
EXPORT_DIR=./backup/workflows \
COMMIT_CHANGES=false \
./scripts/export-n8n-workflows.sh
```

---

## 🤖 Automatisation

### ✅ Option recommandée : Cron Job (CONFIGURÉ)

**Le cron job est déjà configuré et actif !**

Export automatique toutes les 6 heures (00:00, 06:00, 12:00, 18:00)

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
```

---

### Option 1 : Cron Job (déjà configuré)

**Exécuter l'export toutes les heures :**

```bash
# Éditer le crontab
crontab -e

# Ajouter cette ligne (export toutes les heures)
0 * * * * cd /Users/francetv/Documents/workspace/self-hosted-ai-starter-kit && source .env && ./scripts/export-n8n-workflows.sh >> /tmp/n8n-export.log 2>&1

# Pour toutes les 30 minutes
*/30 * * * * cd /Users/francetv/Documents/workspace/self-hosted-ai-starter-kit && source .env && ./scripts/export-n8n-workflows.sh >> /tmp/n8n-export.log 2>&1

# Pour tous les jours à 3h du matin
0 3 * * * cd /Users/francetv/Documents/workspace/self-hosted-ai-starter-kit && source .env && ./scripts/export-n8n-workflows.sh >> /tmp/n8n-export.log 2>&1
```

**Vérifier les logs :**
```bash
tail -f /tmp/n8n-export.log
```

**Lister les cron jobs actifs :**
```bash
crontab -l
```

---

### Option 2 : Launchd (macOS - démarrage automatique)

**Créer un agent launchd qui exécute l'export toutes les heures :**

**1. Créer le fichier plist :**
```bash
nano ~/Library/LaunchAgents/com.n8n.workflow-export.plist
```

**2. Copier cette configuration :**
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
        <string>cd /Users/francetv/Documents/workspace/self-hosted-ai-starter-kit && source .env && ./scripts/export-n8n-workflows.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>3600</integer>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/n8n-export.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/n8n-export.err</string>
</dict>
</plist>
```

**3. Charger le service :**
```bash
launchctl load ~/Library/LaunchAgents/com.n8n.workflow-export.plist
```

**4. Vérifier le statut :**
```bash
launchctl list | grep n8n.workflow-export
```

**Commandes utiles :**
```bash
# Arrêter le service
launchctl unload ~/Library/LaunchAgents/com.n8n.workflow-export.plist

# Redémarrer le service
launchctl unload ~/Library/LaunchAgents/com.n8n.workflow-export.plist
launchctl load ~/Library/LaunchAgents/com.n8n.workflow-export.plist

# Voir les logs
tail -f /tmp/n8n-export.log
```

---

### Option 3 : Systemd (Linux)

**Créer un service systemd avec timer :**

**1. Créer le service :**
```bash
sudo nano /etc/systemd/system/n8n-workflow-export.service
```

**Contenu :**
```ini
[Unit]
Description=N8N Workflow Export
After=network.target

[Service]
Type=oneshot
User=francetv
WorkingDirectory=/Users/francetv/Documents/workspace/self-hosted-ai-starter-kit
EnvironmentFile=/Users/francetv/Documents/workspace/self-hosted-ai-starter-kit/.env
ExecStart=/bin/bash /Users/francetv/Documents/workspace/self-hosted-ai-starter-kit/scripts/export-n8n-workflows.sh
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

**2. Créer le timer :**
```bash
sudo nano /etc/systemd/system/n8n-workflow-export.timer
```

**Contenu :**
```ini
[Unit]
Description=N8N Workflow Export Timer
Requires=n8n-workflow-export.service

[Timer]
OnBootSec=5min
OnUnitActiveSec=1h

[Install]
WantedBy=timers.target
```

**3. Activer et démarrer :**
```bash
sudo systemctl daemon-reload
sudo systemctl enable n8n-workflow-export.timer
sudo systemctl start n8n-workflow-export.timer
```

**4. Vérifier :**
```bash
# Voir le statut du timer
sudo systemctl status n8n-workflow-export.timer

# Voir les logs
sudo journalctl -u n8n-workflow-export.service -f
```

---

## 📁 Structure des fichiers exportés

```
n8n/workflows/
├── index.json                              # Métadonnées de tous les workflows
├── 1_Mon_premier_workflow.json             # Workflow ID 1
├── 2_Integration_Ollama.json               # Workflow ID 2
├── 3_RAG_avec_Qdrant.json                 # Workflow ID 3
└── auto-export-workflows.json             # Workflow d'export automatique (exemple)
```

### Format de `index.json`

```json
{
  "export_date": "2026-01-07T09:30:00Z",
  "workflow_count": 3,
  "workflows": [
    {
      "id": "1",
      "name": "Mon premier workflow",
      "active": true,
      "updatedAt": "2026-01-06T15:30:00.000Z"
    },
    {
      "id": "2",
      "name": "Integration Ollama",
      "active": true,
      "updatedAt": "2026-01-07T08:00:00.000Z"
    }
  ]
}
```

---

## 🔄 Commit automatique dans Git

Le script commit automatiquement les changements par défaut.

**Message de commit généré automatiquement :**
```
Auto-export N8N workflows - 2026-01-07 10:30:00

Exported 5 workflows:
- Mon premier workflow (ID: 1)
- Integration Ollama (ID: 2)
- RAG avec Qdrant (ID: 3)
- Webhook Analytics (ID: 4)
- Agent IA (ID: 5)

🤖 Generated with Claude Code
```

**Désactiver le commit automatique :**
```bash
COMMIT_CHANGES=false ./scripts/export-n8n-workflows.sh
```

**Push automatique vers GitHub (optionnel) :**

Décommenter cette ligne dans `scripts/export-n8n-workflows.sh` (ligne 177) :
```bash
# git push origin main
```

Devient :
```bash
git push origin main
```

---

## 📊 Restaurer un workflow depuis JSON

### Méthode 1 : Via l'interface N8N

1. Ouvrez N8N : http://localhost:5678
2. Cliquez sur **Import from File**
3. Sélectionnez le fichier JSON du workflow
4. Le workflow est restauré

### Méthode 2 : Via l'API N8N

```bash
# Restaurer un workflow spécifique
curl -X POST http://localhost:5678/api/v1/workflows \
  -H "X-N8N-API-KEY: votre_clé_api" \
  -H "Content-Type: application/json" \
  -d @n8n/workflows/1_Mon_workflow.json
```

### Méthode 3 : Script de restauration automatique

**Créer un script de restauration :**

```bash
#!/bin/bash
# scripts/import-n8n-workflows.sh

N8N_HOST="${N8N_HOST:-http://localhost:5678}"
N8N_API_KEY="${N8N_API_KEY:-}"
IMPORT_DIR="${IMPORT_DIR:-./n8n/workflows}"

for file in "$IMPORT_DIR"/*.json; do
    # Ignorer index.json et auto-export-workflows.json
    if [[ "$file" == *"index.json" ]] || [[ "$file" == *"auto-export-workflows.json" ]]; then
        continue
    fi

    echo "Importing: $file"
    curl -X POST "$N8N_HOST/api/v1/workflows" \
        -H "X-N8N-API-KEY: $N8N_API_KEY" \
        -H "Content-Type: application/json" \
        -d @"$file"
    echo ""
done
```

**Utilisation :**
```bash
chmod +x scripts/import-n8n-workflows.sh
source .env
./scripts/import-n8n-workflows.sh
```

---

## 🐛 Troubleshooting

### Erreur : "N8N_API_KEY n'est pas définie"

**Cause :** La clé API N8N n'est pas configurée.

**Solution :**
1. Créez une clé API dans N8N (Settings → API)
2. Ajoutez-la dans `.env` :
   ```bash
   N8N_API_KEY=votre_clé_api
   ```
3. Rechargez les variables :
   ```bash
   source .env
   ```

---

### Erreur : "jq n'est pas installé"

**Solution :**
```bash
# macOS
brew install jq

# Linux
sudo apt-get install jq
```

---

### Erreur : "Erreur API N8N: 'X-N8N-API-KEY' header required"

**Cause :** La clé API n'est pas valide ou expirée.

**Solution :**
1. Vérifiez que la clé API est correcte dans `.env`
2. Créez une nouvelle clé API dans N8N
3. Mettez à jour `.env` avec la nouvelle clé

---

### Erreur : "Impossible de récupérer les workflows"

**Causes possibles :**
1. N8N n'est pas accessible
2. L'URL N8N est incorrecte

**Solution :**
```bash
# Vérifier que N8N est accessible
curl http://localhost:5678/healthz

# Vérifier les conteneurs Docker
docker ps | grep n8n

# Tester l'API manuellement
curl -H "X-N8N-API-KEY: votre_clé" http://localhost:5678/api/v1/workflows
```

---

### Aucun changement détecté dans Git

**Cause :** Les workflows n'ont pas changé depuis le dernier export.

**C'est normal !** Le script ne commit que s'il y a des modifications.

**Forcer un export et voir les différences :**
```bash
# Voir les fichiers qui ont changé
git status n8n/workflows/

# Voir les différences
git diff n8n/workflows/
```

---

### Le cron ne s'exécute pas

**Vérifier que le cron est actif :**
```bash
# Lister les cron jobs
crontab -l

# Vérifier les logs système (macOS)
log show --predicate 'process == "cron"' --last 1h

# Vérifier les logs (Linux)
grep CRON /var/log/syslog
```

**Tester le script manuellement :**
```bash
cd /Users/francetv/Documents/workspace/self-hosted-ai-starter-kit
source .env
./scripts/export-n8n-workflows.sh
```

**Vérifier les permissions :**
```bash
ls -la scripts/export-n8n-workflows.sh
# Doit être : -rwxr-xr-x (exécutable)

# Si pas exécutable :
chmod +x scripts/export-n8n-workflows.sh
```

---

## 📊 Monitoring et logs

### Voir les logs du dernier export

```bash
tail -f /tmp/n8n-export.log
```

### Voir l'historique Git des workflows

```bash
# Voir les commits d'export
git log --oneline -- n8n/workflows/

# Voir les changements d'un workflow spécifique
git log -p n8n/workflows/1_Mon_workflow.json

# Comparer deux versions
git diff HEAD~1 HEAD -- n8n/workflows/1_Mon_workflow.json
```

### Statistiques d'export

```bash
# Nombre de workflows exportés
ls -1 n8n/workflows/*.json | grep -v index.json | wc -l

# Taille totale
du -sh n8n/workflows/

# Date du dernier export
jq -r '.export_date' n8n/workflows/index.json
```

---

## 🔒 Sécurité

### ⚠️ Important

- **Ne committez JAMAIS** le fichier `.env` contenant votre clé API
- **Vérifiez** que `.env` est dans `.gitignore`
- **Utilisez** des clés API avec les permissions minimales requises

### Vérifier que .env est ignoré

```bash
# Vérifier .gitignore
cat .gitignore | grep .env

# Vérifier que .env n'est pas tracké
git status | grep .env
# Ne doit rien afficher
```

### Rotation des clés API

Il est recommandé de changer régulièrement les clés API :

1. Créez une nouvelle clé dans N8N
2. Mettez à jour `.env`
3. Supprimez l'ancienne clé dans N8N

---

## 📚 Récapitulatif des commandes

### Export manuel
```bash
source .env
./scripts/export-n8n-workflows.sh
```

### Configuration cron (toutes les heures)
```bash
crontab -e
# Ajouter :
0 * * * * cd /Users/francetv/Documents/workspace/self-hosted-ai-starter-kit && source .env && ./scripts/export-n8n-workflows.sh >> /tmp/n8n-export.log 2>&1
```

### Voir les logs
```bash
tail -f /tmp/n8n-export.log
```

### Vérifier les exports
```bash
ls -lh n8n/workflows/
jq -r '.workflows[] | "\(.id) - \(.name)"' n8n/workflows/index.json
```

### Historique Git
```bash
git log --oneline -- n8n/workflows/
```

---

## 🔗 Liens utiles

- **N8N API Documentation :** https://docs.n8n.io/api/
- **Cron Expression Generator :** https://crontab.guru/
- **jq Manual :** https://stedolan.github.io/jq/manual/

---

**Dernière mise à jour :** 7 janvier 2026
