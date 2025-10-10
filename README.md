# CE-Parts Supply Chain Hub

A comprehensive supply chain management system for tracking parts, orders, and projects at Congo Equipment.

## Features

### Core Modules
- **Global Dashboard** - Overview of all system metrics and performance indicators
- **ETA Tracking** - Track order statuses, delivery dates, and part availability
- **Stock Availability** - Check stock levels across all branches and locations
- **Parts Equivalence** - Find equivalent parts and cross-references
- **Orders Movement** - Track order entries and deliveries with real-time updates
- **Project Management** - Create and track machine projects with parts availability analysis
- **Dealer Forward Planning** - Upload and manage parts forecasts for regional availability

### Administration
- **User Management** - Create, edit, and delete users
- **Role-Based Access Control** - Assign different roles (Admin, Employee, Consultant)
- **Module Permissions** - Grant or revoke access to specific modules per user
- **Project Access Control** - Manage user access to individual projects

## Tech Stack

- **Frontend**: React 18 + TypeScript
- **Routing**: React Router v7
- **State Management**: Zustand
- **Styling**: Tailwind CSS
- **UI Icons**: Lucide React
- **Database**: Supabase (PostgreSQL)
- **Authentication**: Supabase Auth
- **Build Tool**: Vite

## Prerequisites

- Node.js 18+ and npm
- A Supabase project with the required database schema

## Installation

1. Clone the repository:
```bash
git clone <your-repository-url>
cd ce-parts-supply-chain-hub
```

2. Install dependencies:
```bash
npm install
```

3. Create a `.env` file in the root directory with your Supabase credentials:
```env
VITE_SUPABASE_URL=your_supabase_url
VITE_SUPABASE_ANON_KEY=your_supabase_anon_key
```

4. Run database migrations:
The migrations are located in `supabase/migrations/`. Apply them to your Supabase project using the Supabase CLI or dashboard.

## Development

Start the development server:
```bash
npm run dev
```

The application will be available at `http://localhost:5173`

## Build

Create a production build:
```bash
npm run build
```

Preview the production build:
```bash
npm run preview
```

## Database Schema

The application uses the following main tables:
- `profiles` - User profiles and roles
- `user_module_access` - Module permissions per user
- `user_project_access` - Project access permissions
- `eta_tracking` - Parts tracking and ETA information
- `stock_availability` - Stock levels across locations
- `parts_equivalence` - Part equivalence mappings
- `orders` - Order movements and deliveries
- `projects` - Project definitions
- `project_machines` - Machines within projects
- `project_machine_parts` - Parts required for machines
- `dealer_forward_planning` - Forward planning data

## Security

- Row Level Security (RLS) is enabled on all tables
- Authentication is required for all routes except login/register
- Module and project access is controlled at the database level
- Admins have full access to all modules and features

## Project Structure

```
src/
├── components/          # React components
│   ├── AdminInterface.tsx
│   ├── Dashboard.tsx
│   ├── EtaTrackingInterface.tsx
│   ├── GlobalDashboard.tsx
│   ├── ProjectsInterface.tsx
│   └── ...
├── store/              # Zustand stores
│   ├── adminStore.ts
│   ├── userStore.ts
│   ├── projectsStore.ts
│   └── ...
├── types/              # TypeScript types
│   └── index.ts
├── lib/                # Utilities and configs
│   └── supabase.ts
└── App.tsx             # Main app component

supabase/
└── migrations/         # Database migrations
```

## Contributing

1. Create a feature branch
2. Make your changes
3. Test thoroughly
4. Submit a pull request

## License

Proprietary - Congo Equipment®

## Support

For support and questions, contact your system administrator.
