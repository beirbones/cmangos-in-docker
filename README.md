# Overview

## The aim of this repository is to create a docker image that is extensible and highly customisable whilst also making start and maintaining a CMaNGOS server straightforward with very few individual user steps to get up and running. The below list are some of the aims of this project -

- Create a simple docker image that requires very little configuration to get a CMaNGOS server up and running.
- Allow the image to be highly customisable for various use cases by allowing configuration of the image using docker environment variables i.e playerbots configurations etc.
- Keep users out of the server processes as much as possible and spending more time enjoying!
- Selfishly to allow me to play The Burning Crusade as it's my favourite expansion.
- As a fun project for myself and to allow me to collaborate with others to improve my poorly written code :)

## The below list is a list of some of the things this project can provide -

- Choosing which expansion to install (classic, tbc or wotlk).
- Install using the latest available commit version/s for your chosen expansion OR Choosing which expansion core commit or database commit ids to install with.
- Updating the Realm Name / IP address of your server.
- Enabling/Disabling/Configuring the Playerbots Module.
- Enabling/Disabling/Configuring the AHBot Module.
- Database backup of the server during start up.
- Updating the server to specified core / db commit ids whilst providing a database backup and a full data backup before updating to allow easy restoration.
- Creating the first account user during startup and setting a GM Level for the account.

[Quick Start](https://github.com/beirbones/cmangos-in-docker/wiki/Quick-Start)
