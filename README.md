# Overview

## What is this?
[CMaNGOS](https://cmangos.net/) in docker.. an emulated World of Warcraft server running inside docker obscuring away the nitty gritty of setting up a CMaNGOS server yourself whilst only requiring very little from the end-user.

## but why?
Well.. I wanted this for myself first and foremost as other projects I'd seen had heavy dependencies on Windows or were too technical for me to get involved in and had lots of moving parts so I felt I could hopefully make something better and easier to maintain in the long run.. I also like to self host any services I can and being somewhat familiar with docker it made sense to make this monstrosity.

###  Aim of this project

- Create a simple docker image that requires very little configuration to get a CMaNGOS server up and running.
- Allow the image to be highly customisable for various use cases by allowing configuration of the image using docker environment variables i.e playerbots configurations etc.
- Keep users out of the server processes as much as possible and spending more time playing!
- Selfishly to allow me to play The Burning Crusade as it's my favourite expansion.
- As a fun project for myself and to allow me to collaborate with others to improve my poorly written code :)

### What this project can provide

- Choosing which expansion to install (classic, tbc or wotlk).
- Install using the latest available commit version/s for your chosen expansion OR Choosing which expansion core commit or database commit ids to install with.
- Updating the Realm Name / IP address of your server.
- Enabling/Disabling/Configuring the Playerbots Module.
- Enabling/Disabling/Configuring the AHBot Module.
- Database backup of the server during start up.
- Updating the server to specified core / db commit ids whilst providing a database backup and a full data backup before updating to allow easy restoration.
- Creating the first account user during startup and setting a GM Level for the account.

### [Quick Start](https://github.com/beirbones/cmangos-in-docker/wiki/Quick-Start)
