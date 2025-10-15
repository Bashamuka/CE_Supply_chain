# Netlify Environment Variables Checker (PowerShell)
# This script helps verify and set the correct environment variables in Netlify

Write-Host "🔍 NETLIFY ENVIRONMENT VARIABLES CHECKER" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Netlify CLI is installed
try {
    $netlifyVersion = netlify --version 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Netlify CLI not found"
    }
    Write-Host "✅ Netlify CLI found" -ForegroundColor Green
} catch {
    Write-Host "❌ Netlify CLI not found. Please install it first:" -ForegroundColor Red
    Write-Host "   npm install -g netlify-cli" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Or use the web interface at: https://app.netlify.com/" -ForegroundColor Yellow
    exit 1
}

Write-Host ""

# Check if we're in a Netlify site
if (-not (Test-Path "netlify.toml")) {
    Write-Host "❌ netlify.toml not found. Make sure you're in the project directory." -ForegroundColor Red
    exit 1
}

Write-Host "✅ netlify.toml found" -ForegroundColor Green
Write-Host ""

# Get current environment variables
Write-Host "📋 Current Environment Variables:" -ForegroundColor Cyan
Write-Host "--------------------------------" -ForegroundColor Cyan
netlify env:list

Write-Host ""
Write-Host "🔧 Required Environment Variables:" -ForegroundColor Cyan
Write-Host "---------------------------------" -ForegroundColor Cyan
Write-Host "VITE_SUPABASE_URL=https://nvuohqfsgeulivaihxeh.supabase.co" -ForegroundColor Yellow
Write-Host "VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im52dW9ocWZzZ2V1bGl2YWloeGVoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzk4NzEwMTMsImV4cCI6MjA1NTQ0NzAxM30.i444AztcnU3hvvPZmiexLOgOSxUUKeX_4h1rFAtYoQM" -ForegroundColor Yellow
Write-Host ""

# Ask if user wants to set the variables
$response = Read-Host "Do you want to set these environment variables? (y/n)"
Write-Host ""

if ($response -eq "y" -or $response -eq "Y") {
    Write-Host "🔧 Setting environment variables..." -ForegroundColor Cyan
    
    # Set Supabase URL
    netlify env:set VITE_SUPABASE_URL "https://nvuohqfsgeulivaihxeh.supabase.co"
    
    # Set Supabase Anon Key
    netlify env:set VITE_SUPABASE_ANON_KEY "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im52dW9ocWZzZ2V1bGl2YWloeGVoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzk4NzEwMTMsImV4cCI6MjA1NTQ0NzAxM30.i444AztcnU3hvvPZmiexLOgOSxUUKeX_4h1rFAtYoQM"
    
    Write-Host ""
    Write-Host "✅ Environment variables set successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "🔄 Redeploying site..." -ForegroundColor Cyan
    netlify deploy --prod
    
    Write-Host ""
    Write-Host "🎉 Deployment complete! Check your site." -ForegroundColor Green
} else {
    Write-Host "ℹ️  Environment variables not set. You can set them manually in the Netlify dashboard." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "📝 Manual Setup Instructions:" -ForegroundColor Cyan
    Write-Host "1. Go to https://app.netlify.com/" -ForegroundColor White
    Write-Host "2. Select your site" -ForegroundColor White
    Write-Host "3. Go to Site settings > Environment variables" -ForegroundColor White
    Write-Host "4. Add the variables listed above" -ForegroundColor White
    Write-Host "5. Redeploy your site" -ForegroundColor White
}

Write-Host ""
Write-Host "🏁 Script complete!" -ForegroundColor Cyan
