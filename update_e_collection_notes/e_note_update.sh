#!bin/bash

#######################################################################################################################
# This script can be used to update alma electronic collection internal descriptions (notes) with
# new notes in batch. The script does roughly the following:
# 1. loops through a txt file of collection id/note pairs
# 2. uses the vlaues in the coll_id column to make get calls to the alma api and retreive the e-collection xml object
# 3. updates the internal_description field with the information from the "note" column
# 4. makes put calls to send the updated e-collection objects back to the alm api
# 5. creates a txt of coll_id pairs for verification that the put call was successful
#
# BEWARE: the put calls will replace the "modification date" and "modified by" fields in the e-collection record with 
# "alma-api". according to ex libris, this behaivor is a normal bi-product of the get/put swap model.
#######################################################################################################################


cat coll_ids.txt | while IFS= read item
do
	# isolate variable from tsv file of collection id/note pairs 
	coll_id="$(cut -f1 <<<$item)"
	note="$(cut -f2 <<<$item)"

	# create string for GET call to Alma web service
	getstring="https://api-na.hosted.exlibrisgroup.com/almaws/v1/electronic/e-collections/${coll_id}"

	# get e-collection xml object
	coll_obj=$(curl -s -H "Authorization: apikey $(cat api_key_e_prod.txt)" -H "Accept: application/xml" -X GET $getstring)

	#  edit internal_description xml and replace with note variable
	coll_obj=$(echo $coll_obj | xmlstarlet ed -u '/electronic_collection/internal_description' -v "${note}")


	# send the modified xml object back to alma web service for update via PUT
	updatedoc=$(curl -s -H "Authorization: apikey $(cat api_key_e_prod.txt)" -H "Content-Type: application/xml" -X PUT --data "${coll_obj}" $getstring)
	
	# extract collection id from updated xml document returned by api 
	resp_coll_id=$(echo $coll_obj | xmlstarlet sel -T -t -m '//electronic_collection/id' -v '.')
	
	# create a .txt file of results
	echo -e "$coll_id\t$resp_coll_id"
	
done > results.txt
# add header row to results
sed -i $'1 i\\\ncollection_id_sent\tcollection_id_returned' results.txt
