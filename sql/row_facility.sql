-- This is not really required now, as the facility domain is loaded through Django into the facility_facility table
insert into daas.facility (fac_code, fac_name, create_ts) values ('US_TEST_01', 'TEST FACILITY 1', now());
insert into daas.facility (fac_code, fac_name, create_ts) values ('US_TEST_02', 'TEST FACILITY 2', now());
insert into daas.facility (fac_code, fac_name, create_ts) values ('US_TEST_03', 'TEST FACILITY 3', now());
insert into daas.facility (fac_code, fac_name, create_ts) values ('US_TEST_04', 'TEST FACILITY 4', now());
insert into daas.facility (fac_code, fac_name, create_ts) values ('US_TEST_05', 'TEST FACILITY 5', now());
insert into daas.facility (fac_code, fac_name, create_ts) values ('US_TEST_06', 'TEST FACILITY 6', now());
insert into daas.facility (fac_code, fac_name, create_ts) values ('US_TEST_07', 'TEST FACILITY 7', now());
insert into daas.facility (fac_code, fac_name, create_ts) values ('US_TEST_08', 'TEST FACILITY 8', now());
insert into daas.facility (fac_code, fac_name, create_ts) values ('US_TEST_09', 'TEST FACILITY 9', now());
insert into daas.facility (fac_code, fac_name, create_ts) values ('US_TEST_10', 'TEST FACILITY 10', now());
insert into daas.facility (fac_code, fac_name, create_ts) values ('US_TEST_11', 'TEST FACILITY 11', now());
insert into daas.facility (fac_code, fac_name, create_ts) values ('US_TEST_12', 'TEST FACILITY 12', now());
insert into daas.facility (fac_code, fac_name, create_ts) values ('US_TEST_13', 'TEST FACILITY 13', now());
insert into daas.facility (fac_code, fac_name, create_ts) values ('US_TEST_14', 'TEST FACILITY 14', now());
insert into daas.facility (fac_code, fac_name, create_ts) values ('US_TEST_15', 'TEST FACILITY 15', now());
insert into daas.facility (fac_code, fac_name, create_ts) values ('US_TEST_16', 'TEST FACILITY 16', now());
insert into daas.facility (fac_code, fac_name, create_ts) values ('US_TEST_17', 'TEST FACILITY 17', now());
insert into daas.facility (fac_code, fac_name, create_ts) values ('US_TEST_18', 'TEST FACILITY 18', now());
insert into daas.facility (fac_code, fac_name, create_ts) values ('US_TEST_19', 'TEST FACILITY 19', now());
insert into daas.facility (fac_code, fac_name, create_ts) values ('US_TEST_20', 'TEST FACILITY 20', now());

SELECT setval('daas.facility_id_seq', 99, false);
insert into daas.facility (fac_code, fac_name, create_ts) values ('UNKNOWN', 'UNKNOWN', now());
