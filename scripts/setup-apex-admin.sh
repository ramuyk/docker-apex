#!/bin/bash
#
# APEX Admin Setup Script
# Requires: SYS/SYSDBA privileges on the target database
# Purpose: Install APEX, create users, configure database
#

set -e

echo "=========================================="
echo "APEX Admin Setup (Requires DBA Privileges)"
echo "=========================================="

# Wait for Oracle database to be ready
echo "Waiting for Oracle Database to be ready..."
while ! sqlplus -s system/oracle@oracle-db:1521/XEPDB1 <<< "SELECT 1 FROM DUAL;" > /dev/null 2>&1; do
    echo "Database not ready, waiting 10 seconds..."
    sleep 10
done

echo "Oracle Database XEPDB1 is ready!"

# Check if APEX is already installed
echo "Checking if Oracle APEX is installed..."
APEX_INSTALLED=$(sqlplus -s sys/oracle@oracle-db:1521/XEPDB1 as sysdba <<EOF
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF
SELECT COUNT(*) FROM dba_users WHERE username = 'APEX_240200';
EXIT;
EOF
)

APEX_INSTALLED=$(echo "$APEX_INSTALLED" | tr -d '[:space:]')

if [ "$APEX_INSTALLED" = "0" ]; then
    echo "==========================================="
    echo "Installing Oracle APEX 24.2 into database..."
    echo "==========================================="

    cd /opt/apex

    # Install APEX core
    sqlplus sys/oracle@oracle-db:1521/XEPDB1 as sysdba <<EOF
@apexins.sql SYSAUX SYSAUX TEMP /i/
EXIT;
EOF

    # Unlock APEX accounts and set passwords
    echo "Configuring APEX Admin user..."
    sqlplus sys/oracle@oracle-db:1521/XEPDB1 as sysdba <<EOF
ALTER SESSION SET CONTAINER = XEPDB1;

-- Set APEX admin password
BEGIN
    APEX_UTIL.SET_WORKSPACE('INTERNAL');
    APEX_UTIL.CREATE_USER(
        p_user_name => 'ADMIN',
        p_email_address => 'admin@localhost',
        p_web_password => 'Welcome1',
        p_change_password_on_first_use => 'N',
        p_developer_privs => 'ADMIN:CREATE:DATA_LOADER:EDIT:HELP:MONITOR:SQL'
    );
    COMMIT;
END;
/
EXIT;
EOF

    # Configure APEX instance settings
    echo "Configuring APEX instance..."
    sqlplus sys/oracle@oracle-db:1521/XEPDB1 as sysdba <<EOF
ALTER SESSION SET CONTAINER = XEPDB1;

BEGIN
    APEX_INSTANCE_ADMIN.SET_PARAMETER('SMTP_HOST_ADDRESS', 'localhost');
    APEX_INSTANCE_ADMIN.SET_PARAMETER('SMTP_HOST_PORT', 25);
    COMMIT;
END;
/
EXIT;
EOF

    echo "Oracle APEX installation completed!"
else
    echo "Oracle APEX is already installed, skipping installation..."
fi

# Ensure APEX_PUBLIC_USER is unlocked (APEX installs it locked by default)
echo "Unlocking APEX_PUBLIC_USER account..."
sqlplus sys/oracle@oracle-db:1521/XEPDB1 as sysdba <<EOF
ALTER USER APEX_PUBLIC_USER ACCOUNT UNLOCK;
COMMIT;
EXIT;
EOF

# Clean up any previous ORDS installation
echo "Cleaning up previous ORDS installation..."
sqlplus sys/oracle@oracle-db:1521/XEPDB1 as sysdba <<EOF
DECLARE
  user_exists NUMBER;
  role_exists NUMBER;
BEGIN
  -- Drop ORDS metadata schema if exists
  SELECT COUNT(*) INTO user_exists FROM dba_users WHERE username = 'ORDS_METADATA';
  IF user_exists > 0 THEN
    EXECUTE IMMEDIATE 'DROP USER ORDS_METADATA CASCADE';
  END IF;

  -- Drop ORDS_PUBLIC_USER if exists
  SELECT COUNT(*) INTO user_exists FROM dba_users WHERE username = 'ORDS_PUBLIC_USER';
  IF user_exists > 0 THEN
    EXECUTE IMMEDIATE 'DROP USER ORDS_PUBLIC_USER CASCADE';
  END IF;

  -- Drop APEX_PUBLIC_USER if exists
  SELECT COUNT(*) INTO user_exists FROM dba_users WHERE username = 'APEX_PUBLIC_USER';
  IF user_exists > 0 THEN
    EXECUTE IMMEDIATE 'DROP USER APEX_PUBLIC_USER CASCADE';
  END IF;

  -- Drop APEX_LISTENER if exists
  SELECT COUNT(*) INTO user_exists FROM dba_users WHERE username = 'APEX_LISTENER';
  IF user_exists > 0 THEN
    EXECUTE IMMEDIATE 'DROP USER APEX_LISTENER CASCADE';
  END IF;

  -- Drop APEX_REST_PUBLIC_USER if exists
  SELECT COUNT(*) INTO user_exists FROM dba_users WHERE username = 'APEX_REST_PUBLIC_USER';
  IF user_exists > 0 THEN
    EXECUTE IMMEDIATE 'DROP USER APEX_REST_PUBLIC_USER CASCADE';
  END IF;

  -- Drop ORDS roles
  SELECT COUNT(*) INTO role_exists FROM dba_roles WHERE role = 'ORDS_ADMINISTRATOR_ROLE';
  IF role_exists > 0 THEN
    EXECUTE IMMEDIATE 'DROP ROLE ORDS_ADMINISTRATOR_ROLE';
  END IF;

  SELECT COUNT(*) INTO role_exists FROM dba_roles WHERE role = 'ORDS_RUNTIME_ROLE';
  IF role_exists > 0 THEN
    EXECUTE IMMEDIATE 'DROP ROLE ORDS_RUNTIME_ROLE';
  END IF;
END;
/
COMMIT;
EXIT;
EOF

# Grant necessary privileges to SYSTEM user for ORDS installation
echo "Granting privileges to SYSTEM user..."
sqlplus sys/oracle@oracle-db:1521/XEPDB1 as sysdba <<EOF
-- Grant necessary privileges to SYSTEM for ORDS installation
GRANT CREATE USER, ALTER USER, DROP USER TO SYSTEM;
GRANT CREATE SESSION TO SYSTEM WITH ADMIN OPTION;
GRANT SELECT ANY DICTIONARY TO SYSTEM;
GRANT EXECUTE ON DBMS_LOCK TO SYSTEM;
GRANT UNLIMITED TABLESPACE TO SYSTEM;

-- Grant additional privileges needed for ORDS
GRANT ALTER ANY TABLE TO SYSTEM;
GRANT CREATE ANY TABLE TO SYSTEM;
GRANT DROP ANY TABLE TO SYSTEM;
GRANT CREATE ANY INDEX TO SYSTEM;
GRANT DROP ANY INDEX TO SYSTEM;
GRANT CREATE ANY SYNONYM TO SYSTEM;
GRANT CREATE PUBLIC SYNONYM TO SYSTEM;
GRANT DROP PUBLIC SYNONYM TO SYSTEM;
GRANT CREATE ANY VIEW TO SYSTEM;
GRANT DROP ANY VIEW TO SYSTEM;
GRANT CREATE ANY PROCEDURE TO SYSTEM;
GRANT DROP ANY PROCEDURE TO SYSTEM;
GRANT CREATE ANY SEQUENCE TO SYSTEM;
GRANT DROP ANY SEQUENCE TO SYSTEM;
GRANT CREATE ANY TRIGGER TO SYSTEM;
GRANT DROP ANY TRIGGER TO SYSTEM;

COMMIT;
EXIT;
EOF

# Create ORDS users
echo "Creating ORDS database users..."
sqlplus sys/oracle@oracle-db:1521/XEPDB1 as sysdba <<EOF
-- Create ORDS_PUBLIC_USER
CREATE USER ORDS_PUBLIC_USER IDENTIFIED BY Welcome1 ACCOUNT UNLOCK;
GRANT CONNECT, RESOURCE TO ORDS_PUBLIC_USER;
GRANT UNLIMITED TABLESPACE TO ORDS_PUBLIC_USER;

-- Create APEX_PUBLIC_USER
CREATE USER APEX_PUBLIC_USER IDENTIFIED BY Welcome1 ACCOUNT UNLOCK;
GRANT CONNECT, CREATE SESSION TO APEX_PUBLIC_USER;
GRANT EXECUTE ON SYS.OWA_UTIL TO APEX_PUBLIC_USER;
GRANT EXECUTE ON SYS.HTP TO APEX_PUBLIC_USER;
GRANT EXECUTE ON SYS.HTF TO APEX_PUBLIC_USER;

COMMIT;
EXIT;
EOF

echo "=========================================="
echo "✅ Admin setup completed successfully!"
echo "=========================================="