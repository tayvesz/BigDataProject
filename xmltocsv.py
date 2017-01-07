import os.path
import sys
import csv
from xml.etree import cElementTree

# Python script which extracts from the daily xml file the useful tags:
# id, pop, latitude, longitude, cp, maj, id (fuel id), valeur (price) and nom (fuel name)

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
