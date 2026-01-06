#!/bin/sh
set -e

# Fonction pour afficher les messages
log() {
    echo "[nginx-entrypoint] $1"
}

log "Starting NGINX proxy configuration..."

# Vérifier que les variables d'environnement requises sont définies
if [ -z "$RAG_UPSTREAM_URL" ]; then
    log "WARNING: RAG_UPSTREAM_URL is not set"
fi

if [ -z "$BRAINTRUST_API_KEY" ]; then
    log "WARNING: BRAINTRUST_API_KEY is not set"
fi

if [ -z "$SUPABASE_URL" ]; then
    log "WARNING: SUPABASE_URL is not set"
fi

if [ -z "$SUPABASE_API_KEY" ]; then
    log "WARNING: SUPABASE_API_KEY is not set"
fi

if [ -z "$GOOGLE_ANALYTICS_MEASUREMENT_ID" ]; then
    log "WARNING: GOOGLE_ANALYTICS_MEASUREMENT_ID is not set"
fi

if [ -z "$GOOGLE_ANALYTICS_API_SECRET" ]; then
    log "WARNING: GOOGLE_ANALYTICS_API_SECRET is not set"
fi

if [ -z "$GOOGLE_ANALYTICS_TOKEN" ]; then
    log "WARNING: GOOGLE_ANALYTICS_TOKEN is not set (only needed for Data/Admin APIs)"
fi

# Générer le fichier proxy.conf à partir du template
log "Generating proxy.conf from template..."
envsubst '${RAG_UPSTREAM_URL} ${BRAINTRUST_API_KEY} ${SUPABASE_URL} ${SUPABASE_API_KEY} ${GOOGLE_ANALYTICS_MEASUREMENT_ID} ${GOOGLE_ANALYTICS_API_SECRET} ${GOOGLE_ANALYTICS_TOKEN}' \
    < /etc/nginx/conf.d/proxy.conf.template \
    > /etc/nginx/conf.d/proxy.conf

log "Configuration generated successfully"

# Tester la configuration NGINX
log "Testing NGINX configuration..."
nginx -t

# Démarrer NGINX
log "Starting NGINX..."
exec nginx -g 'daemon off;'
