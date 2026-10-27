# db/multi

Base image with unixODBC and ODBC drivers, used by
[dataport](https://github.com/rakunlabs/dataport).

```sh
docker pull ghcr.io/rakunlabs/dock/db/multi:v0.2.0
```

Drivers registered in `/etc/odbcinst.ini`:

| Database | Driver name | Source |
| --- | --- | --- |
| IBM DB2 | `DB2` | IBM Data Server Driver for ODBC and CLI |
| SQL Server | `ODBC Driver 18 for SQL Server` | Microsoft `msodbcsql18` |
| PostgreSQL | `PostgreSQL Unicode`, `PostgreSQL ANSI` | Debian `odbc-postgresql` |
| MySQL / MariaDB | `MariaDB Unicode` | Debian `odbc-mariadb` |

Use them in a connection string, e.g. `Driver={DB2};Hostname=db2;Port=50000;Database=sample;Protocol=TCPIP`.

## Adding Ingres

The Actian Client (Ingres ODBC driver) is not part of this image, as its
license does not allow redistribution. If you have an Actian license, add it
in your own image on top of this one (or on top of `ghcr.io/rakunlabs/dataport`).

Get `actian-client-<version>-linux-ingbuild-x86_64.tgz` from
[Actian ESD](https://esd.actian.com/) and put it next to this Dockerfile:

```dockerfile
FROM debian:13.7-slim AS actian

# The installer calls sudo
RUN apt-get update && apt-get install --no-install-recommends -y sudo

COPY actian-client-*-linux-ingbuild-x86_64.tgz /tmp/
RUN tar -xzf /tmp/actian-client-*.tgz -C /tmp && \
    /tmp/actian-client-*/client_install.sh -express -user root XZ /opt/actian && \
    cd /opt/actian/ingres && \
    rm -rf demo bin install utility sig files/name files/rcfiles files/ocf \
    lib/iijdbc.jar lib/edbc.jar lib/JdbcInfo.class lib/libx100.so.0

# or ghcr.io/rakunlabs/dataport:<tag>
FROM ghcr.io/rakunlabs/dock/db/multi:v0.2.0

USER root

COPY --from=actian /opt/actian /opt/actian

ENV II_SYSTEM=/opt/actian \
    II_ODBC_WCHAR_SIZE=2 \
    LD_LIBRARY_PATH=/opt/actian/ingres/lib:$LD_LIBRARY_PATH

RUN printf '[Ingres]\nDriver=/opt/actian/ingres/lib/libiiodbcdriver.1.so\nDriverODBCVer=3.50\nDriverReadOnly=N\nDriverType=Ingres\nVendor=Actian Corporation\nDontDlClose=1\n' > /tmp/ingres.template && \
    odbcinst -i -d -f /tmp/ingres.template && rm /tmp/ingres.template

# for the dataport image, switch back to its user
# USER dataport
```

```sh
docker build -t my/db-multi-ingres .
```

Connect with `Driver={Ingres};Server=<host>;Port=II7;Database=<db>`
(`Port` is the instance id, `II7` by default).
