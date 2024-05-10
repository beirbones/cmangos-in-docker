FROM ubuntu:22.04

ARG DEBIAN_FRONTEND="noninteractive"

ARG TZ="Etc/UTC"
# Install required dependencies for CMaNGOS to run on ubuntu
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
            tzdata \
    && ln -snf "/usr/share/zoneinfo/${TZ}" /etc/localtime \
    && echo "${TZ}" > /etc/timezone \
    && dpkg-reconfigure --frontend noninteractive tzdata \
    \
    && apt-get install -y --no-install-recommends \
            build-essential \
            ca-certificates \
            cmake \
            g++-12 \
            git-core \
            libboost-filesystem-dev \
            libboost-program-options-dev \
            libboost-regex-dev \
            libboost-serialization-dev \
            libboost-system-dev \
            libboost-thread-dev \
            libmariadb-dev-compat \
            libssl-dev \
            mariadb-client \
            screen \
    \
    && update-alternatives --install /usr/bin/gcc gcc \
                                        /usr/bin/gcc-12 12 \
                            --slave /usr/bin/g++ g++ \
            /usr/bin/g++-12 \
    \
    && rm -rf /var/lib/apt/lists/* \
                /tmp/*

# Allows user to pick specific expansion they would like to install
ENV EXPANSION="tbc"
# Allows users to set the MariaDB root password for security
ENV MARIADB_ROOT_PASSWORD="root"
# Allows users to set the Mangos MariaDB user password for security
ENV MARIADB_MANGOS_USER_PASSWORD="mangos"
ARG HOME_DIR="/home/mangos"
# Allows user to set container name for multi-db setups (mariadb_tbc, mariadb_classic etc)
ENV MARIADB_CONTAINER_NAME="mariadb"
ENV AHBOT="ON"
ENV PLAYERBOTS="ON"
ENV REALM_NAME="CMaNGOS-in-docker"
ENV IP_ADDRESS="127.0.0.1"
ENV CORE_COMMIT_ID=null
ENV DB_COMMIT_ID=null
ENV DBBACKUPS="ON"

EXPOSE 3724 8085

RUN useradd --comment "MaNGOS" --create-home --user-group mangos --home-dir "${HOME_DIR}"
COPY healthcheck.sh /usr/local/bin/healthcheck.sh
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
CMD ["sh", "-c", "entrypoint.sh $EXPANSION $MARIADB_ROOT_PASSWORD $MARIADB_MANGOS_USER_PASSWORD $MARIADB_CONTAINER_NAME $AHBOT $PLAYERBOTS $REALM_NAME $IP_ADDRESS $CORE_COMMIT_ID $DB_COMMIT_ID $DBBACKUPS"]
