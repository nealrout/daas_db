# daas_db

To run migration execute below command
    Initialization
        liquibase update --contexts=init

    Migration
        liquibase update --contexts=update

For postgresql anonomous blocks to work we have to substitute single quotes ' to two single quotes ''.
And double dollar sign $$ to single quotes '

