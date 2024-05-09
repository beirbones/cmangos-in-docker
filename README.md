# cmangos-in-docker
Overview
The docker image provided by this repository provide a method to install CMaNGOS using docker whilst providing a highly customisable experience using docker environment variables to manage the vast majority of configurations required for a CMaNGOS server. This includes

- Choosing which expansion to install (classic, tbc or wotlk).
- Install using the latest available commit version/s for your chosen expansion OR Choosing which expansion core commit or database commit ids to install with.
- Updating the Realm Name / IP address of your server.
- Enabling/Disabling/Configuring the Playerbots Module.
- Enabling/Disabling/Configuring the AHBot Module.
- Database backup of the server during start up.
- Updating the server to specified core / db commit ids whilst providing a database backup and a full data backup before updating to allow easy restoration.
- Creating the first account user during startup and setting a GM Level for the account.
