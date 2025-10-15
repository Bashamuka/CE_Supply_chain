# Netlify Environment Variables Checker
# This script helps verify and set the correct environment variables in Netlify

echo "🔍 NETLIFY ENVIRONMENT VARIABLES CHECKER"
echo "========================================"
echo ""

# Check if Netlify CLI is installed
if ! command -v netlify &> /dev/null; then
    echo "❌ Netlify CLI not found. Please install it first:"
    echo "   npm install -g netlify-cli"
    echo ""
    echo "Or use the web interface at: https://app.netlify.com/"
    exit 1
fi

echo "✅ Netlify CLI found"
echo ""

# Check if we're in a Netlify site
if [ ! -f "netlify.toml" ]; then
    echo "❌ netlify.toml not found. Make sure you're in the project directory."
    exit 1
fi

echo "✅ netlify.toml found"
echo ""

# Get current environment variables
echo "📋 Current Environment Variables:"
echo "--------------------------------"
netlify env:list

echo ""
echo "🔧 Required Environment Variables:"
echo "---------------------------------"
echo "VITE_SUPABASE_URL=https://nvuohqfsgeulivaihxeh.supabase.co"
echo "VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im52dW9ocWZzZ2V1bGl2YWloeGVoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzk4NzEwMTMsImV4cCI6MjA1NTQ0NzAxM30.i444AztcnU3hvvPZmiexLOgOSxUUKeX_4h1rFAtYoQM"
echo ""

# Ask if user wants to set the variables
read -p "Do you want to set these environment variables? (y/n): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "🔧 Setting environment variables..."
    
    # Set Supabase URL
    netlify env:set VITE_SUPABASE_URL "https://nvuohqfsgeulivaihxeh.supabase.co"
    
    # Set Supabase Anon Key
    netlify env:set VITE_SUPABASE_ANON_KEY "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im52dW9ocWZzZ2V1bGl2YWloeGVoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzk4NzEwMTMsImV4cCI6MjA1NTQ0NzAxM30.i444AztcnU3hvvPZmiexLOgOSxUUKeX_4h1rFAtYoQM"
    
    echo ""
    echo "✅ Environment variables set successfully!"
    echo ""
    echo "🔄 Redeploying site..."
    netlify deploy --prod
    
    echo ""
    echo "🎉 Deployment complete! Check your site."
else
    echo "ℹ️  Environment variables not set. You can set them manually in the Netlify dashboard."
    echo ""
    echo "📝 Manual Setup Instructions:"
    echo "1. Go to https://app.netlify.com/"
    echo "2. Select your site"
    echo "3. Go to Site settings > Environment variables"
    echo "4. Add the variables listed above"
    echo "5. Redeploy your site"
fi

echo ""
echo "🏁 Script complete!"
