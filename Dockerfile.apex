FROM container-registry.oracle.com/os/oraclelinux:8

# Install required packages
RUN dnf update -y && dnf install -y \
    unzip \
    wget \
    curl \
    java-17-openjdk \
    oracle-instantclient-release-23ai-el8 \
    && dnf install -y oracle-instantclient-basic oracle-instantclient-sqlplus \
    && dnf clean all

ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk
ENV PATH="/opt:$PATH"

WORKDIR /opt

COPY apex_24.2.zip .
RUN unzip apex_24.2.zip && rm apex_24.2.zip

# Download and install Oracle REST Data Services (ORDS) latest
RUN wget https://download.oracle.com/otn_software/java/ords/ords-latest.zip -O ords.zip && \
    unzip ords.zip && \
    rm ords.zip && \
    mkdir -p /opt/ords/config && \
    chmod +x /opt/bin/ords

# Create installation scripts directory
RUN mkdir -p /opt/scripts

# Copy installation and configuration scripts
COPY scripts/ /opt/scripts/
RUN chmod +x /opt/scripts/*.sh

EXPOSE 8080

ENTRYPOINT ["/opt/scripts/entrypoint.sh"]