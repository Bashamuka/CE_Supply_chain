# CE-Parts Supply Chain Hub

A comprehensive supply chain management application built with React, TypeScript, and Supabase.

## 🚀 Live Demo

**Production URL**: [https://classy-dango-1ee677.netlify.app/](https://classy-dango-1ee677.netlify.app/)

## ✨ Features

- **User Authentication**: Secure login with Supabase Auth
- **Role-Based Access Control**: Admin, Employee, and Consultant roles
- **Module Management**: Granular permissions for different modules
- **Real-time Data**: Live updates with Supabase
- **Responsive Design**: Works on desktop, tablet, and mobile
- **Professional UI**: Clean, modern interface with CATERPILLAR branding

## 🏗️ Architecture

- **Frontend**: React 18 + TypeScript + Vite
- **Styling**: Tailwind CSS
- **State Management**: Zustand
- **Backend**: Supabase (PostgreSQL + Auth + Real-time)
- **Deployment**: Netlify

## 📦 Modules

1. **Global Dashboard** - System overview and metrics
2. **ETA Tracking** - Order status and delivery tracking
3. **Stock Availability** - Real-time inventory management
4. **Parts Equivalence** - Cross-reference and alternative parts
5. **Orders Management** - Complete order lifecycle
6. **Projects Management** - Project planning and analytics
7. **Dealer Forward Planning** - Demand forecasting and planning
8. **Administration** - User and permissions management

## 🔧 Environment Variables

```env
VITE_SUPABASE_URL=https://nvuohqfsgeulivaihxeh.supabase.co
VITE_SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im52dW9ocWZzZ2V1bGl2YWloeGVoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Mzk4NzEwMTMsImV4cCI6MjA1NTQ0NzAxM30.i444AztcnU3hvvPZmiexLOgOSxUUKeX_4h1rFAtYoQM
```

## 🚀 Quick Deploy

### Option 1: Deploy to Netlify (Recommended)

1. **Fork this repository**
2. **Connect to Netlify**:
   - Go to [Netlify](https://app.netlify.com/)
   - Click "New site from Git"
   - Select your forked repository
   - Set build command: `npm run build`
   - Set publish directory: `dist`
3. **Add environment variables** in Netlify dashboard
4. **Deploy!**

### Option 2: Local Development

```bash
# Clone the repository
git clone https://github.com/Bashamuka/CE_Supply_chain.git
cd CE_Supply_chain

# Install dependencies
npm install

# Start development server
npm run dev
```

## 📱 Demo Credentials

- **Admin**: `pacifiquebashamuka@gmail.com` / `admin`
- **Employee**: Contact administrator for access

## 🛠️ Build Commands

```bash
# Development
npm run dev

# Production build
npm run build

# Preview production build
npm run preview

# Lint code
npm run lint
```

## 📊 Database Schema

The application uses Supabase with the following key tables:
- `profiles` - User profiles and roles
- `user_module_access` - Module permissions
- `user_project_access` - Project-specific access
- `projects` - Project management
- `orders` - Order tracking
- `parts` - Parts catalog
- `stock_dispo` - Stock availability

## 🔒 Security Features

- Row Level Security (RLS) enabled on all tables
- Role-based access control
- Secure authentication with Supabase
- Environment variable protection
- HTTPS enforcement

## 🌐 Browser Support

- Chrome 90+
- Firefox 88+
- Safari 14+
- Edge 90+

## 📄 License

This project is proprietary software developed for Congo Equipment®.

## 🤝 Support

For technical support or feature requests, please contact the development team.

---

**Powered by Congo Equipment®** | Built with ❤️ for supply chain excellence
