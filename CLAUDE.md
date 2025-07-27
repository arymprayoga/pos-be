# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A Ruby on Rails 8 backend for a Point of Sale system designed for Indonesian restaurants and UMKM stores. Features offline-first capabilities with JWT authentication and multi-tenancy support targeting 500 stores × 100 transactions/day.

## Essential Commands

### Development
- `bin/dev` - Start development server with foreman (Rails + Tailwind watch)
- `docker-compose up --build` - Start with Docker containers (recommended)
- `docker-compose exec app bash` - Access app container shell

### Database
- `rails db:create db:migrate db:seed` - Setup database
- `docker-compose exec app rails db:create db:migrate db:seed` - Setup with Docker

### Testing & Quality
- `bundle exec rspec` - Run all tests
- `bundle exec rspec spec/models` - Run model tests only
- `bundle exec rubocop` - Code style checks (omakase Ruby style)
- `bundle exec rubocop -a` - Auto-fix style issues
- `bundle exec brakeman` - Security vulnerability scan

## Architecture

### Multi-Tenancy
- All models segregated by `company_id`
- API requires `X-Company-ID` header
- Base controller: `Api::V1::BaseController` handles tenant scoping

### Database Design
- UUID primary keys on all tables (`uuid-ossp` extension)
- Model-only relationships (no database foreign keys)
- Soft deletes via `deleted_at` timestamps
- Audit trails with `created_by`/`updated_by` UUID tracking
- Offline sync support with `sync_id` fields

### API Structure
- Base URL: `/api/v1/`
- JWT authentication with refresh tokens
- Endpoints:
  - `/auth/*` - Authentication (login, refresh, logout)
  - `/sync/*` - Offline synchronization
  - Planned: companies, categories, products, transactions, users

### Core Models
- Companies (tenants)
- Users (with company_id scoping)
- Categories → Items → Inventories
- Sales Orders → Sales Order Items
- Payment Methods, Taxes, Inventory Ledgers

## Technology Stack
- Ruby 3.4.2, Rails 8
- PostgreSQL 15 with multi-tenancy
- Redis 7 for caching/sessions
- Solid Trifecta (Queue, Cache, Cable)
- ActiveAdmin for management interface
- Docker + Kamal deployment

## Code Style
- Follows `rubocop-rails-omakase` (Rails team's omakase Ruby styling)
- API controllers under `app/controllers/api/v1/`
- Models inherit from `ApplicationRecord` with multi-tenant support
- JSON responses with consistent error handling

## Development Tools & Rules
- **File Searching**: Always use Serena (MCP tool) for searching files, symbols, and code patterns
- **Security Scanning**: Always use Semgrep for vulnerability detection and security analysis
- Prefer symbolic operations (find_symbol, find_referencing_symbols) over basic text searches
- Use targeted searches with proper file type filtering for efficiency

## Key Access Points
- API: http://localhost:3000/api/v1
- ActiveAdmin: http://localhost:3000/admin
- Health Check: http://localhost:3000/up

## Current Status
Phase 1.2 completed - Database architecture with UUID primary keys and multi-tenant schema implemented. Ready for Rails application foundation development.