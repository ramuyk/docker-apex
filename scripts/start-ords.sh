#!/bin/bash
#
# ORDS Startup Script
# Requires: APEX already installed, ORDS users created
# Purpose: Configure and start ORDS (no admin privileges needed)
#

set -e

echo "=========================================="
echo "Starting ORDS (No Admin Privileges Required)"
echo "=========================================="

# Configure ORDS directories
echo "Configuring ORDS..."
cd /opt

export CONFIG_DIR=/config
mkdir -p ${CONFIG_DIR}/databases/default
mkdir -p ${CONFIG_DIR}/global/doc_root

# Copy APEX static files
echo "Setting up APEX static files..."
cp -r /opt/apex/images ${CONFIG_DIR}/global/doc_root/i

# Create version files
echo "Oracle APEX Version:  24.2.0" > ${CONFIG_DIR}/global/doc_root/i/apex_version.txt
echo 'var gApexVersion = "24.2.0";' > ${CONFIG_DIR}/global/doc_root/i/apex_version.js

# Check if ORDS is already installed by checking with sys user
echo "Checking ORDS installation status..."
ORDS_INSTALLED=$(sqlplus -s sys/oracle@oracle-db:1521/XEPDB1 as sysdba <<EOF
SET PAGESIZE 0 FEEDBACK OFF VERIFY OFF HEADING OFF ECHO OFF
SELECT COUNT(*) FROM dba_users WHERE username = 'ORDS_METADATA';
EXIT;
EOF
)

ORDS_INSTALLED=$(echo "$ORDS_INSTALLED" | tr -d '[:space:]')

if [ "$ORDS_INSTALLED" = "1" ]; then
    echo "ORDS metadata already installed, skipping installation..."

    # Create pool.xml for existing installation
    cat > ${CONFIG_DIR}/databases/default/pool.xml <<EOF
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE properties SYSTEM "http://java.sun.com/dtd/properties.dtd">
<properties>
<entry key="db.hostname">oracle-db</entry>
<entry key="db.port">1521</entry>
<entry key="db.servicename">XEPDB1</entry>
<entry key="db.username">ORDS_PUBLIC_USER</entry>
<entry key="db.password">Welcome1</entry>
<entry key="jdbc.InitialLimit">3</entry>
<entry key="jdbc.MaxLimit">10</entry>
<entry key="jdbc.MinLimit">1</entry>
</properties>
EOF
else
    echo "Installing ORDS metadata in database..."

    # Clean up config to ensure fresh install
    rm -rf ${CONFIG_DIR}/databases/*

    # Try installing ORDS using SYS user (has all necessary privileges)
    set +e  # Temporarily disable exit on error
    echo -e "oracle\noracle" | /opt/bin/ords --config ${CONFIG_DIR} install \
      --admin-user sys \
      --db-hostname oracle-db \
      --db-port 1521 \
      --db-servicename XEPDB1 \
      --feature-sdw true 2>&1 | tee /tmp/ords_install.log

    INSTALL_EXIT=$?
    set -e  # Re-enable exit on error

    # Check if installation failed (either by exit code or error message)
    if [ $INSTALL_EXIT -ne 0 ] || grep -q "Error" /tmp/ords_install.log; then
        echo "==========================================="
        echo "ORDS installation failed, cleaning up completely and retrying..."
        echo "==========================================="

        # Clean up the users manually (ORDS_METADATA and ORDS_PUBLIC_USER)
        echo "Cleaning up ORDS users, schemas and roles..."
        sqlplus sys/oracle@oracle-db:1521/XEPDB1 as sysdba <<EOF
DECLARE
  user_exists NUMBER;
  role_exists NUMBER;
BEGIN
  -- Drop users
  SELECT COUNT(*) INTO user_exists FROM dba_users WHERE username = 'ORDS_PUBLIC_USER';
  IF user_exists > 0 THEN
    EXECUTE IMMEDIATE 'DROP USER ORDS_PUBLIC_USER CASCADE';
  END IF;

  SELECT COUNT(*) INTO user_exists FROM dba_users WHERE username = 'ORDS_METADATA';
  IF user_exists > 0 THEN
    EXECUTE IMMEDIATE 'DROP USER ORDS_METADATA CASCADE';
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

        # Clean up ALL config files
        echo "Cleaning up ORDS configuration files..."
        rm -rf ${CONFIG_DIR}/databases/*
        rm -f ${CONFIG_DIR}/global/settings.xml

        # Recreate directories
        mkdir -p ${CONFIG_DIR}/databases/default

        # Then reinstall fresh with SYS user
        echo "Retrying ORDS installation with clean slate using SYS user..."
        echo -e "oracle\noracle" | /opt/bin/ords --config ${CONFIG_DIR} install \
          --admin-user sys \
          --db-hostname oracle-db \
          --db-port 1521 \
          --db-servicename XEPDB1 \
          --feature-sdw true
    fi
fi

# Configure ORDS settings
cat > ${CONFIG_DIR}/global/settings.xml <<EOF
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<!DOCTYPE properties SYSTEM "http://java.sun.com/dtd/properties.dtd">
<properties>
<entry key="standalone.context.path">/ords</entry>
<entry key="standalone.doc.root">${CONFIG_DIR}/global/doc_root</entry>
<entry key="feature.sdw">true</entry>
<entry key="feature.autorest">true</entry>
<entry key="standalone.static.context.path">/i</entry>
<entry key="standalone.static.path">${CONFIG_DIR}/global/doc_root/i</entry>
</properties>
EOF

echo "ORDS configuration completed!"

# Configure APEX image prefix
echo "Configuring APEX image prefix..."
sqlplus sys/oracle@oracle-db:1521/XEPDB1 as sysdba <<EOF
ALTER SESSION SET CONTAINER = XEPDB1;

-- Configure APEX RESTful Services
BEGIN
    APEX_INSTANCE_ADMIN.SET_PARAMETER(
        p_parameter => 'IMAGE_PREFIX',
        p_value     => '/i/'
    );
    COMMIT;
END;
/

EXIT;
EOF

# Verify database connections
echo "Verifying database connections..."
if ! sqlplus -s ORDS_PUBLIC_USER/Welcome1@oracle-db:1521/XEPDB1 <<< "SELECT 'ORDS_PUBLIC_USER OK' FROM DUAL;" > /dev/null 2>&1; then
    echo "WARNING: ORDS_PUBLIC_USER connection failed"
fi

if ! sqlplus -s APEX_PUBLIC_USER/Welcome1@oracle-db:1521/XEPDB1 <<< "SELECT 'APEX_PUBLIC_USER OK' FROM DUAL;" > /dev/null 2>&1; then
    echo "ERROR: APEX_PUBLIC_USER connection failed"
    exit 1
fi

echo "Database connections verified!"

# Start ORDS
echo "Starting ORDS server..."
echo ""
echo "🎉 Oracle ORDS with APEX interface is ready!"
echo ""
echo "Access your environment at:"
echo "  ✅ ORDS Landing: http://localhost:8081/ords/_/landing"
echo "  ✅ APEX Interface: http://localhost:8081/ords/apex"
echo "  ✅ SQL Developer Web: http://localhost:8081/ords/"
echo "  ✅ Static Files: http://localhost:8081/i/"
echo ""

cd /opt
exec java -jar ords.war --config ${CONFIG_DIR} serve --port 8080