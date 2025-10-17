@echo off
echo ===============================================
echo AIRP v2.0 - Database Initialization
echo ===============================================
echo.

REM Check if PostgreSQL container is running
echo [1/4] Checking PostgreSQL container...
docker ps --filter "name=airp-postgres" --format "{{.Names}}" > nul 2>&1
if errorlevel 1 (
    echo X PostgreSQL container not running!
    echo    Run: docker compose -f docker-compose.dev.yml up -d postgres
    exit /b 1
)

echo V PostgreSQL container is running
echo.

echo [2/4] Waiting for PostgreSQL to be ready...
timeout /t 5 /nobreak > nul

docker exec airp-postgres pg_isready -U airp_admin -d airp_master > nul 2>&1
if errorlevel 1 (
    echo Waiting for PostgreSQL to start...
    timeout /t 3 /nobreak > nul
)

echo V PostgreSQL is ready
echo.

echo [3/4] Loading database schema...
docker cp C:\Dev\AIRP2\schemas\sql\ddl.sql airp-postgres:/tmp/ddl.sql
docker exec airp-postgres psql -U airp_admin -d airp_master -f /tmp/ddl.sql

if errorlevel 1 (
    echo X Failed to load schema
    exit /b 1
)

echo V Database schema loaded successfully
echo.

echo [4/4] Creating test data...

REM Test data will be loaded via PowerShell script
powershell -ExecutionPolicy Bypass -File "C:\Dev\AIRP2\scripts\init-database.ps1"

echo.
echo ===============================================
echo V Database initialization complete!
echo ===============================================
echo.
