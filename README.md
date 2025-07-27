# POS Backend - Indonesian Point of Sale System

A Ruby on Rails 8 backend for a Point of Sale system designed for Indonesian restaurants and UMKM stores, featuring offline-first capabilities and multi-tenancy support.

## 🏗️ Technical Stack

- **Framework**: Ruby on Rails 8 with ActiveAdmin
- **Database**: PostgreSQL 15 with multi-tenancy (company_id approach)
- **Authentication**: JWT with short-lived access tokens + refresh tokens
- **Admin Panel**: ActiveAdmin for internal management
- **Background Jobs**: Solid Queue (Solid Trifecta - Queue, Cache, Cable)
- **Caching**: Redis for session storage and application caching
- **Deployment**: Docker containerization + Kamal orchestration

## 🚀 Getting Started

### Prerequisites

- Docker and Docker Compose
- Ruby 3.4.2 (if running locally)
- PostgreSQL 15
- Redis 7

### Setup with Docker (Recommended)

1. Clone the repository:
```bash
git clone <repository-url>
cd pos-be
```

2. Copy environment variables:
```bash
cp .env.example .env
```

3. Build and start the containers:
```bash
docker-compose up --build
```

4. Setup the database:
```bash
docker-compose exec app rails db:create db:migrate db:seed
```

5. Access the application:
- API: http://localhost:3000/api/v1
- ActiveAdmin: http://localhost:3000/admin

### Local Development Setup

1. Install dependencies:
```bash
bundle install
```

2. Setup database:
```bash
rails db:create db:migrate db:seed
```

3. Start the server:
```bash
bin/dev
```

## 📋 Phase 1.1 Implementation Status

✅ **Completed:**
- Rails 8 application initialization with ActiveAdmin support
- Multi-stage Dockerfile for development/production optimization
- Docker Compose configuration with PostgreSQL and Redis containers
- Database configuration for multi-tenant setup
- Redis configuration for caching and sessions
- Environment management with .env.example
- Development tools and debugging setup (Lograge, CORS, Rack::Attack)
- Project structure and essential configuration files
- API route structure preparation

## 🏛️ System Architecture

### Multi-tenancy
- Single database with company_id segregation
- All tables include company_id with composite indexing
- API requests require X-Company-ID header

### Authentication
- JWT-based authentication with refresh tokens
- Device fingerprinting for enhanced security
- Rate limiting per company and IP

### API Structure
```
/api/v1/
├── auth/          # Authentication endpoints
├── sync/          # Offline synchronization
├── companies/     # Company management
├── categories/    # Product categories
├── products/      # Product management
├── transactions/  # POS transactions
└── users/         # User management
```

## 🔧 Development Tools

- **Logging**: Lograge with JSON formatting and sensitive data redaction
- **Rate Limiting**: Rack::Attack with Redis backend
- **CORS**: Configured for React PWA integration
- **Error Handling**: Better Errors for development
- **Debugging**: Pry Rails integration

## 📊 Target Scale

- **Capacity**: 500 stores × 100 transactions/day = 50,000 daily transactions
- **Offline Support**: Timestamp-based conflict resolution with UUID transaction IDs
- **Data Retention**: Permanent transaction storage with soft delete capability
- **Localization**: Indonesian market support (Rupiah currency, Bahasa Indonesia)

## 🚢 Deployment

The application is configured for deployment with Kamal. See `config/deploy.yml` for deployment configuration.

## 📚 Next Phases

1. **Phase 1.2**: Database Architecture Design
2. **Phase 1.3**: Rails Application Foundation
3. **Phase 2**: Authentication & User Management
4. **Phase 3**: Core Business Logic
5. **Phase 4**: API Design & Integration

## 📝 License

This project is proprietary software for Indonesian POS system development.
