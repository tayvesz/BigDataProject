-- Database of the project --

create database base;

-- Create a hive table in the database to load the csv files of 4 years: 2013 to 2016 --

use base;
drop table if exists base.carburants_csv;
create table base.carburants_csv(
	id INT, 
	cp STRING, 
	pop STRING, 
	latitude INT, 
	longitude INT,
	date_info STRING, 
	id_carb INT,
	nom_carburant STRING, 
	prix INT)
	row format delimited 
	FIELDS TERMINATED BY '\073' 
	STORED AS TEXTFILE;


load data local inpath '/home/cloudera/project/csvfiles/Prix2013.csv' into table base.carburants_csv;
load data local inpath '/home/cloudera/project/csvfiles/Prix2014.csv' into table base.carburants_csv;
load data local inpath '/home/cloudera/project/csvfiles/Prix2015.csv' into table base.carburants_csv;
load data local inpath '/home/cloudera/project/csvfiles/Prix2016.csv' into table base.carburants_csv;



-- Create a hive table in parquet format to insert the data from the previous table and then drop the previous table --

use base;
drop table if exists base.carburants_parquet;
create table base.carburants_parquet(
	id INT, 
	cp STRING, 
	pop STRING, 
	latitude INT, 
	longitude INT,
	date_info STRING, 
	id_carb INT,
	nom_carburant STRING, 
	prix INT)
	row format delimited 
	FIELDS TERMINATED BY '\073'
	STORED AS PARQUET;


insert into table base.carburants_parquet select * from base.carburants_csv;
drop table base.carburants_csv;
