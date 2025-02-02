# daas_db

## Description

This project contains the liquibase scripts to build and underlying daas database.  This database stores facility, asset, etc. information for DaaS that will be fetched through Django apis.  We are adding functions and procedures so we can control the CRUD operations at the DBMS level.


## Table of Contents

- [Miscellaneous](#miscellaneous)
- [Usage](#usage)
- [Features](#features)
- [Contact](#contact)

## Miscellaneous
For postgresql anonomous blocks to work we have to make the following substitutions in the .sql files

- From
  - '
- To
  - ''
- From
  - \$$
- To
  - '

## Usage
    Initialization
        liquibase update --contexts=init

    Migration
        liquibase update --contexts=update


## Features
- Facility table
- Asset table and functions to allow DBMS control over CRUD operations.

## Contact
Neal Routson  
nroutson@gmail.com
