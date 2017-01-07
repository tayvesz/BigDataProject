-- Create a daily temporary table to load daily data which will be afterwards sent to global table --

use base;
drop table if exists base.dailytable;
create table base.dailytable (
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
FIELDS TERMINATED BY ','
STORED AS TEXTFILE;

load data inpath '/user/hue/oozie/workspaces/project/dailydata.csv' into table dailytable;
insert into table carburants_parquet select * from base.dailytable;
drop table base.dailytable;
