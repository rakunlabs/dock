FROM debian:13.7-slim AS download

RUN apt-get update && apt-get install --no-install-recommends -y \
    ca-certificates curl unzip sudo

# Microsoft repository and signing key for msodbcsql18
RUN curl -fsSL https://packages.microsoft.com/config/debian/13/packages-microsoft-prod.deb -o /packages-microsoft-prod.deb

# IBM DB2 CLI/ODBC driver
RUN curl -fsSL https://public.dhe.ibm.com/ibmdl/export/pub/software/data/db2/drivers/odbc_cli/linuxx64_odbc_cli.tar.gz | tar -xz -C /

# Actian Client (Ingres ODBC driver), shipped inside Actian's PyPI package
ARG ACTIAN_WHEEL_URL=https://files.pythonhosted.org/packages/a4/c7/091ff7b1079afb63cd2e609756ce61fe831454e457a51b3c267c6b1ef88d/actian_analytics_odbc-1.0.0-py3-none-manylinux2014_x86_64.whl
ARG ACTIAN_WHEEL_SHA256=ce27089dce88e6d7309d7c621b6984fe424a296aa4a5089840ef1f8373eb460e
RUN curl -fsSL ${ACTIAN_WHEEL_URL} -o /tmp/actian.whl && \
    echo "${ACTIAN_WHEEL_SHA256}  /tmp/actian.whl" | sha256sum -c - && \
    unzip -q -j /tmp/actian.whl 'actiandb/binaries/actian-client-*.tgz' -d /tmp && \
    tar -xzf /tmp/actian-client-*.tgz -C /tmp && \
    /tmp/actian-client-*/client_install.sh -express -user root XZ /opt/actian && \
    cd /opt/actian/ingres && \
    rm -rf demo bin install utility sig files/name files/rcfiles files/ocf \
    lib/iijdbc.jar lib/edbc.jar lib/JdbcInfo.class lib/libx100.so.0

FROM debian:13.7-slim

RUN apt-get update && apt-get install --no-install-recommends -y \
    ca-certificates tzdata unixodbc odbcinst libxml2 \
    odbc-postgresql odbc-mariadb

COPY --from=download /packages-microsoft-prod.deb /tmp/packages-microsoft-prod.deb

RUN dpkg -i /tmp/packages-microsoft-prod.deb && rm /tmp/packages-microsoft-prod.deb && \
    apt-get update && \
    ACCEPT_EULA=Y apt-get install --no-install-recommends -y msodbcsql18 && \
    rm -rf /var/lib/apt/lists/*

## Ingres PART
COPY --from=download /opt/actian /opt/actian

# required by Ingres ODBC and timezone information for connection and local
ENV II_SYSTEM=/opt/actian \
    II_ODBC_WCHAR_SIZE=2 \
    LD_LIBRARY_PATH=/opt/actian/ingres/lib

# II_TIMEZONE_NAME=GMT ## dont set this use default
# TZ=UTC ## dont set this use default timezone of the base image

RUN printf '[Ingres]\nDriver=/opt/actian/ingres/lib/libiiodbcdriver.1.so\nDriverODBCVer=3.50\nDriverReadOnly=N\nDriverType=Ingres\nVendor=Actian Corporation\nDontDlClose=1\n' > /tmp/ingres.template && \
    odbcinst -i -d -f /tmp/ingres.template && rm /tmp/ingres.template

## DB2 PART
COPY --from=download /clidriver /opt/ibm/clidriver
RUN printf '[DB2]\nDescription=IBM DB2 ODBC Driver\nDriver=/opt/ibm/clidriver/lib/libdb2.so\nFileUsage=1\nDontDlClose=1\n' > /tmp/db2.template && \
    odbcinst -i -d -f /tmp/db2.template && rm /tmp/db2.template

ENV DB2_CLI_DRIVER_INSTALL_PATH=/opt/ibm/clidriver \
    LD_LIBRARY_PATH=/opt/ibm/clidriver/lib:$LD_LIBRARY_PATH
