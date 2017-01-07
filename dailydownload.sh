#/bin/sh

#Repertories
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

#Applying the Python script to convert it into csv format
python $localDirect/xmltocsv.py $dailyDirectory/dailydata.xml $dailyDirectory/dailydata.csv

#Putting xml file into my oozie workspace on HDFS: /user/hue/oozie/workspaces/project
hdfs dfs -rm -f $oozieWorkspace/dailydata.csv
hdfs dfs -put $dailyDirectory/dailydata.csv $oozieWorkspace
