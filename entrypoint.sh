#!/bin/bash
set -o errexit   # abort on nonzero exitstatus
#set -o nounset   # abort on unbound variable
set -o pipefail  # don't hide errors within pipes
#Variables pulled from Dockerfile defaults or overridden by environment variables in docker compose and validations
expansion=$(echo "${1}" | tr '[:upper:]' '[:lower:]') ## Make Lowercase # Allows user to pick specific expansion they would like to install # check if one of available expansions?
mariadb_root_password=${2} # Allows users to set the MariaDB root password for security
mariadb_mangos_user_password=${3} # Allows users to set the Mangos MariaDB user password for security
mariadb_container_name=${4} # Allows user to set container name for multi-db setups (mariadb_tbc, mariadb_classic etc)
ahbot=$(echo "${5}" | tr '[:upper:]' '[:lower:]') # Allows user to select use of AHBOT
playerbots=$(echo "${6}" | tr '[:upper:]' '[:lower:]') # Allows user to select use of Playerbots
realm_name=${7}
ip_address=${8} # require to be a longdecimal?
core_commit_id=${9} # allows users to select a specific core commit to build with
db_commit_id=${10} # allows users to select a specific core commit to build with
dbbackups=$(echo "${11}" | tr '[:upper:]' '[:lower:]')
dbbackups_totalcount=${12}
fullbackups_totalcount=${13}

home_dir="/home/mangos"
work_dir="$home_dir/cmangos-$expansion"
mangos_dir="$work_dir/mangos-$expansion"
database_dir="$work_dir/$expansion-db"

function echo_success () {
    echo -e "\e[1;32mSUCCESS: $1\e[0m"
}
function echo_error () {
    echo -e "\e[31;1mERROR: $1\e[0m"
}
function echo_bold () {
    echo -e "\e[1m$1\e[0m"
}
function echo_successflashingdots () {
    echo -e "\e[1m$1\e[0m\e[5m...\e[0m"
}
function echo_orangeinfo () {
   echo -e "\e[1;38;5;208m$1\e[0m"
}
function datavalidation () {
   # if [ "${expansion}" != "tbc" ] || [ "${expansion}" != tbc ] || [ "${expansion}" != "classic" ] || [ "${expansion}" != classic ] || [ "${expansion}" != "wotlk" ] || [ "${expansion}" != wotlk ] 
    #then
        #echo_error "Expansion name is incorrect, available options are -:"
        #echo_error "tbc"
        #echo_error "classic"
        #echo_error "wotlk"
        #echo_error "Please choose one of these options and try again." && exit 1
    #fi
    if [[ "${mariadb_root_password}" == *[^[:alnum:]]* ]]
    then
        echo_error "mariadb root password cannot contain special characters, please change this and try again." && exit 1
    fi
    if [ "${core_commit_id}" != null ] || [ "${core_commit_id}" != "null" ]
    then
        if [ "${#core_commit_id}" != 40 ] || [[ "${core_commit_id}" == *[^[:alnum:]]* ]]
        then
            echo_error "git commit id is not the correct length, or contains special characters.. please correct this." && exit 1
        fi
    fi
    if [ "${db_commit_id}" != null ] || [ "${db_commit_id}" != "null" ]
    then
        if [ "${#db_commit_id}" != 40 ] || [[ "${db_commit_id}" == *[^[:alnum:]]* ]]
        then
            echo_error "git commit id is not the correct length, or contains special characters.. please correct this." && exit 1
        fi
    fi
    if [[ "${realm_name}" == *['!'@#\$%^\&*()_+]* ]]
    then
        echo_error "realmname cannot contain special characters, please change this and try again." && exit 1
    fi
}
# WoW Client Data checks and create base directories
function clientdatacheck_makebasedirs () {
    if [ ! -d "${home_dir}/Client-Data/Data" ]
    then
        echo_error "Your WoW Client Data directory does not contain a Data folder with an uppercase"
        echo_bold "Please ensure that the WoW Client data folder does not contain any intermediate folders or ensure you have the Client Data path correct in your volumes environment variable"
        echo_bold "It should look similar to the below folder structure"
        echo '
        WoW Client Folder
        _________|_________
       |         |         |      
       Data   Interface   WTF

            \e[0m'
        exit 1
    fi

    if [ ! -d "${mangos_dir}" ]
    then
        mkdir --parents "${mangos_dir}"
    fi
    if [ ! -d "${database_dir}" ]
    then
        mkdir --parents "${database_dir}"
    fi
}
# Git glone latest version of specified repo and output commit ID for troubleshooting purposes
function git_clone () {
    local repo_name
    local directory
    repo_name="${1}"
    directory="${2}"
    git clone "https://github.com/cmangos/${repo_name}.git" \
            --branch "master" \
            --single-branch \
            --depth 1 \
            "${directory}"
    cd "${directory}/.git"
    echo_bold "${repo_name} commit ID: $(sed -n '2p' packed-refs | sed 's/\s.*$//')"
    echo_success "Clone of ${repo_name} was successful"
}
# Git glone the specified repo and output commit ID for troubleshooting purposes
function git_clone_specific_commit () {
    local repo_name
    local directory
    local commit_id
    repo_name="${1}"
    directory="${2}"
    commit_id="${3}"

    git clone "https://github.com/cmangos/${repo_name}.git" \
        --branch "master" \
        --single-branch \
        --depth 100 \
        "${directory}"
    cd "${directory}"
    git reset --hard "${commit_id}"
    git clean -d --force
    cd "${directory}/.git/refs/heads"
    echo_bold "${repo_name} commit ID: $(cat master)"
    echo_success "Clone of ${repo_name} commit ${commit_id} was successful"
}
# Logic for the first run gitclones 
function firstrun_gitclonelogic () {
    if [ "${core_commit_id}" != "null"  ] || [ "${core_commit_id}" != null  ] && [ "${db_commit_id}" != "null"  ] || [ "${db_commit_id}" != null  ]
    then
        git_clone_specific_commit "mangos-$expansion" "$mangos_dir" "${core_commit_id}"
        git_clone_specific_commit "$expansion-db" "$database_dir" "${db_commit_id}"

    else
        git_clone "mangos-$expansion" "$mangos_dir"
        git_clone "$expansion-db" "$database_dir"
    fi
}
function compile_cmangos () {
    local cmake_variable="${mangos_dir}"" -D CMAKE_INSTALL_PREFIX=${work_dir}/run -D PCH=1 -D DEBUG=0 -D BUILD_EXTRACTORS=ON -D BUILD_METRICS=ON"
    if [ "$playerbots" = on ] || [ "$playerbots" = "on" ]
    then
        cmake_variable+=" -D BUILD_PLAYERBOTS=ON"
    fi
    if [ "$ahbot" = on ] || [ "$ahbot" = "on" ] 
    then
        cmake_variable+=" -D BUILD_AHBOT=ON"
    fi 
    
    echo_bold "Start compiling CMaNGOS"
    if [ ! -d "${work_dir}/build" ]
    then
        mkdir "${work_dir}/build"
    fi
    if [ ! -d "${work_dir}/run" ]
    then
        mkdir "${work_dir}/run"
    fi
    cd "${work_dir}/build"
    cmake ${cmake_variable}
    make -j"$(nproc)"
    make install
    echo_success "Compiling of CMaNGOS was successful"
}
#Copy conf files to allow user update
function copymove_conf_files () {
    echo_bold "Copying configuration files and moving default configurations to their own folder in - ${work_dir}/run/etc/defaultconfigs"
    cd "${work_dir}/run/etc"
    if [ ! -d "${work_dir}/run/etc/defaultconfigs" ]
    then
        mkdir --verbose "${work_dir}/run/etc/defaultconfigs" 
    fi
    cp --verbose --force mangosd.conf.dist mangosd.conf
    cp --verbose --force realmd.conf.dist realmd.conf
    cp --verbose --force anticheat.conf.dist anticheat.conf
    cp --verbose --force aiplayerbot.conf.dist aiplayerbot.conf
    cp --verbose --force ahbot.conf.dist ahbot.conf
    mv --verbose --force mangosd.conf.dist "${work_dir}/run/etc/defaultconfigs"
    mv --verbose --force realmd.conf.dist "${work_dir}/run/etc/defaultconfigs"
    mv --verbose --force anticheat.conf.dist "${work_dir}/run/etc/defaultconfigs"
    mv --verbose --force aiplayerbot.conf.dist "${work_dir}/run/etc/defaultconfigs" 
    mv --verbose --force ahbot.conf.dist "${work_dir}/run/etc/defaultconfigs"
    echo_success "Copy and move of configuration files completed"
}
# extract client data required files for maps etc then move generated files created by extractor and remove copied WoW client data files
function extractor () {
    echo_bold "Starting extraction of WoW client data"
    cd "${work_dir}/run/bin/tools"
    chmod --verbose +x ExtractResources.sh
    chmod --verbose +x MoveMapGen.sh
    if [ ! -d "${home_dir}/Client-Data-Copy" ]
    then
        mkdir "${home_dir}/Client-Data-Copy"
    fi
    echo_bold "Copying ${expansion} client data"
    cp --recursive "${home_dir}/Client-Data/." "${home_dir}/Client-Data-Copy"
    echo_bold "Copying extractor tools to copy of ${expansion} client data"
    cp --recursive "${work_dir}/run/bin/tools/." "${home_dir}/Client-Data-Copy"
    cd "${home_dir}/Client-Data-Copy"
    echo y | bash ./ExtractResources.sh
    echo_success "Extraction of WoW Client data was successfully"

    mv *maps "${work_dir}/run/bin"
    if [ -d "${home_dir}/Client-Data-Copy/CreatureModels" ]
    then
        mv CreatureModels "${work_dir}/run/bin"
    fi
    mv dbc "${work_dir}/run/bin"
    mv Cameras "${work_dir}/run/bin"
    mv MaNGOSExtractor*log "${work_dir}/run/bin/tools/"
    rm --recursive --force "${home_dir}/Client-Data-Copy"
}
# update default installfulldb.config file  and add required database tables to mariadb 
function install_database () {
    cd "${database_dir}"
    echo 9 | ./InstallFullDB.sh > /dev/null
    echo_success "Default DB configuration file created"

    # Change some default values for the InstallFullDB.config file # Change AHBOT and Playerbots to ENV variable
   # sed --in-place 's/^MYSQL_HOST=.*$/MYSQL_HOST="'"${mariadb_container_name}"'"/' InstallFullDB.config
   # sed --in-place 's/^MYSQL_PASSWORD=.*$/MYSQL_PASSWORD="'"${mariadb_mangos_user_password}"'"/' InstallFullDB.config
    #sed --in-place 's/^MYSQL_USERIP=.*$/MYSQL_USERIP="%"/' InstallFullDB.config
    #sed --in-place 's\^CORE_PATH=.*$\CORE_PATH="'"${mangos_dir}"'"\' InstallFullDB.config 
    #sed --in-place 's/^AHBOT=.*$/AHBOT="YES"/' InstallFullDB.config
    #sed --in-place 's/^PLAYERBOTS_DB=.*$/PLAYERBOTS_DB="YES"/' InstallFullDB.config
    #sed --in-place 's/^FORCE_WAIT=.*$/FORCE_WAIT="NO"/' InstallFullDB.config

    sed --in-place 's/MYSQL_HOST="localhost"/MYSQL_HOST="'${mariadb_container_name}'"/' InstallFullDB.config && \
    sed --in-place 's/MYSQL_PASSWORD="mangos"/MYSQL_PASSWORD="'${mariadb_mangos_user_password}'"/' InstallFullDB.config && \
    sed --in-place 's/MYSQL_USERIP="localhost"/MYSQL_USERIP="%"/' InstallFullDB.config && \
    sed --in-place 's\CORE_PATH=""\CORE_PATH="'${mangos_dir}'"\' InstallFullDB.config && \
    sed --in-place 's/AHBOT="NO"/AHBOT="YES"/' InstallFullDB.config && \
    sed --in-place 's/PLAYERBOTS_DB="NO"/PLAYERBOTS_DB="YES"/' InstallFullDB.config && \
    sed --in-place 's/FORCE_WAIT="YES"/FORCE_WAIT="NO"/' InstallFullDB.config && \

    bash ./InstallFullDB.sh -InstallAll 'root' "${mariadb_root_password}" DeleteAll
    echo_success "Application of Database tables was successful"
    
}
function updatedatabase () {
    cd "${database_dir}"
    bash ./InstallFullDB.sh -UpdateCore
    echo_success "Application of Database tables was successful"
}
# update the default mangosd and realmd config files
function update_mangosdrealmd_config () {
    cd "${work_dir}/run/etc" || exit 1
    echo_bold "Updating default mangosd.conf and realmd.conf configurations"
    sed --in-place 's/^LoginDatabaseInfo     =.*$/LoginDatabaseInfo     = "'${mariadb_container_name}';3306;mangos;'${mariadb_mangos_user_password}';'${expansion}'realmd"/' mangosd.conf
    sed --in-place 's/^WorldDatabaseInfo     =.*$/WorldDatabaseInfo     = "'${mariadb_container_name}';3306;mangos;'${mariadb_mangos_user_password}';'${expansion}'mangos"/' mangosd.conf
    sed --in-place 's/^CharacterDatabaseInfo =.*$/CharacterDatabaseInfo = "'${mariadb_container_name}';3306;mangos;'${mariadb_mangos_user_password}';'${expansion}'characters"/' mangosd.conf
    sed --in-place 's/^LogsDatabaseInfo      =.*$/LogsDatabaseInfo      = "'${mariadb_container_name}';3306;mangos;'${mariadb_mangos_user_password}';'${expansion}'logs"/' mangosd.conf
    sed --in-place 's/^Motd =.*$/Motd = "Welcome to the CMaNGOS-'${expansion}'-in-Docker Server"/' mangosd.conf
    sed --in-place 's/^Rate.XP.Kill    =.*$/Rate.XP.Kill    = 3/' mangosd.conf
    sed --in-place 's/^Rate.XP.Quest   =.*$/Rate.XP.Quest   = 5/' mangosd.conf
    sed --in-place 's/^Rate.XP.Explore =.*$/Rate.XP.Explore = 3/' mangosd.conf

    sed --in-place 's/^LoginDatabaseInfo.*=.*$/LoginDatabaseInfo = "'${mariadb_container_name}';3306;mangos;'${mariadb_mangos_user_password}';'${expansion}'realmd"/' realmd.conf
    echo_bold "mangosd.conf and realmd.conf configuration changes completed"
}
#update the realm name and ip address as per REALMNAME and IPADDRESS Env variable
function update_realmname_ipaddress () {
    sed --in-place 's/user=/user="mangos"/' /etc/my.cnf
    sed --in-place 's/password=/password='"${mariadb_mangos_user_password}"''/'' /etc/my.cnf
    sed --in-place 's/port=/port=3306/' /etc/my.cnf
    sed --in-place 's/host=/host='"${mariadb_container_name}"'/' /etc/my.cnf
    mariadb --defaults-file=/etc/my.cnf \
            --execute='UPDATE '${expansion}'realmd.realmlist SET name="'${realm_name}'", address="'${ip_address}'";'
    echo_bold "Updated Realm Name to ${realm_name} and Realm IP address to ${ip_address}"
}
# update the playerbots config file
function update_playerbots_config () {
    if [ "${playerbots}" = on ] || [ "${playerbots}" = "on" ]
    then
        cd "${work_dir}/run/etc"
        sed --in-place 's/^.*AiPlayerbot.MaxRandomBots =.*$/AiPlayerbot.MaxRandomBots = 1500/' aiplayerbot.conf
        sed --in-place 's/^.*AiPlayerbot.MinRandomBots =.*$/AiPlayerbot.MinRandomBots = 1000/' aiplayerbot.conf
        sed --in-place 's/^.*AiPlayerbot.RandomBotGuildCount =.*$/AiPlayerbot.RandomBotGuildCount = 50/' aiplayerbot.conf
        sed --in-place 's/^.*AiPlayerbot.RandomGearUpgradeEnabled =.*$/AiPlayerbot.RandomGearUpgradeEnabled = 1/' aiplayerbot.conf
        sed --in-place 's/^.*AiPlayerbot.RandomBotTeleportNearPlayer =.*$/AiPlayerbot.RandomBotTeleportNearPlayer = 1/' aiplayerbot.conf
        sed --in-place 's/^.*AiPlayerbot.TalentsInPublicNote =.*$/AiPlayerbot.TalentsInPublicNote = 1/' aiplayerbot.conf
        sed --in-place 's/^.*AiPlayerbot.SyncQuestWithPlayer =.*$/AiPlayerbot.SyncQuestWithPlayer = 1/' aiplayerbot.conf
        sed --in-place 's/^.*AiPlayerbot.AutoLearnTrainerSpells =.*$/AiPlayerbot.AutoLearnTrainerSpells = 1/' aiplayerbot.conf
        sed --in-place 's/^.*AiPlayerbot.AutoLearnQuestSpells =.*$/AiPlayerbot.AutoLearnQuestSpells = 1/' aiplayerbot.conf
        if [ "${expansion}" = classic ] || [ "${expansion}" = "classic" ] && [ "${playerbots}" = on ] || [ "${playerbots}" = "on" ]
        then
            sed --in-place 's/^.*AiPlayerbot.RandomBotMaxLevel =.*$/AiPlayerbot.RandomBotMaxLevel = 60/' aiplayerbot.conf
        fi
        if [ "${expansion}" = tbc ] || [ "${expansion}" = "tbc" ] && [ "${playerbots}" = on ] || [ "${playerbots}" = "on" ]
        then
            sed --in-place 's/^.*AiPlayerbot.RandomBotMaxLevel =.*$/AiPlayerbot.RandomBotMaxLevel = 70/' aiplayerbot.conf
        fi
            if [ "${expansion}" = wotlk ] || [ "${expansion}" = "wotlk" ] && [ "${playerbots}" = on ] || [ "${playerbots}" = "on" ]
        then
            sed --in-place 's/^.*AiPlayerbot.RandomBotMaxLevel =.*$/AiPlayerbot.RandomBotMaxLevel = 80/' aiplayerbot.conf
        fi
    fi
}
# finalise setup and create required folders / files
function finalise_setup () {
    if [ ! -d "${work_dir}/db-backups" ]
    then
        mkdir "${work_dir}/db-backups"
    fi
    if [ ! -d "${work_dir}/full-backups" ]
    then
        mkdir "${work_dir}/full-backups"
    fi
    touch "${work_dir}/run/bin/.SETUPCOMPLETE"
    echo_orangeinfo "\nPlease make any manual changes to your configurations before starting your server (configs can be found in /home/mangos/cmangos-${expansion}/run/etc within your cmangos docker volume.) if you used the environment variables to make changes you can ignore this."
    echo_orangeinfo 'When you have made your required changes you can use "docker compose up -d" again to start the server, depending on your configurations this can take some time for the server to be fully up and running especially if using playerbots..'
}
# Perform a MariaDB dump and compress it to a tar.gz to save space for backup/restore purposes
function mariadbbackup() {
    echo_orangeinfo "Creating backup of ${expansion} database"
    local datenow 
    datenow=$(date "+%d-%m-%yT%H%M%S")
    sed --in-place 's/user=/user="mangos"/' /etc/my.cnf
    sed --in-place 's/password=/password='"${mariadb_mangos_user_password}"''/'' /etc/my.cnf
    sed --in-place 's/port=/port=3306/' /etc/my.cnf
    sed --in-place 's/host=/host='"${mariadb_container_name}"'/' /etc/my.cnf
    mariadb-dump --defaults-file=/etc/my.cnf \
                    --lock-tables --databases "${expansion}"characters "${expansion}"logs "${expansion}"mangos "${expansion}"realmd > "${work_dir}/db-backups/${expansion}-backup-${datenow}.sql"
    tar --absolute-names --gzip --file="${work_dir}/db-backups/${expansion}-backup-${datenow}.tar.gz" --create "${work_dir}/db-backups/${expansion}-backup-${datenow}.sql"
    rm "${work_dir}"/db-backups/"${expansion}"-backup-*.sql
    echo_success "Database backup complete"
}
# start realmd and mangosd and leave mangos user available for prompts
function start_cmangos () {
    echo_successflashingdots "Starting realmd"
    su - mangos -c "cd ${work_dir}/run/bin && screen -dmS realmd ./realmd"
    echo_successflashingdots "Starting mangosd"
    su - mangos -c "cd ${work_dir}/run/bin && screen -dmS mangosd ./mangosd"
    echo_success "mangosd and realmd successfully started"
}
function create_fullbackup () {
    mariadbbackup
    echo_orangeinfo "Starting full backup process, this can take some time.."
    local latestmariadbbackup
    latestmariadbbackup=$(ls -t "${work_dir}/db-backups/" | head -n1)
    local datenow 
    datenow=$(date "+%d-%m-%yT%H%M%S")
    tar --absolute-names -czf "${work_dir}/full-backups/Fullbackup-${datenow}.tar.gz" "${work_dir}/mangos-${expansion}" "${work_dir}/${expansion}-db" "${work_dir}/run" "${work_dir}/db-backups/${latestmariadbbackup}"
    echo_success "Full backup complete!"
}
function upgradeprocess () {
    # allow facility for latest flag? 
    local fullbackupcompleted
    fullbackupcompleted=0
    if [ "${core_commit_id}" != null ] || [ "${core_commit_id}" != "null" ]
    then
        cd "${mangos_dir}/.git/refs/heads"
        local core_commit_oldid
        core_commit_oldid=$(cat master)
        if [ "${core_commit_id}" != "${core_commit_oldid}" ]
        then
            git config --global --add safe.directory "*"
            git fetch --quiet >> /dev/null
            if git rev-list --max-count=10000 "${core_commit_id}" | grep "${core_commit_oldid}" -q ;
            then 
                echo_success "Detected Core commit ID is newer than current Core commit ID, will now perform a full backup and update the core."
                cd "${mangos_dir}" 
                create_fullbackup
                fullbackupcompleted=1
                git merge "${core_commit_id}"
                compile_cmangos
                copymove_conf_files
                updatedatabase
                update_mangosdrealmd_config 
                update_playerbots_config
                echo_success "Core updated successfully, will now check database commit ID"
            else 
                echo_orangeinfo "Commit not found, is it definitely correct? Is it older than the current commit?"
            fi
        else
            echo_orangeinfo "Core commit provided is not newer than the current core commit, checking database commit id."
        fi
    fi

    if [ "${db_commit_id}" != null ] || [ "${db_commit_id}" != "null" ]
    then
        cd "${database_dir}/.git/refs/heads"
        local db_commit_oldid
        db_commit_oldid=$(cat master)
        if [ "${db_commit_id}" != "${db_commit_oldid}" ]
        then
            git config --global --add safe.directory "*"
            git fetch --quiet >> /dev/null
            if git rev-list --max-count=9000 "${db_commit_id}" | grep "${db_commit_oldid}" -q ;
            then 
                echo_success "Detected Database commit ID is newer than current Database commit ID, will now perform a full backup and update the Database."
                cd "${database_dir}"
                if [ $fullbackupcompleted = 0 ]
                then 
                    create_fullbackup
                else
                    echo_orangeinfo "Full backup already completed for core update.. will skip"
                fi
                git merge "${db_commit_id}"
                updatedatabase 
                echo_success "Database updated successfully, will now start the server"
            else 
                echo_orangeinfo "Commit not found, is it definitely correct? Is it older than the current commit?"
            fi          
        else
            echo_orangeinfo "Database commit provided is not newer than the current Database commit, starting server.."
        fi
    fi
}
#region - Setup
if [ ! -f "${work_dir}/run/bin/.SETUPCOMPLETE" ]
then
    echo -e '\e[1;38;5;208m
   ________  ___      _   ____________  _____       ____            ____             __             
  / ____/  |/  /___ _/ | / / ____/ __ \/ ___/      /  _/___        / __ \____  _____/ /_____  _____ 
 / /   / /|_/ / __ `/  |/ / / __/ / / /\__ \______ / // __ \______/ / / / __ \/ ___/ //_/ _ \/ ___/ 
/ /___/ /  / / /_/ / /|  / /_/ / /_/ /___/ /_____// // / / /_____/ /_/ / /_/ / /__/ ,< /  __/ /     
\____/_/  /_/\__,_/_/ |_/\____/\____//____/     /___/_/ /_/     /_____/\____/\___/_/|_|\___/_/      
            _______           __     ____                 _____      __                             
           / ____(_)_________/ /_   / __ \__  ______     / ___/___  / /___  _____                   
 ______   / /_  / / ___/ ___/ __/  / /_/ / / / / __ \    \__ \/ _ \/ __/ / / / __ \   ______        
/_____/  / __/ / / /  (__  ) /_   / _, _/ /_/ / / / /   ___/ /  __/ /_/ /_/ / /_/ /  /_____/        
        /_/   /_/_/  /____/\__/  /_/ |_|\__,_/_/ /_/   /____/\___/\__/\__,_/ .___/                  
                                                                          /_/                        
                                                                                            \e[0m'

    datavalidation
    clientdatacheck_makebasedirs
    firstrun_gitclonelogic
    compile_cmangos
    copymove_conf_files
    extractor
    install_database
    update_mangosdrealmd_config
    update_realmname_ipaddress
    update_playerbots_config
    finalise_setup

#endregion
else
#region - Running
    echo -e '\e[1;38;5;208m
   ________  ___      _   ____________  _____       ____            ____             __            
  / ____/  |/  /___ _/ | / / ____/ __ \/ ___/      /  _/___        / __ \____  _____/ /_____  _____
 / /   / /|_/ / __ `/  |/ / / __/ / / /\__ \______ / // __ \______/ / / / __ \/ ___/ //_/ _ \/ ___/
/ /___/ /  / / /_/ / /|  / /_/ / /_/ /___/ /_____// // / / /_____/ /_/ / /_/ / /__/ ,< /  __/ /    
\____/_/  /_/\__,_/_/ |_/\____/\____//____/     /___/_/ /_/     /_____/\____/\___/_/|_|\___/_/     
            _____ __             __  _                _____                                        
           / ___// /_____ ______/ /_(_)___  ____ _   / ___/___  ______   _____  _____              
 ______    \__ \/ __/ __ `/ ___/ __/ / __ \/ __ `/   \__ \/ _ \/ ___/ | / / _ \/ ___/  ______      
/_____/   ___/ / /_/ /_/ / /  / /_/ / / / / /_/ /   ___/ /  __/ /   | |/ /  __/ /     /_____/      
         /____/\__/\__,_/_/   \__/_/_/ /_/\__, /   /____/\___/_/    |___/\___/_/                   
                                         /____/                                                    \n\e[0m'
    
    chown -R mangos:mangos "${home_dir}"
    upgradeprocess
    if [ "${dbbackups}" == on ] || [ "${dbbackups}" == "on" ]
    then
        mariadbbackup
    fi
    start_cmangos
    echo_orangeinfo '\nYou can now use "docker attach cmangos-in-docker" then type "screen -r mangosd or screen -r realmd" to connect to your mangosd or realmd processes.'
    su - mangos
#endregion
fi