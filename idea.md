# Expense Tracker - Project Context

## Project Overview

This is an **AI-powered mobile expense tracker** application that helps users manage their personal finances by automatically parsing and categorizing bank statements using Claude AI. The app is built with a modern full-stack architecture featuring a FastAPI backend and React Native/Expo frontend.

**Primary Purpose**: Upload bank statements (Excel/PDF), have AI automatically extract and categorize transactions, then view insights and analytics about spending patterns.

## Architecture

### Tech Stack

**Backend** (`/backend`)
- **Framework**: FastAPI (Python 3.x)
- **Database**: MongoDB (NoSQL)
- **AI Integration**: Anthropic Claude API (Sonnet 4)
- **Authentication**: JWT tokens with bcrypt password hashing
- **Storage**: Supabase for file uploads
- **Server**: Uvicorn ASGI server on port 8001

**Frontend** (`/frontend`)
- **Framework**: Expo (React Native)
- **Language**: TypeScript
- **UI Components**: React Native Paper (Material Design)
- **Navigation**: React Navigation (native-stack)
- **State Management**: Zustand
- **HTTP Client**: Axios
- **Charts**: Victory Native

**Infrastructure**
- **Process Manager**: supervisord (manages MongoDB and backend)
- **Database**: MongoDB on port 27017
- **CORS**: Configured for frontend access

## Project Structure

```
/backend/
  server.py              # Main FastAPI application (605 lines)
                         # All API endpoints, AI processing, auth logic
  requirements.txt       # Python dependencies

/frontend/
  App.tsx               # Root component with navigation setup
  /src/
    /screens/           # 8 main screens
      LoginScreen.tsx
      SignupScreen.tsx
      DashboardScreen.tsx
      TransactionsScreen.tsx
      TransactionDetailScreen.tsx
      UploadScreen.tsx
      AnalyticsScreen.tsx
      ProfileScreen.tsx
    /config/
      api.ts            # Axios API client configuration
      supabase.ts       # Supabase client setup
      theme.ts          # App theme colors
    /store/
      authStore.ts      # Zustand authentication state
    /types/
      index.ts          # TypeScript interfaces

/supervisord.conf       # Process management configuration
/start_services.sh      # Service startup script
```

## Key Features

### 1. AI-Powered Statement Processing
- Upload bank statements (Excel/PDF format)
- Claude AI analyzes each transaction and:
  - Extracts merchant names (removes reference codes, card numbers)
  - Assigns categories based on merchant and description
  - Provides confidence scores for categorizations
- Transactions automatically saved to MongoDB

### 2. Transaction Management
- List all transactions with search and filtering
- Edit merchant names, categories, and notes
- Delete transactions
- Manual category override capability

### 3. Analytics Dashboard
- Visual spending breakdowns by category
- Monthly summaries
- Top spending categories
- Pie and bar charts
- Average transaction calculations

### 4. Category System
10 default categories with icons and colors:
- Groceries, Dining, Transportation, Shopping, Utilities
- Healthcare, Entertainment, Travel, Education, Other

### 5. User Authentication
- Email/password signup and login
- JWT token-based sessions (30-day expiration)
- Secure password hashing
- Protected API endpoints

## API Endpoints

### Authentication
- `POST /api/auth/signup` - Create new user
- `POST /api/auth/login` - Login and get JWT token
- `GET /api/auth/me` - Get current user info

### Transactions
- `GET /api/transactions` - List transactions (with filters)
- `GET /api/transactions/{id}` - Get single transaction
- `PATCH /api/transactions/{id}` - Update transaction
- `DELETE /api/transactions/{id}` - Delete transaction

### Statements
- `POST /api/statements/upload` - Upload bank statement for AI processing

### Analytics
- `GET /api/analytics/dashboard` - Get spending analytics

### Categories
- `GET /api/categories` - Get all categories for user

### Health
- `GET /api/health` - Server health check

## Development Workflow

### Backend Development
1. Backend runs via supervisord for auto-restart
2. Main logic is in `backend/server.py`
3. MongoDB data persists in `mongodb_data/` directory
4. Logs available in supervisor logs

### Frontend Development
1. Use `npm start` in frontend directory
2. Expo provides hot-reload
3. Test on physical devices with Expo Go app
4. API calls go through `src/config/api.ts`

### Running Services
```bash
./start_services.sh  # Starts MongoDB and backend via supervisord
```

## Important Files

### Configuration
- `backend/.env` - Backend environment variables (gitignored)
  - MongoDB URL, Supabase keys, Claude API key
- `frontend/.env` - Frontend environment variables (gitignored)
  - Backend API URL, Supabase keys

### Documentation
- `README.md` - Comprehensive project overview
- `SETUP_GUIDE.md` - Detailed setup instructions
- `NEXT_STEPS.md` - Quick start guide

## Database Schema

### MongoDB Collections

**users**
- `_id`, `email`, `password_hash`, `full_name`, `created_at`

**transactions**
- `_id`, `user_id`, `date`, `merchant`, `amount`, `category`, `confidence`, `notes`, `created_at`

**bank_statements**
- `_id`, `user_id`, `filename`, `status`, `uploaded_at`, `processed_at`

**categories**
- `_id`, `user_id`, `name`, `icon`, `color`, `is_default`

## Code Conventions

### Backend (`server.py`)
- FastAPI route functions use async/await
- JWT authentication via `get_current_user` dependency
- MongoDB queries use PyMongo
- Claude API calls in `process_transactions_with_ai()`
- Error handling with HTTPException

### Frontend
- Functional components with TypeScript
- React Navigation for screen routing
- Zustand for auth state management
- AsyncStorage for token persistence
- Material Design via React Native Paper

## AI Processing Flow

1. User uploads statement via UploadScreen
2. POST to `/api/statements/upload`
3. Backend parses Excel/PDF to extract raw data
4. For each transaction, call Claude API with prompt:
   - Clean merchant name
   - Categorize transaction
   - Return confidence score
5. Save processed transactions to MongoDB
6. Frontend displays in TransactionsScreen

## Security Considerations

- Passwords hashed with bcrypt (not stored in plaintext)
- JWT tokens for stateless authentication
- CORS middleware protects API
- Environment variables for all secrets
- Supabase RLS for file storage security

## Supported Bank Format

Currently supports Commercial Bank of Qatar Excel format:
- Columns: Date | Details | Amount | Balance
- Expects standard Excel date format
- PDF parsing is placeholder (to be implemented)

## Testing Considerations

- Test with real Excel bank statements
- Verify AI categorization accuracy
- Check authentication flow
- Test on multiple devices (iOS/Android/Web)
- Monitor Claude API usage and costs

## Common Tasks

### Adding a New Category
1. Add to default categories in `backend/server.py`
2. Update category types in `frontend/src/types/index.ts`
3. Restart backend

### Modifying AI Prompt
1. Edit `process_transactions_with_ai()` in `backend/server.py`
2. Adjust the Claude API prompt for better categorization

### Adding New Screen
1. Create screen in `frontend/src/screens/`
2. Add route in `App.tsx` navigation
3. Update TypeScript types if needed

### Debugging Issues
- Backend logs: Check supervisord logs
- Frontend: Use React Native debugger
- Database: Connect to MongoDB on localhost:27017
- API: Test endpoints with curl or Postman