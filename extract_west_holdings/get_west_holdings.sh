#!/bin/bash

# THIS SCRIPT DOES THE FOLLOWING:
# 1. Loops through a list of WEST mms_id and holding_id pairs and for each mms_id/holding_id pair...
# 2. Makes a GET call to the Alma Bibs web-service
# 3. Extracts the holding record information for each mms_id/holding_id pair
# 4. Deletes the 001 and replaces it with the holding_id
# 5. Deletes the 004 if present in the record and adds a new 004 with the mms_id in it
# 6. Deletes the 014, 969, 022, and 035 fields
# 7. Deletes the 852.x subfield if it exists
# 8. Writes the output to a (temporarily) invalid xml file
#	NOTE: a root node "<records>" will need to be added to xml file later to make it valid. This is a kluge that should be fixed later.
# 9. Removes the <?xml version="1.0"> tag


cat west_ids.csv | while read item
do
	# separate .csv file into fields and declare variables
	mms_id="$(cut -d',' -f1 <<<$item)"
	holding_id="$(cut -d',' -f2 <<<$item)"

#######################
# GET HOLDINGS DATA
#######################

	hld_getstring="https://api-na.hosted.exlibrisgroup.com/almaws/v1/bibs/${mms_id}/holdings/${holding_id}"

	# retrieve holdings xml object
	hld_obj=$(curl -H "Authorization: apikey $(cat prod_apikey.txt)" -H "Accept: application/xml" -X GET $hld_getstring)

	# extract holding record xml
	hold_rec=$(echo $hld_obj | xmlstarlet sel -t -c '//holding/record')

	# update 001 with holding_id
	hold_rec=$(echo $hold_rec | xmlstarlet ed -u '/record/controlfield[@tag="001"]' -v $holding_id)

	# Insert mms_id into 004 control field by looking for 001 control fields and appending it if a 004 doesn't exist
	hold_rec=$(echo $hold_rec | xmlstarlet ed -a '/record/controlfield[@tag="001"]' \
						  -t 'elem' -n 'controlfield' -v $mms_id \
						  -i '/record/controlfield[not(@tag)]' \
						  -t 'attr' -n 'tag' -v '004')

	# delete 014, 969, 022, and 035 fields
	hold_rec=$(echo $hold_rec | xmlstarlet ed -d '/record/datafield[@tag="014"]')
	hold_rec=$(echo $hold_rec | xmlstarlet ed -d '/record/datafield[@tag="969"]')
	hold_rec=$(echo $hold_rec | xmlstarlet ed -d '/record/datafield[@tag="022"]')
	hold_rec=$(echo $hold_rec | xmlstarlet ed -d '/record/datafield[@tag="035"]')

	# delete 852.x subfield
	hold_rec=$(echo $hold_rec | xmlstarlet ed -d '/record/datafield[@tag="852"]/subfield[@code="x"]')

	echo $hold_rec

	# write and append to file
done   >  west_recs_test.xml

# remove version and encoding
perl -p -e 's/<\?xml version="1.0"\?>//g' west_recs.xml > west_recs_clean.xml

