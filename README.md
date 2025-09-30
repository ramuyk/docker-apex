# Introduction

This repository provides a `docker-compose.yml` ready-to-use Docker configuration to simplify the deployment of Oracle APEX with Oracle Database XE. For comprehensive details about extra configurations, please refer to the [Oracle APEX official documentation](https://www.oracle.com/tools/downloads/apex-downloads/) and [Oracle Database XE documentation](https://www.oracle.com/database/technologies/appdev/xe.html).

## Repository Contents

This repository includes:

- **Docker Compose File**: A `docker-compose.yml` file that configures the Oracle APEX Docker environment. Highlights of this setup include:
  - **Persistent Data Storage**: Configures volumes for:
    - Oracle Database data storage for preserving database contents.
    - APEX and ORDS configuration files.

    This setup ensures that your APEX applications, configurations, and database data are preserved when the container is restarted.

- **Dockerfile**: Specifies the custom Oracle APEX Docker image build process. This file includes the installation of Oracle APEX 24.2, Oracle REST Data Services (ORDS), and SQL Developer Web. Feel free to modify the Dockerfile to incorporate additional components as needed.

## Getting Started

### Quick Setup

1. **Clone the Repository**:
   Clone this repository to your local machine using the following Git command:
   ```bash
   git clone git clone https://github.com/ramuyk/docker-apex.git
   cd docker-apex
   ```

2. **Build and Start Oracle APEX**:
   Use the following command to build the Oracle APEX image and start the service:
   ```bash
   docker compose up -d --build
   ```

   Note: The first run will take approximately 6-8 minutes as it installs Oracle APEX and configures ORDS.

3. **Access Oracle APEX**:
   Open a web browser and navigate to `http://localhost:8081/ords/apex` to access the APEX workspace interface. The pre-configured admin credentials are:

   - **Workspace**: INTERNAL
   - **Username**: ADMIN
   - **Password**: Welcome1

   Upon first login with these credentials, you may change them for security reasons through the APEX administration interface.

