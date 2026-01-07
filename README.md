# Kit de démarrage IA auto-hébergé

**Self-hosted AI Starter Kit** est un template Docker Compose open-source conçu pour initialiser rapidement un environnement complet de développement IA local et low-code.

![n8n.io - Screenshot](https://raw.githubusercontent.com/n8n-io/self-hosted-ai-starter-kit/main/assets/n8n-demo.gif)

Créé par <https://github.com/n8n-io>, il combine la plateforme n8n auto-hébergée avec une sélection de produits et composants IA compatibles pour démarrer rapidement la création de workflows IA auto-hébergés.

> [!TIP]
> [Lire l'annonce officielle](https://blog.n8n.io/self-hosted-ai/)

### Composants inclus

✅ [**n8n auto-hébergé**](https://n8n.io/) - Plateforme low-code avec plus de 400 intégrations et des composants IA avancés

✅ [**Ollama**](https://ollama.com/) - Plateforme multi-plateformes pour installer et exécuter les derniers LLM locaux

✅ [**Qdrant**](https://qdrant.tech/) - Base de données vectorielle open-source haute performance avec une API complète

✅ [**PostgreSQL**](https://www.postgresql.org/) - Base de données robuste pour gérer de grandes quantités de données en toute sécurité

✅ **Proxy NGINX** - Passerelle API centralisée avec observabilité complète

✅ **Grafana + Loki** - Monitoring et visualisation des logs

---

## Documentation

| Guide | Description |
|-------|-------------|
| [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) | Déploiement complet sur serveur (VPS, Hostinger, etc.) |
| [OLLAMA_GUIDE.md](./OLLAMA_GUIDE.md) | Configuration et utilisation d'Ollama avec N8N |
| [NGINX_PROXY_SETUP.md](./NGINX_PROXY_SETUP.md) | Configuration du proxy NGINX et observabilité |
| [N8N_WORKFLOW_EXPORT.md](./N8N_WORKFLOW_EXPORT.md) | Export automatique des workflows vers Git |

---

### Ce que vous pouvez construire

⭐️ **Agents IA** pour la prise de rendez-vous

⭐️ **Résumé de PDF d'entreprise** en toute sécurité sans fuite de données

⭐️ **Bots Slack intelligents** pour améliorer les communications et les opérations IT

⭐️ **Analyse de documents financiers privés** à moindre coût

---

## Installation

### Cloner le dépôt

```bash
git clone https://github.com/n8n-io/self-hosted-ai-starter-kit.git
cd self-hosted-ai-starter-kit
cp .env.example .env  # Mettre à jour les secrets et mots de passe
```

### Lancer n8n avec Docker Compose

#### Pour les utilisateurs GPU Nvidia

```bash
git clone https://github.com/n8n-io/self-hosted-ai-starter-kit.git
cd self-hosted-ai-starter-kit
cp .env.example .env  # Mettre à jour les secrets et mots de passe
docker compose --profile gpu-nvidia up
```

> [!NOTE]
> Si vous n'avez jamais utilisé votre GPU Nvidia avec Docker, suivez les
> [instructions Ollama Docker](https://github.com/ollama/ollama/blob/main/docs/docker.md).

#### Pour les utilisateurs GPU AMD sur Linux

```bash
git clone https://github.com/n8n-io/self-hosted-ai-starter-kit.git
cd self-hosted-ai-starter-kit
cp .env.example .env  # Mettre à jour les secrets et mots de passe
docker compose --profile gpu-amd up
```

#### Pour les utilisateurs Mac / Apple Silicon

Si vous utilisez un Mac avec un processeur M1 ou plus récent, vous ne pouvez malheureusement pas exposer votre GPU à l'instance Docker. Deux options s'offrent à vous :

1. Exécuter le kit entièrement sur CPU (voir section "Pour tous les autres")
2. Exécuter Ollama sur votre Mac pour une inférence plus rapide et s'y connecter depuis n8n

Pour exécuter Ollama sur votre Mac, consultez la [page d'accueil Ollama](https://ollama.com/) pour les instructions d'installation, puis lancez le kit :

```bash
git clone https://github.com/n8n-io/self-hosted-ai-starter-kit.git
cd self-hosted-ai-starter-kit
cp .env.example .env  # Mettre à jour les secrets et mots de passe
docker compose up
```

##### Pour les utilisateurs Mac exécutant Ollama localement

Si vous exécutez Ollama localement sur votre Mac (pas dans Docker), vous devez modifier la variable d'environnement OLLAMA_HOST :

1. Définir `OLLAMA_HOST=host.docker.internal:11434` dans votre fichier `.env`
2. Après avoir vu "Editor is now accessible via: <http://localhost:5678/>" :
   1. Aller sur <http://localhost:5678/home/credentials>
   2. Cliquer sur "Local Ollama service"
   3. Changer l'URL de base en `http://host.docker.internal:11434/`

#### Pour tous les autres

```bash
git clone https://github.com/n8n-io/self-hosted-ai-starter-kit.git
cd self-hosted-ai-starter-kit
cp .env.example .env  # Mettre à jour les secrets et mots de passe
docker compose --profile cpu up
```

---

## Démarrage rapide

Le coeur du kit est un fichier Docker Compose pré-configuré avec les paramètres réseau et stockage, minimisant les installations supplémentaires.

Après avoir complété les étapes d'installation ci-dessus :

1. Ouvrir <http://localhost:5678/> dans votre navigateur pour configurer n8n (à faire une seule fois)
2. Ouvrir le workflow inclus : <http://localhost:5678/workflow/srOnR8PAY3u4RSwb>
3. Cliquer sur le bouton **Chat** en bas du canvas pour lancer le workflow
4. Si c'est la première exécution, attendez qu'Ollama finisse de télécharger Llama3.2 (vérifiez les logs Docker)

Pour accéder à n8n à tout moment : <http://localhost:5678/>

Avec votre instance n8n, vous avez accès à plus de 400 intégrations et une suite de nodes IA basiques et avancés comme [AI Agent](https://docs.n8n.io/integrations/builtin/cluster-nodes/root-nodes/n8n-nodes-langchain.agent/), [Text classifier](https://docs.n8n.io/integrations/builtin/cluster-nodes/root-nodes/n8n-nodes-langchain.text-classifier/), et [Information Extractor](https://docs.n8n.io/integrations/builtin/cluster-nodes/root-nodes/n8n-nodes-langchain.information-extractor/). Pour garder tout en local, utilisez le node Ollama pour votre modèle de langage et Qdrant comme base vectorielle.

> [!NOTE]
> Ce kit est conçu pour vous aider à démarrer avec les workflows IA auto-hébergés. Bien qu'il ne soit pas entièrement optimisé pour les environnements de production, il combine des composants robustes qui fonctionnent bien ensemble pour des projets de preuve de concept. Vous pouvez le personnaliser selon vos besoins.

---

## Mise à jour

### Pour les configurations GPU Nvidia

```bash
docker compose --profile gpu-nvidia pull
docker compose create && docker compose --profile gpu-nvidia up
```

### Pour les utilisateurs Mac / Apple Silicon

```bash
docker compose pull
docker compose create && docker compose up
```

### Pour les configurations sans GPU

```bash
docker compose --profile cpu pull
docker compose create && docker compose --profile cpu up
```

---

## Lectures recommandées

n8n propose beaucoup de contenu utile pour démarrer rapidement avec ses concepts et nodes IA. En cas de problème, consultez le [support](#support).

- [Agents IA pour développeurs : de la théorie à la pratique avec n8n](https://blog.n8n.io/ai-agents/)
- [Tutoriel : Créer un workflow IA dans n8n](https://docs.n8n.io/advanced-ai/intro-tutorial/)
- [Concepts Langchain dans n8n](https://docs.n8n.io/advanced-ai/langchain/langchain-n8n/)
- [Démonstration des différences clés entre agents et chaînes](https://docs.n8n.io/advanced-ai/examples/agent-chain-comparison/)
- [Qu'est-ce qu'une base de données vectorielle ?](https://docs.n8n.io/advanced-ai/examples/understand-vector-databases/)

## Vidéo explicative

- [Installer et utiliser Local AI pour n8n](https://www.youtube.com/watch?v=xz_X2N-hPg0)

---

## Plus de templates IA

Pour plus d'idées de workflows IA, visitez la [**galerie officielle de templates IA n8n**](https://n8n.io/workflows/categories/ai/). Depuis chaque workflow, cliquez sur **Use workflow** pour l'importer automatiquement dans votre instance n8n.

### Apprendre les concepts clés de l'IA

- [AI Agent Chat](https://n8n.io/workflows/1954-ai-agent-chat/)
- [Chat IA avec n'importe quelle source de données](https://n8n.io/workflows/2026-ai-chat-with-any-data-source-using-the-n8n-workflow-tool/)
- [Chat avec OpenAI Assistant (avec mémoire)](https://n8n.io/workflows/2098-chat-with-openai-assistant-by-adding-a-memory/)
- [Utiliser un LLM open-source (via Hugging Face)](https://n8n.io/workflows/1980-use-an-open-source-llm-via-huggingface/)
- [Chat avec des PDF en citant les sources](https://n8n.io/workflows/2165-chat-with-pdf-docs-using-ai-quoting-sources/)
- [Agent IA capable de scraper des pages web](https://n8n.io/workflows/2006-ai-agent-that-can-scrape-webpages/)

### Templates IA locaux

- [Assistant Code Fiscal](https://n8n.io/workflows/2341-build-a-tax-code-assistant-with-qdrant-mistralai-and-openai/)
- [Transformer des documents en notes d'étude avec MistralAI et Qdrant](https://n8n.io/workflows/2339-breakdown-documents-into-study-notes-using-templating-mistralai-and-qdrant/)
- [Assistant Documents Financiers avec Qdrant et Mistral.ai](https://n8n.io/workflows/2335-build-a-financial-documents-assistant-using-qdrant-and-mistralai/)
- [Recommandations de recettes avec Qdrant et Mistral](https://n8n.io/workflows/2333-recipe-recommendations-with-qdrant-and-mistral/)

---

## Astuces

### Accéder aux fichiers locaux

Le kit crée un dossier partagé (par défaut dans le même répertoire) monté dans le conteneur n8n, permettant à n8n d'accéder aux fichiers sur disque. Ce dossier dans le conteneur n8n est situé à `/data/shared` -- c'est le chemin à utiliser dans les nodes qui interagissent avec le système de fichiers local.

**Nodes qui interagissent avec le système de fichiers local**

- [Read/Write Files from Disk](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.filesreadwrite/)
- [Local File Trigger](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.localfiletrigger/)
- [Execute Command](https://docs.n8n.io/integrations/builtin/core-nodes/n8n-nodes-base.executecommand/)

---

## Licence

Ce projet est sous licence Apache License 2.0 - voir le fichier [LICENSE](LICENSE) pour les détails.

---

## Support

Rejoignez la conversation sur le [Forum n8n](https://community.n8n.io/), où vous pouvez :

- **Partager votre travail** : Montrez ce que vous avez construit avec n8n et inspirez les autres
- **Poser des questions** : Que vous débutiez ou soyez un expert, la communauté et notre équipe sont prêtes à vous aider
- **Proposer des idées** : Vous avez une idée de fonctionnalité ou d'amélioration ? Faites-le nous savoir !
