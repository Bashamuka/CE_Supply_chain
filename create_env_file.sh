#!/bin/bash

# Script Bash pour créer le fichier .env
# Ce script crée automatiquement le fichier .env avec les bonnes variables

echo "Creating .env file for Supabase connection..."

# Contenu du fichier .env
cat > .env << 'EOF'
# Supabase Configuration
VITE_SUPABASE_URL=https://nvuohqfsgeulivaihxeh.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im52dW9ocWZzZ2V1bGl2YWloeGVoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzk4NzEwMTMsImV4cCI6MjA1NTQ0NzAxM30.i444AztcnU3hvvPZmiexLOgOSxUUKeW_4h1rFAtYoQM

# Application Configuration
VITE_APP_NAME=CE-Parts Supply Chain Hub
VITE_APP_VERSION=1.0.0

# Development Configuration
VITE_DEBUG_MODE=true
VITE_LOG_LEVEL=info
EOF

# Vérifier si le fichier a été créé
if [ -f ".env" ]; then
    echo "✅ .env file created successfully!"
    echo "Location: $(pwd)/.env"
    
    echo ""
    echo "Content created:"
    cat .env | sed 's/^/  /'
    
else
    echo "❌ Error creating .env file"
    exit 1
fi

echo ""
echo "🎉 Setup complete! You can now run 'npm run dev' to start the application."
echo ""
echo "Next steps:"
echo "1. Run: npm run dev"
echo "2. Open your browser to the local development URL"
echo "3. Try logging in to test the connection"

# Vérifier la connectivité réseau
echo ""
echo "🔍 Testing network connectivity..."
if ping -c 1 nvuohqfsgeulivaihxeh.supabase.co > /dev/null 2>&1; then
    echo "✅ Supabase server is reachable"
else
    echo "⚠️  Supabase server may not be reachable"
fi

echo ""
echo "📚 For troubleshooting, see: SUPABASE_CONNECTION_TROUBLESHOOTING.md"
