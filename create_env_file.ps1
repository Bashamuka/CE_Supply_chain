# Script PowerShell pour créer le fichier .env
# Ce script crée automatiquement le fichier .env avec les bonnes variables

Write-Host "Creating .env file for Supabase connection..." -ForegroundColor Green

# Contenu du fichier .env
$envContent = @"
# Supabase Configuration
VITE_SUPABASE_URL=https://nvuohqfsgeulivaihxeh.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im52dW9ocWZzZ2V1bGl2YWloeGVoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzk4NzEwMTMsImV4cCI6MjA1NTQ0NzAxM30.i444AztcnU3hvvPZmiexLOgOSxUUKeW_4h1rFAtYoQM

# Application Configuration
VITE_APP_NAME=CE-Parts Supply Chain Hub
VITE_APP_VERSION=1.0.0

# Development Configuration
VITE_DEBUG_MODE=true
VITE_LOG_LEVEL=info
"@

# Chemin du fichier .env
$envPath = ".\.env"

# Vérifier si le fichier existe déjà
if (Test-Path $envPath) {
    Write-Host "File .env already exists. Backing up..." -ForegroundColor Yellow
    Copy-Item $envPath "$envPath.backup" -Force
    Write-Host "Backup created: $envPath.backup" -ForegroundColor Yellow
}

# Créer le fichier .env
try {
    $envContent | Out-File -FilePath $envPath -Encoding UTF8 -Force
    Write-Host "✅ .env file created successfully!" -ForegroundColor Green
    Write-Host "Location: $envPath" -ForegroundColor Cyan
    
    # Afficher le contenu créé
    Write-Host "`nContent created:" -ForegroundColor Cyan
    Get-Content $envPath | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    
} catch {
    Write-Host "❌ Error creating .env file: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "`n🎉 Setup complete! You can now run 'npm run dev' to start the application." -ForegroundColor Green
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Run: npm run dev" -ForegroundColor White
Write-Host "2. Open your browser to the local development URL" -ForegroundColor White
Write-Host "3. Try logging in to test the connection" -ForegroundColor White

# Vérifier la connectivité réseau
Write-Host "`n🔍 Testing network connectivity..." -ForegroundColor Cyan
try {
    $pingResult = Test-NetConnection -ComputerName "nvuohqfsgeulivaihxeh.supabase.co" -Port 443 -InformationLevel Quiet
    if ($pingResult) {
        Write-Host "✅ Supabase server is reachable" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Supabase server may not be reachable" -ForegroundColor Yellow
    }
} catch {
    Write-Host "⚠️  Could not test network connectivity" -ForegroundColor Yellow
}

Write-Host "`n📚 For troubleshooting, see: SUPABASE_CONNECTION_TROUBLESHOOTING.md" -ForegroundColor Cyan
