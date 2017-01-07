# It tools for Big Data Readme

### Project Description
Set up a featured data platform for processing pricing data on Hadoop:

* Set-up the platform. We used both Hortonworks and Cloudera VMs: the first one to produce the notebook with visualizations. The second (Cloudera) to produce through Hue, the oozie workflow coordination 
* Develop data loading and storage to a table
* Develop a notebook with several visualizations: We used zeppelin provided in Hortonworks sandbox

### A. Database et Tables


1) First of all, we create a in Ambari Hive script editor the database named base of the entire project.
```sql
create table base;
```

2) Then we create a temporary Hive table "carburants_csv" in which we will load the csv files. The initial csv files are in the local directory of hortonworks "*/tmp/rawdata/xmlfiles*". We chose the years 2013 to 2016. The fields delimiter *"\73"* is used for semicolon.

```sql
use base;

drop table if exists base.carburants_csv;
create table if not exists base.carburants_csv(id INT,cp STRING,pop STRING,latitude INT,longitude INT,date_info STRING,id_carb INT,nom_carburant STRING,prix INT )
row format delimited 
FIELDS TERMINATED BY '\073' 
STORED AS TEXTFILE;

load data local inpath "/tmp/rawdata/csvfiles/Prix2013.csv" into table base.carburants_csv;
load data local inpath "/tmp/rawdata/csvfiles/Prix2014.csv" into table base.carburants_csv;
load data local inpath "/tmp/rawdata/csvfiles/Prix2015.csv" into table base.carburants_csv;
load data local inpath "/tmp/rawdata/csvfiles/Prix2016.csv" into table base.carburants_csv;
``` 

3) Then, we create **carburants_parquet**, another Hive table with a **parquet** format and insert in it all the data stored in carburants_csv. Finally, we drop the table carburants_csv.

```sql
use base;

create table base.carburants_parquet(id INT,cp STRING,pop STRING,latitude INT,longitude INT,date_info STRING,id_carb INT,nom_carburant STRING,prix INT)
row format delimited 
FIELDS TERMINATED BY '\073'
STORED AS PARQUET;

insert into table base.carburants_parquet select * from base.carburants_csv;
drop table base.carburants_csv;
```

4) Let us notice that it is also possible to create hive table in zeppelin using either hive interpreter or pyspark using HiveContext as bellow

```python
%pyspark
from pyspark.sql import HiveContext
hc = HiveContext(sc)
hc.sql("use base")
hc.sql("drop table base.carburants_parquet")
hc.sql("create table base.carburants_parquet(id INT, cp STRING, pop STRING, latitude INT, longitude INT,date_info STRING, id_carb INT,nom_carburant STRING, prix INT) row format delimited FIELDS TERMINATED BY '\073' STORED AS PARQUET")

hc.sql("insert into table base.carburants_parquet select * from base.carburants_csv")
hc.sql("drop table base.carburants_csv")
```

### B. Daily data upload

In this section, we present the dailydata script used in the oozie workflow. We used cloudera VM to in order to lever HUE.
The first script named *dailydownload.sh* allows to download using **wget** the daily data located at the url: https://donnees.roulez-eco.fr/opendata/jour.
This data is then unzipped and transformed into csv format and to ease it loading in the temporary hive table **dailytable**. 
The function used to convert the xml file in csv file is **xmltocsv.py**.
Before loading the daily csv data into csv their are send to HDFS.
We also provide the json file of the oozie workflow coordinator.

1) dailydownload.sh

```sh
#/bin/sh

#Repertories declarations
localDirect=/home/cloudera/project/				# The local repertory of the project
dailyDirectory=/home/cloudera/project/daily			# The local daily data repertory
oozieWorkspace=/user/hue/oozie/workspaces/project		# The HDFS workspace

#Remove the local directory do delete old data and re-create a new local repertory
rm -rf $dailyDirectory/
mkdir $dailyDirectory

#Downloading the new daily data and saving it in the local daily data repertory
wget https://donnees.roulez-eco.fr/opendata/jour -O $dailyDirectory/jour.zip
	
#Unzip the new daily data
unzip $dailyDirectory/jour.zip -d $dailyDirectory

#Renaming it by a more convenient name
mv $dailyDirectory/PrixCarburants_quotidien_* $dailyDirectory/dailydata.xml

#Applying the Python script xmltocsv.py (described below) to convert it into csv format
python $localDirect/xmltocsv.py $dailyDirectory/dailydata.xml $dailyDirectory/dailydata.csv

#Putting xml file into my oozie workspace on HDFS: /user/hue/oozie/workspaces/project
hdfs dfs -rm -f $oozieWorkspace/dailydata.csv
hdfs dfs -put $dailyDirectory/dailydata.csv $oozieWorkspace
```

2) Creating a first temporary table dailytable

```sql
use base;
drop table if exists base.dailytable;
create table base.dailytable (id INT,cp STRING,pop STRING,latitude INT,longitude INT,date_info STRING,id_carb INT,nom_carburant STRING,prix INT)
row format delimited 
FIELDS TERMINATED BY ','
STORED AS TEXTFILE;

load data inpath '/user/hue/oozie/workspaces/project/dailydata.csv' into table dailytable;
insert into table carburants_parquet select * from base.dailytable;
drop table base.dailytable;
```

3) Python script to extract useful tags information

```python
import os.path
import sys
import csv
from xml.etree import cElementTree

def csv_to_xml(infile,outfile):
	with open(outfile, 'wb') as f:
	   	writer = csv.writer(f)
		tree = cElementTree.parse(infile)
		pdvs = tree.getroot()
		for pdv in pdvs:
		    id_pdv = pdv.attrib['id']
		    pop = pdv.attrib['pop']
		    lat = pdv.attrib['latitude']
		    lon = pdv.attrib['longitude']
		    cp_pdv = pdv.attrib['cp']
		    for prix in pdv.getiterator('prix'):
			   date = prix.attrib['maj'] if 'maj' in prix.keys() else ''
			   id_prix = prix.attrib['id'] if 'id' in prix.keys() else ''
			   valeur = prix.attrib['valeur'] if 'valeur' in prix.keys() else ''
			   nom = prix.attrib['nom'] if 'nom' in prix.keys() else ''
			   row = [id_pdv, cp_pdv, pop, lat, lon, date, id_prix, nom, valeur]
			   writer.writerow(row)
	return
	
if __name__ == "__main__":
	infile = sys.argv[1]
	outfile = sys.argv[2]
	csv_to_xml(infile,outfile)
```

### C. Oozie workflow coordinator

The oozie workflows consists of three main components the first one is the shell script *dailydownload.sh*. The second component is the hive script *dailytable.hql* which loads the csv file generated by the *dailydownload.sh* script into a temporary dailytable and then insert these data into the global table.
The third component is a *email* component which alter the user when an update is done. 
Indeed the HUE GUI allows to build a workflows graphically. Once a workflow is completed, one can export it into a json file
The workflow is described in the xml file **DailyData.xml** and the oozie workflow coordinator in the file **Coordinator.json**


### D. Loading xml files into hive tables

This part is based on works provided by Dmitry Vasilenko and available at this [github link](https://github.com/dvasilen/Hive-XML-SerDe)

The goal is to use a jar designed by the author:
 
1) First we must download the hive serde (serialization/deserialization) and put in in a local directory for example /tmp/hive_serde/ of the Hortonworks sandbox VM
```sh
# Create the directory of the jar file
mkdir /tmp/hive_serde/
dc /tmp/hive_serde
# Download the jar file
wget http://search.maven.org/remotecontent?filepath=com/ibm/spss/hive/serde2/xml/hivexmlserde/1.0.5.3/hivexmlserde-1.0.5.3-sources.jar
# Rename the jar file for more convenience
mv remotecontent?filepath=com/ibm/spss/hive/serde2/xml/hivexmlserde/1.0.5.3/hivexmlserde-1.0.5.3-sources.jar hivexmlserde-1.0.5.3-sources.jar
```

2) Hive script to create the table and load data
```sql
add jar /tmp/hive_serde/hivexmlserde-1.0.5.3.jar;
USE base;
drop table base.carb_xml;
create table carb_xml (location_id INT,latitude INT,longitude INT,cp STRING,pop STRING,nom_carburant STRING,id_carburant INT,date_maj STRING,prix INT)

ROW FORMAT SERDE 'com.ibm.spss.hive.serde2.xml.XmlSerDe'
WITH SERDEPROPERTIES (
"column.xpath.location_id"="/pdv/@id",
"column.xpath.latitude"="/pdv/@latitude",
"column.xpath.longitude"="/pdv/@longitude",
"column.xpath.cp"="/pdv/@cp",
"column.xpath.pop"="/pdv/@pop",
"column.xpath.nom_carburant"="/pdv/prix/@nom",
"column.xpath.id_carburant"="/pdv/prix/@id",
"column.xpath.date_maj"="/pdv/prix/@maj",
"column.xpath.prix"="/pdv/prix/@valeur"
)

STORED AS 
    INPUTFORMAT 'com.ibm.spss.hive.serde2.xml.XmlInputFormat'
    OUTPUTFORMAT 'org.apache.hadoop.hive.ql.io.IgnoreKeyTextOutputFormat'
TBLPROPERTIES ("xmlinput.start"="<pdv id","xmlinput.end"="</pdv>");
load data local inpath "/tmp/rawdata/xmlfiles/PrixCarburants_annuel_2013.xml" into table base.carburants_csv;
load data local inpath "/tmp/rawdata/xmlfiles/PrixCarburants_annuel_2014.xml" into table base.carburants_csv;
load data local inpath "/tmp/rawdata/xmlfiles/PrixCarburants_annuel_2015.xml" into table base.carburants_csv;
load data local inpath "/tmp/rawdata/xmlfiles/PrixCarburants_annuel_2016.xml" into table base.carburants_csv;
```

However the xml files must start by <pdv_id, so a script shell is required to remove the first line of the xml files. For example for the xml files of the year 2013:
```sh
   sed -i 1d PrixCarburants_annuel_2013.xml 
```
