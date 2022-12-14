#!/bin/bash

### THIS SCRIPT CAN BE USED TO CREATE PO-LINES FOR FY CLOSE ###

# 1. Funds.txt is a tsv file of fund code, expenditures, and notes
# 2. File_revised_note.xml is an XML template for the PO Line object
# 3. The script iterates through the file, populates the needed values in the XML object and then sends POST requests to create PO Lines
# 4. The results of the API requests are stored in a txt file (results.txt)

cat funds.txt | while read item
do

	# separate txt file into fields and variables
	fund="$(cut -f 1 <<<$item)"
	amount="$(cut -f 2 <<<$item)"
	note="$(cut -f 3 <<<$item)"

	# import xml template
	xmldoc=`cat create_pol_template.xml`

	# add amount to price element
	xmldoc=$(echo "$xmldoc" | xmlstarlet edit --update "//po_line/price/sum" --value "$amount")
	# add fundcode
	xmldoc=$(echo "$xmldoc" | xmlstarlet edit --update "//po_line/fund_distributions/fund_distribution/fund_code" --value "$fund")
	# add fund distribution
	xmldoc=$(echo "$xmldoc" | xmlstarlet edit --update "//po_line/fund_distributions/fund_distribution/amount/sum" --value "$amount")
	# add note
	xmldoc=$(echo "$xmldoc" | xmlstarlet edit --update "//po_line/notes/note/note_text" --value "$note")

	# create url for POL api
	poststring="https://api-na.hosted.exlibrisgroup.com/almaws/v1/acq/po-lines"

	#send updated xml to Alma web service as a POST to create POLs and save result as a variable
	result=$(curl -X POST -H "Authorization: apikey $(cat acq_prod_apikey.txt)" -H "Content-Type: application/xml" --data "${xmldoc}" $poststring)

	# extract PO-Line reference for newly created PO-Line
	pol_ref=$(echo "$result" | xmlstarlet sel -T -t -m '//po_line/number' -v '.')

	# extract fund code from  newly create PO-Line
	pol_fund=$(echo "$result" | xmlstarlet sel -T -t -m '//po_line/fund_distributions/fund_distribution/fund_code' -v '.')

	# extract MMS Id
	pol_mms=$(echo "$result" | xmlstarlet sel -T -t -m '//po_line/resource_metadata/mms_id' -v '.')

	# extract status
	pol_status=$(echo "$result" | xmlstarlet sel -T -t -m '//po_line/status' -v '.')

	# create tab delimited output
	echo -e "$fund \t $amount \t $note \t $pol_ref \t $pol_fund \t $pol_mms \t $pol_status"

done >> results.txt

# add header row to results.txt 
sed -i $'1 i\\\nfund\tamount\tnote\tpol_ref\tpol_fund\tpol_mms\tpol_status' results.txt
