#!bin/bash

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
