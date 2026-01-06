# Configuration Ollama pour Docker

Ce guide explique comment configurer et démarrer Ollama correctement pour qu'il soit accessible depuis les conteneurs Docker (N8N, NGINX proxy, etc.).

## 🎯 Objectif

Par défaut, Ollama écoute uniquement sur `127.0.0.1:11434` (localhost), ce qui empêche les conteneurs Docker d'y accéder. Nous devons le configurer pour écouter sur toutes les interfaces (`0.0.0.0:11434`).

---

## ⚡ Démarrage rapide

### 1. Arrêter Ollama

```bash
killall ollama
```

### 2. Démarrer Ollama avec la bonne configuration

```bash
OLLAMA_HOST=0.0.0.0:11434 ollama serve
```

### 3. Vérifier la configuration

```bash
lsof -iTCP:11434 | grep LISTEN
```

**Résultat attendu :**
```
ollama  12345 francetv  3u  IPv6 0x...  0t0  TCP *:11434 (LISTEN)
                                              ^^^
                                              ✅ Écoute sur toutes les interfaces
```

**❌ Mauvaise configuration :**
```
ollama  12345 francetv  3u  IPv4 0x...  0t0  TCP localhost:11434 (LISTEN)
                                              ^^^^^^^^^^^^
                                              ❌ Écoute uniquement sur localhost
```

---

## 🔧 Configuration permanente

Pour ne pas avoir à définir `OLLAMA_HOST` à chaque démarrage, ajoutez-le à votre fichier de configuration shell.

### Sur macOS/Linux avec Zsh (par défaut sur macOS)

**1. Éditer `~/.zshrc` :**

```bash
nano ~/.zshrc
# ou
vim ~/.zshrc
# ou
code ~/.zshrc
```

**2. Ajouter à la fin du fichier :**

```bash
# Configuration Ollama pour Docker
export OLLAMA_HOST=0.0.0.0:11434
```

**3. Recharger la configuration :**

```bash
source ~/.zshrc
```

**4. Redémarrer Ollama :**

```bash
killall ollama
ollama serve &
```

### Sur macOS/Linux avec Bash

**1. Éditer `~/.bash_profile` ou `~/.bashrc` :**

```bash
nano ~/.bash_profile
```

**2. Ajouter à la fin du fichier :**

```bash
# Configuration Ollama pour Docker
export OLLAMA_HOST=0.0.0.0:11434
```

**3. Recharger la configuration :**

```bash
source ~/.bash_profile
```

**4. Redémarrer Ollama :**

```bash
killall ollama
ollama serve &
```

### Sur Linux avec systemd (installation système)

**1. Créer un fichier de configuration systemd :**

```bash
sudo systemctl edit ollama
```

**2. Ajouter la configuration :**

```ini
[Service]
Environment="OLLAMA_HOST=0.0.0.0:11434"
```

**3. Sauvegarder et quitter (Ctrl+X, puis Y, puis Entrée)**

**4. Recharger et redémarrer :**

```bash
sudo systemctl daemon-reload
sudo systemctl restart ollama
```

**5. Vérifier le statut :**

```bash
sudo systemctl status ollama
```

---

## 🚀 Démarrage automatique

### macOS - Démarrage automatique au login

**Option 1 : Avec launchd (recommandé)**

**1. Créer le fichier plist :**

```bash
nano ~/Library/LaunchAgents/com.ollama.serve.plist
```

**2. Copier cette configuration :**

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
    <key>StandardOutPath</key>
    <string>/tmp/ollama.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/ollama.err</string>
</dict>
</plist>
```

**3. Charger le service :**

```bash
launchctl load ~/Library/LaunchAgents/com.ollama.serve.plist
```

**4. Vérifier qu'il fonctionne :**

```bash
lsof -iTCP:11434 | grep LISTEN
```

**Commandes utiles :**

```bash
# Arrêter le service
launchctl unload ~/Library/LaunchAgents/com.ollama.serve.plist

# Redémarrer le service
launchctl unload ~/Library/LaunchAgents/com.ollama.serve.plist
launchctl load ~/Library/LaunchAgents/com.ollama.serve.plist

# Voir les logs
tail -f /tmp/ollama.log
```

**Option 2 : Ajouter dans le fichier de démarrage du shell**

Dans `~/.zshrc` (ou `~/.bash_profile`) :

```bash
# Démarrer Ollama automatiquement s'il n'est pas lancé
if ! pgrep -x "ollama" > /dev/null; then
    export OLLAMA_HOST=0.0.0.0:11434
    ollama serve > /tmp/ollama.log 2>&1 &
fi
```

---

## ✅ Vérification

### 1. Vérifier qu'Ollama écoute sur la bonne interface

```bash
lsof -iTCP:11434 | grep LISTEN
```

**Résultat attendu :**
```
ollama  12345 francetv  3u  IPv6 0x...  0t0  TCP *:11434 (LISTEN)
```

### 2. Tester depuis l'hôte

```bash
curl http://localhost:11434/api/tags
```

**Résultat attendu :** Liste des modèles Ollama en JSON

### 3. Tester depuis Docker (N8N)

```bash
docker exec n8n wget -qO- http://nginx:80/api/ollama/api/tags
```

**Résultat attendu :** Liste des modèles Ollama en JSON

### 4. Tester via le proxy NGINX

```bash
curl http://localhost:8080/api/ollama/api/tags
```

**Résultat attendu :** Liste des modèles Ollama en JSON

---

## 🐛 Troubleshooting

### Problème : Ollama ne démarre pas

**1. Vérifier qu'aucun processus n'utilise le port 11434 :**

```bash
lsof -iTCP:11434
```

**2. Si un processus est en cours, le tuer :**

```bash
killall ollama
# ou
kill -9 <PID>
```

**3. Redémarrer Ollama :**

```bash
OLLAMA_HOST=0.0.0.0:11434 ollama serve
```

### Problème : Variable OLLAMA_HOST non prise en compte

**1. Vérifier que la variable est définie :**

```bash
echo $OLLAMA_HOST
# Devrait afficher : 0.0.0.0:11434
```

**2. Si vide, l'exporter manuellement :**

```bash
export OLLAMA_HOST=0.0.0.0:11434
```

**3. Redémarrer Ollama :**

```bash
killall ollama
ollama serve &
```

### Problème : "Connection refused" depuis Docker

**1. Vérifier qu'Ollama écoute sur `*:11434` et pas `127.0.0.1:11434` :**

```bash
lsof -iTCP:11434 | grep LISTEN
```

**2. Vérifier que `host.docker.internal` est accessible :**

```bash
docker exec nginx ping -c 1 host.docker.internal
```

**3. Tester l'accès direct :**

```bash
docker exec n8n wget -qO- http://host.docker.internal:11434/api/tags
```

### Problème : Ollama redémarre automatiquement

Si Ollama redémarre automatiquement après un `killall`, c'est probablement un service système :

**Sur macOS avec launchd :**

```bash
# Lister les services Ollama
launchctl list | grep -i ollama

# Désactiver le service
launchctl unload ~/Library/LaunchAgents/com.ollama.serve.plist
```

**Sur Linux avec systemd :**

```bash
# Arrêter le service
sudo systemctl stop ollama

# Désactiver le démarrage automatique
sudo systemctl disable ollama
```

---

## 🔒 Sécurité

### ⚠️ Important

Configurer Ollama sur `0.0.0.0:11434` signifie qu'il accepte les connexions depuis **n'importe quelle interface réseau**.

### ✅ C'est sûr si :

- Vous êtes derrière un routeur avec NAT
- Le firewall de votre OS est activé
- Vous ne forwarding pas le port 11434 sur votre routeur
- Vous êtes sur un réseau privé/domestique

### 🛡️ Protections recommandées

**1. Activer le firewall macOS :**

```bash
# Activer le firewall
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on

# Autoriser Ollama
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/local/bin/ollama
```

**2. Vérifier qu'aucune règle de port forwarding n'existe :**

- Accéder à l'interface de votre routeur
- Vérifier qu'il n'y a pas de redirection du port 11434

**3. Limiter l'accès au réseau local uniquement (optionnel) :**

Si vous voulez plus de sécurité, vous pouvez utiliser un firewall pour limiter l'accès :

```bash
# macOS - Bloquer l'accès externe au port 11434
# (Nécessite PF - Packet Filter)
```

---

## 📊 Résumé des commandes

### Démarrage manuel

```bash
# Arrêter Ollama
killall ollama

# Démarrer avec la bonne config
OLLAMA_HOST=0.0.0.0:11434 ollama serve

# En arrière-plan
OLLAMA_HOST=0.0.0.0:11434 ollama serve &
```

### Configuration permanente

```bash
# Ajouter à ~/.zshrc ou ~/.bash_profile
echo 'export OLLAMA_HOST=0.0.0.0:11434' >> ~/.zshrc

# Recharger
source ~/.zshrc

# Redémarrer Ollama
killall ollama
ollama serve &
```

### Vérification

```bash
# Vérifier le port
lsof -iTCP:11434 | grep LISTEN

# Tester l'API
curl http://localhost:11434/api/tags

# Tester depuis Docker
docker exec n8n wget -qO- http://nginx:80/api/ollama/api/tags
```

---

## 📚 Prochaines étapes

Maintenant qu'Ollama est correctement configuré :

1. **Consulter [OLLAMA_N8N_SETUP.md](./OLLAMA_N8N_SETUP.md)** pour utiliser Ollama dans N8N
2. **Consulter [NGINX_PROXY_SETUP.md](./NGINX_PROXY_SETUP.md)** pour comprendre le proxy NGINX
3. **Créer vos premiers workflows N8N** avec Ollama

---

## 🔗 Liens utiles

- **Documentation officielle Ollama :** https://github.com/ollama/ollama
- **API Ollama :** https://github.com/ollama/ollama/blob/main/docs/api.md
- **Modèles disponibles :** https://ollama.com/library

---

**Dernière mise à jour :** 6 janvier 2026
