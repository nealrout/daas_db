# daas_db

## Description

This project contains the liquibase scripts to build and underlying PostgreSQL daas database.  This database stores facility, asset, etc. information for DaaS that will be fetched through Django apis.  We are adding functions and procedures so we can control the CRUD operations at the DBMS level.


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
If the DaaS database does not exist yet, you must create it with a password that you must update. 

    CREATE ROLE daas WITH login PASSWORD 'UPDATEME';
    CREATE DATABASE us_dev_daas OWNER daas;
    CREATE DATABASE us_int_daas OWNER daas;

    GRANT ALL PRIVILEGES ON
    DATABASE us_dev_daas TO daas;
    GRANT ALL PRIVILEGES ON
    DATABASE us_int_daas TO daas;
    
    CREATE SCHEMA daas;
    ALTER SCHEMA daas OWNER TO daas;

#
    Initialization
        liquibase update --contexts=init --username=UPDATEME --password=UPDATEME

    Migration
        liquibase update --contexts=update --username=UPDATEME --password=UPDATEME


## Features
- Facility table
- Asset table and functions to allow DBMS control over CRUD operations.

## Contact
Neal Routson  
nroutson@gmail.com
