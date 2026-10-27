FROM debian:13.7-slim AS download

RUN apt-get update && apt-get install --no-install-recommends -y \
    ca-certificates curl

# Microsoft repository and signing key for msodbcsql18
RUN curl -fsSL https://packages.microsoft.com/config/debian/13/packages-microsoft-prod.deb -o /packages-microsoft-prod.deb

# IBM DB2 CLI/ODBC driver
RUN curl -fsSL https://public.dhe.ibm.com/ibmdl/export/pub/software/data/db2/drivers/odbc_cli/linuxx64_odbc_cli.tar.gz | tar -xz -C /

FROM debian:13.7-slim

RUN apt-get update && apt-get install --no-install-recommends -y \
    ca-certificates tzdata unixodbc odbcinst libxml2 \
    odbc-postgresql odbc-mariadb

COPY --from=download /packages-microsoft-prod.deb /tmp/packages-microsoft-prod.deb

RUN dpkg -i /tmp/packages-microsoft-prod.deb && rm /tmp/packages-microsoft-prod.deb && \
    apt-get update && \
    ACCEPT_EULA=Y apt-get install --no-install-recommends -y msodbcsql18 && \
    rm -rf /var/lib/apt/lists/*

## DB2 PART
COPY --from=download /clidriver /opt/ibm/clidriver
RUN printf '[DB2]\nDescription=IBM DB2 ODBC Driver\nDriver=/opt/ibm/clidriver/lib/libdb2.so\nFileUsage=1\nDontDlClose=1\n' > /tmp/db2.template && \
    odbcinst -i -d -f /tmp/db2.template && rm /tmp/db2.template

ENV DB2_CLI_DRIVER_INSTALL_PATH=/opt/ibm/clidriver \
    LD_LIBRARY_PATH=/opt/ibm/clidriver/lib
