# Netlify Deploy Script for Windows PowerShell
# This script helps with the deployment process on Windows

Write-Host "🚀 Starting Netlify deployment process..." -ForegroundColor Green

# Check if we're in the right directory
if (-not (Test-Path "package.json")) {
    Write-Host "❌ Error: package.json not found. Please run this script from the project root." -ForegroundColor Red
    exit 1
}

# Check if Node.js is available
try {
    $nodeVersion = node --version
    Write-Host "✅ Node.js version: $nodeVersion" -ForegroundColor Green
} catch {
    Write-Host "❌ Error: Node.js not found. Please install Node.js first." -ForegroundColor Red
    Write-Host "Download from: https://nodejs.org/" -ForegroundColor Yellow
    exit 1
}

# Install dependencies
Write-Host "📦 Installing dependencies..." -ForegroundColor Blue
try {
    npm install
    Write-Host "✅ Dependencies installed successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Error installing dependencies" -ForegroundColor Red
    exit 1
}

# Build the application
Write-Host "🔨 Building application..." -ForegroundColor Blue
try {
    npm run build
    Write-Host "✅ Build completed successfully" -ForegroundColor Green
} catch {
    Write-Host "❌ Error: Build failed" -ForegroundColor Red
    exit 1
}

# Check if build was successful
if (-not (Test-Path "dist")) {
    Write-Host "❌ Error: Build failed. No dist directory found." -ForegroundColor Red
    exit 1
}

Write-Host "📁 Dist directory contents:" -ForegroundColor Blue
Get-ChildItem -Path "dist" | Format-Table

Write-Host ""
Write-Host "🎉 Ready for deployment!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Next steps:" -ForegroundColor Yellow
Write-Host "1. Go to https://app.netlify.com/" -ForegroundColor White
Write-Host "2. Click 'New site from Git'" -ForegroundColor White
Write-Host "3. Connect your GitHub repository" -ForegroundColor White
Write-Host "4. Set build command: npm run build" -ForegroundColor White
Write-Host "5. Set publish directory: dist" -ForegroundColor White
Write-Host "6. Add environment variables in Site settings > Environment variables" -ForegroundColor White
Write-Host "7. Deploy!" -ForegroundColor White
Write-Host ""
Write-Host "🌐 Your site will be available at: https://classy-dango-1ee677.netlify.app/" -ForegroundColor Cyan
