# Backend Development Guide - Indonesian POS System

## 🏗️ Technical Architecture Overview

### **Tech Stack**
- **Framework**: Ruby on Rails 8 API-only mode
- **Database**: PostgreSQL 15 with multi-tenancy (company_id approach)
- **Authentication**: JWT with short-lived access tokens + refresh tokens
- **Admin Panel**: ActiveAdmin for internal management
- **Background Jobs**: Solid Queue (Solid Trifecta - Queue, Cache, Cable)
- **Caching**: Redis for session storage and application caching
- **Monitoring**: Rails Performance (self-hosted)
- **Deployment**: Docker containerization + Kamal orchestration
- **Logging**: Lograge with sensitive data redaction

### **System Specifications**
- **Target Scale**: 500 stores × 100 transactions/day = 50,000 daily transactions
- **Multi-tenancy**: Single database with company_id segregation
- **Offline Support**: Timestamp-based conflict resolution with UUID transaction IDs
- **Data Retention**: Permanent transaction storage with soft delete capability
- **Localization**: Indonesian market support (Rupiah currency, Bahasa Indonesia)

---

## 📋 Phase 1: Foundation & Infrastructure (Week 1-2)

### **1.1 Development Environment Setup**
- **Ruby on Rails 8**: with minimal dependencies
- **Docker Configuration**: Multi-stage Dockerfile for development/production optimization
- **Database Setup**: PostgreSQL container with persistent volume mounting
- **Redis Configuration**: Cache and session storage container
- **Environment Management**: Secure environment variable handling with Docker secrets
- **Development Tools**: Hot reload configuration, debugging setup, log aggregation

### **1.2 Database Architecture Design**
- **Multi-tenant Schema**: All tables include company_id with composite indexing for performance
- **Core Entities**: Companies, Users, Categories, Products, Transactions, Transaction Items
- **Audit System**: Comprehensive audit logging for all data modifications
- **Soft Delete Implementation**: Logical deletion with deleted_at timestamps
- **Sync Management**: Dedicated tables for tracking offline synchronization status
- **Receipt System**: Configurable HTML templates stored in database with caching

### **1.3 Rails Application Foundation**
- **CORS Setup**: Secure cross-origin configuration for React PWA integration
- **Rate Limiting**: Company-scoped API rate limiting with rack-attack
- **Security Headers**: Comprehensive security header configuration
- **Monitoring Integration**: Rails Performance gem setup for application metrics

---

## 📋 Phase 2: Authentication & User Management (Week 3-4)

### **2.1 JWT Authentication System**
- **Token Strategy**: 15-minute access tokens with 30-day refresh tokens
- **Security Implementation**: SHA256 token hashing with device fingerprinting
- **Token Management**: Database storage of token hashes with automatic cleanup
- **Company Scoping**: Authentication tokens scoped to specific companies
- **Device Tracking**: Multiple device support with individual token revocation

### **2.2 User Role Management**
- **Role Hierarchy**: Cashier (basic POS), Manager (inventory + reports), Owner (full access)
- **Permission System**: Granular permissions for transaction voids, price overrides, reports
- **Company Association**: Users strictly bound to single company contexts
- **Session Management**: Secure session handling with automatic expiration
- **Audit Trail**: Complete user action logging for security compliance

### **2.3 ActiveAdmin Setup**
- **Admin Interface**: Internal management dashboard for system administrators
- **Company Management**: Store onboarding, configuration, and monitoring tools
- **User Administration**: Account management, role assignment, access control
- **System Monitoring**: Real-time metrics, transaction volumes, sync status dashboards
- **Report Generation**: Business intelligence reports for operational insights

---

## 📋 Phase 3: Core Business Logic (Week 5-6)

### **3.1 Product & Inventory Management**
- **Category System**: Hierarchical product categorization with image support
- **Product Variants**: Flexible variant system (Size, Color, etc.) with JSON storage
- **Inventory Tracking**: Real-time stock levels with configurable minimum thresholds
- **Pricing Management**: Company-specific pricing with historical price tracking
- **Stock Alerts**: Automated low-stock notifications for inventory management

### **3.2 Transaction Processing**
- **Transaction Lifecycle**: Complete POS transaction flow from cart to completion
- **Payment Methods**: Cash payment support with change calculation
- **Tax Calculation**: Indonesian PPN (11%) tax computation with configurable rates
- **Receipt Generation**: HTML-based receipt templates with company customization
- **Transaction Numbering**: Date-based sequential numbering with company scoping

### **3.3 Offline Data Sync Architecture**
- **Bulk Sync Endpoints**: Efficient batch processing for offline transaction uploads
- **Conflict Resolution**: Server-timestamp-wins strategy for data consistency
- **Delta Sync**: Incremental synchronization based on last_updated_at timestamps
- **Sync Status Tracking**: Comprehensive logging of sync operations and failures
- **Data Validation**: Server-side validation of offline-created transactions

---

## 📋 Phase 4: API Design & Integration (Week 7-8)

### **4.1 RESTful API Structure**
- **Versioned Endpoints**: URL-based versioning (/api/v1/) for future compatibility
- **Resource Organization**: Logical grouping of endpoints by business domain
- **Bulk Operations**: Specialized endpoints for batch data synchronization
- **Filtering & Pagination**: Cursor-based pagination for large dataset handling
- **Response Formatting**: Consistent JSON response structure with error handling

### **4.2 Sync API Specifications**
- **Transaction Sync**: POST /api/v1/sync/transactions for bulk offline transaction upload
- **Data Delta**: GET /api/v1/sync/delta for incremental data synchronization
- **Full Refresh**: POST /api/v1/sync/full for complete data reinitialization
- **Sync Status**: GET /api/v1/sync/status for real-time synchronization monitoring
- **Conflict Resolution**: Automated handling of timestamp-based data conflicts

### **4.3 Performance Optimization**
- **Database Indexing**: Composite indexes on company_id + frequently queried fields
- **Query Optimization**: N+1 query prevention with eager loading strategies
- **Caching Strategy**: Redis-based caching for expensive analytics queries
- **Background Processing**: Async job processing for heavy operations
- **Response Compression**: Gzip compression for large sync payloads

---

## 📋 Phase 5: Security & Compliance (Week 9-10)

### **5.1 Data Security Implementation**
- **Input Validation**: Comprehensive parameter sanitization and validation
- **SQL Injection Prevention**: Parameterized queries and whitelist filtering
- **Authentication Security**: JWT token security with device fingerprinting
- **Rate Limiting**: Progressive rate limiting based on user behavior patterns
- **Audit Logging**: Complete audit trail for compliance and security monitoring

### **5.2 Indonesian Market Compliance**
- **Currency Handling**: Rupiah formatting with proper decimal precision
- **Tax Calculations**: PPN tax compliance with configurable tax rates
- **Receipt Requirements**: Indonesian receipt format compliance
- **Data Retention**: Business record keeping requirements
- **Localization Support**: Bahasa Indonesia language support infrastructure

### **5.3 Logging & Monitoring**
- **Sensitive Data Redaction**: Automatic PII removal from application logs
- **Performance Monitoring**: Rails Performance dashboard with key metrics
- **Error Tracking**: Comprehensive error logging with context preservation
- **Business Metrics**: Transaction volume, sync success rates, system health
- **Alert System**: Automated alerts for system failures and business anomalies

---

## 📋 Phase 6: Background Jobs & Processing (Week 11-12)

### **6.1 Solid Queue Implementation**
- **Job Processing**: Reliable background job processing with retry mechanisms
- **Sync Operations**: Async processing of bulk data synchronization
- **Report Generation**: Background report generation for analytics dashboards
- **Data Cleanup**: Automated cleanup of expired tokens and audit logs
- **Notification System**: Background processing of system notifications

### **6.2 Scheduled Operations**
- **Data Archival**: Automated archiving of old transaction data
- **Cache Warming**: Scheduled cache warming for frequently accessed data
- **Backup Operations**: Automated database backup scheduling
- **Metric Aggregation**: Periodic calculation of business metrics
- **Health Checks**: Automated system health monitoring and reporting

---

## 📋 Phase 7: Testing & Quality Assurance (Week 13-14)

### **7.1 Testing Strategy**
- **Unit Testing**: Comprehensive model and service testing with RSpec
- **Integration Testing**: API endpoint testing with realistic data scenarios
- **Performance Testing**: Load testing for 50K+ daily transaction volumes
- **Security Testing**: Penetration testing and vulnerability assessment
- **Multi-tenancy Testing**: Data isolation and company scoping validation

### **7.2 Data Integrity Validation**
- **Sync Testing**: Offline/online synchronization scenario testing
- **Conflict Resolution Testing**: Data conflict handling validation
- **Transaction Integrity**: Financial calculation accuracy verification
- **Audit Trail Verification**: Complete audit logging validation
- **Backup Recovery Testing**: Disaster recovery procedure validation

---

## 📋 Phase 8: Deployment & Production Setup (Week 15-16)

### **8.1 Production Infrastructure**
- **Kamal Deployment**: Automated deployment orchestration with zero-downtime
- **Container Optimization**: Production-optimized Docker images with security hardening
- **Database Migration**: Safe production database migration strategies
- **SSL/TLS Configuration**: Secure HTTPS communication setup
- **Backup Strategy**: Automated daily backups with retention policies

### **8.2 Production Monitoring**
- **Application Monitoring**: Rails Performance dashboard deployment
- **Infrastructure Monitoring**: Server resource monitoring and alerting
- **Business Metrics Dashboard**: Real-time business performance tracking
- **Error Alerting**: Automated error notification and escalation
- **Performance Alerting**: Response time and throughput monitoring

### **8.3 Launch Preparation**
- **Production Data Seeding**: Initial company and user data setup
- **Performance Validation**: Production load testing and optimization
- **Security Hardening**: Final security configuration and validation
- **Documentation**: Complete API documentation and operational guides
- **Support Infrastructure**: Monitoring dashboards and troubleshooting guides

---

## 🎯 Key Deliverables

### **Infrastructure**
- ✅ Dockerized development and production environments
- ✅ PostgreSQL database with optimized multi-tenant schema
- ✅ Redis caching layer with session management
- ✅ Kamal deployment configuration with automated CI/CD

### **Core Application**
- ✅ JWT-based authentication with refresh token support
- ✅ Multi-tenant POS transaction processing system
- ✅ Offline-first data synchronization architecture
- ✅ ActiveAdmin dashboard for system management

### **API Layer**
- ✅ RESTful API with versioning and bulk operations
- ✅ Comprehensive sync endpoints with conflict resolution
- ✅ Rate limiting and security middleware
- ✅ Indonesian market localization support

### **Monitoring & Operations**
- ✅ Rails Performance monitoring dashboard
- ✅ Comprehensive audit logging and security tracking
- ✅ Automated backup and disaster recovery procedures
- ✅ Production-ready error handling and alerting

This backend architecture will efficiently support 500 Indonesian restaurants/UMKM stores with robust offline capabilities, comprehensive security, and scalable performance for future growth.