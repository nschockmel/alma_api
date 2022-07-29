#!/bin/bash

### READ ME ############################################################################################################################################################################
# this script is to be executed before running the "creat_pols" script to create dummy PO lines for FY rollover/close
# this step is necessary before creating PO lines because some funding amounts and fund rules will cause the fund to fail to create a  PO line

# this script:
# 1. takes a file of fund codes (funds.txt) and makes API GET calls to verifie the funding rules and expenditure/encumbrances for a given fund
# 2. identifies funds that have a value other than "NO" for the over_encumbrance element AND where the (expends + encumbrances) > allocated balance ($change_rules)
# 3. returns a .txt file of all funds returned by the get calls (funds_check_results.txt)
# 4. returns a .txt file of funds that have have a value of "YES" in the $change_rules variable (funds_check_filtered.txt)

# in the future (if Libraries financial services gives the okay) this script should be adjusted to use the fund_id to make additional PUT calls to change the over_encumbrance rule
# value to "NO_LIMIT" to allow for PO line creation. After PO line creation, another script can be used to set the  over_encumbrance rule back to "NO"
########################################################################################################################################################################################

	# get the number of records in the .txt file containing IDs for the API calls
	recs=$(wc -l < funds.txt)

	# declare the environment (production or sandbox)
	alma_env="PRODUCTION"

	# ask for fiscal_period
	echo "Enter the numeric description for the fiscal period (e.g. 2023=10, 2024=11, 2025=12, 2026=13, 2027=14, etc)"

	read fiscal_period

	# indicate number of records/GET calls and confirm whether program should proceed
	read -p "This will send ${recs} GET calls to the Alma API in the ${alma_env} instance. Press Y if you wish to continue, otherwise press any other key to exit the program" -n 1 -r
	echo -e "\n"
	if [[ ! $REPLY =~ ^[Yy]$ ]]
	then
		exit 1
	fi

	echo "Thank you! The script is running and .txt files of results will appear in the directory in a few moments."


head funds.txt | while read item
do
	# create mode variable for API parameter
	mode="ALL"

	# extract funds code and expenditure and save as variables
	fund="$(cut -f 1 <<<$item)"
	expend="$(cut -f 2 <<<$item)"

	# create url for Alma retrieve funds web service
	getstring="https://api-na.hosted.exlibrisgroup.com/almaws/v1/acq/funds?q=fund_code~${fund}&fiscal_period=${fiscal_period}&mode=${mode}"

	# send GET request to retrieve fund xml object
	fund_doc=$(curl -s -H "Authorization: apikey $(cat acq_prod_apikey.txt)" -H "Accept: application/xml" -X GET $getstring)

	# extract ID from xml object (for use with future GET/PUT calls)
	fund_id=$(echo "$fund_doc" | xmlstarlet sel -T -t -m '//funds/fund/id' -v '.')

	# extract fund code from fund xml object
	fund_code=$(echo "$fund_doc" | xmlstarlet sel -T -t -m '//funds/fund/code' -v '.')

	# extract allocation from fund xml object
	alloc_bal=$(echo "$fund_doc" | xmlstarlet sel -T -t -m '//funds/fund/allocated_balance' -v '.')

	# extract encumbrance from fund xml object
	encumb_bal=$(echo "$fund_doc" | xmlstarlet sel -T -t -m '//funds/fund/encumbered_balance' -v '.')

	# extract fund overencumbrance rules
	over_enc=$(echo "$fund_doc" | xmlstarlet sel -T -t -m '//funds/fund/overencumbrance_allowed' -v '.')

	# extract fund overexpenditure rules
	over_exp=$(echo "$fund_doc" | xmlstarlet sel -T -t -m '//funds/fund/overexpenditure_allowed' -v '.')

	# use bc to convert numeric decimals into floats so they can do math
	exp_enc_sum=`echo "$expend" + "$encumb_bal" | bc`

	# add variable indicating if encumbrance + expenditures is less than allocated balance
	sum_less_than_alloc=$(if (( $( bc <<< "$exp_enc_sum > $alloc_bal") )); then echo "YES"; else echo "NO"; fi)

#	use logic for identifying funds with incompatible funding rules and expenditure/encumbrance combinations
	change_rules=$(if [[ "$over_enc" = "NO" ]] && [[ "$sum_less_than_alloc" = "YES" ]]; then echo "YES"; else echo "NO"; fi)

#	echo $fund"|"$expend"|"$alloc_bal"|"$encumb_bal"|"$exp_enc_sum"|"$sum_less_than_alloc"|"$over_enc

	# write output to comma delimited file
	echo -e "$fund\t$expend\t$fund_id\t$fund_code\t$alloc_bal\t$encumb_bal\t$exp_enc_sum\t$sum_less_than_alloc\t$over_enc\t$over_exp\t$change_rules"

	done > funds_check_results.txt

# add header line to full output
sed -i $'1 i\\\nfund_code_sent\texpend_from_fin_svc\tfund_id_returned\tfund_code_returned\tallocated_balance\tencumbered_balance\texp_plus_enc\tsum_less_than_alloc\tover_encumbrance_value\tover_expenditure_value\tchange_rules' funds_check_results.txt

# filter only to funds that need to be checked
awk '$11=="YES"' funds_check_results.txt > funds_check_filtered.txt

# add header line to filtered output
sed -i $'1 i\\\nfund_code_sent\texpend_from_fin_svc\tfund_id_returned\tfund_code_returned\tallocated_balance\tencumbered_balance\texp_plus_enc\tsum_less_than_alloc\tover_encumbrance_value\tover_expenditure_value\tchange_rules' funds_check_filtered.txt



