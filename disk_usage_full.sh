#!/bin/bash

# WhatsApp Alert Config
WA_TOKEN="eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpZCI6IjY1ZjNiMjIyZWY1MmJjMzc4MDYxM2U1OSIsInVzZXJuYW1lIjoiY2hhbmRyYSIsImlhdCI6MTcxNzc0Nzc4NywiZXhwIjo0ODczNTA3Nzg3fQ.KIqEs7rELJzVj2hk6WJqCiYy0T0Mz7G5vbiy4gFLRQ0"
WA_SESSION="pasda"
WA_TARGET="08988588885"

if [ -n "$WA_TOKEN" ] && [ -n "$WA_SESSION" ] && [ -n "$WA_TARGET" ]; then
	THRESHOLD=90

	# Output file (argument or default)
	OUTPUT_FILE="${1:-/tmp/storage_report.txt}"

	# Clear file first
	: > "$OUTPUT_FILE"

	# ----------- System Info -----------
	MACHINE_NAME=$(hostname)
	OS_VERSION=$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')
	IP_ADDRESS=$(hostname -I | awk '{print $1}')
	TIMESTAMP=$(date +"%Y-%m-%d %H.%M.%S")

	# ----------- Write Header -----------
	{
		echo "============================="
		echo "   Partition Storage Usage Report"
		echo "============================="
		echo "Machine Name : $MACHINE_NAME"
		echo "Linux Ver.   : $OS_VERSION"
		echo "IP Address   : $IP_ADDRESS"
		echo "============================="
		echo
	} >> "$OUTPUT_FILE"

	# ----------- Disk Info -----------
	df -T -BG | awk -v outfile="$OUTPUT_FILE" '
	NR>1 && $2 !~ /(tmpfs|devtmpfs|overlay|squashfs)/ {
		fs=$1
		size=$3
		used=$4
		avail=$5
		mount=$7

		gsub("G","",size)
		gsub("G","",used)
		gsub("G","",avail)

		if (size == 0) next
		pct_used = (used / size) * 100

		# Get label
		cmd="blkid -o value -s LABEL " fs
		cmd | getline label
		close(cmd)
		if (label == "" || label ~ /^ *$/) label="(No Label)"

		printf "Drive: %s\n", mount >> outfile
		printf "  Label: %s\n", label >> outfile
		printf "  Total Size: %.2f GB\n", size >> outfile
		printf "  Used Space: %.2f GB (%.2f%%)\n", used, pct_used >> outfile
		printf "  Free Space: %.2f GB (%.2f%%)\n\n", avail, 100-pct_used >> outfile
	}
	'

	# ----------- Footer -----------
	{
		echo "============================="
		echo " Threshold for warning: ${THRESHOLD}%"
		echo " Generated: $TIMESTAMP"
	} >> "$OUTPUT_FILE"


	# WA SECTION
	MESSAGE="$OUTPUT_FILE"
	FILEPATH=""
	TARGET="$WA_TARGET"
	VERBOSE=false

	# Parse arguments
	while [[ $# -gt 0 ]]; do
		case "$1" in
			--message)
				MESSAGE="$2"
				shift 2
				;;
			--filepath)
				FILEPATH="$2"
				shift 2
				;;
			--target)
				TARGET="$2"
				shift 2
				;;
			--verbose)
				VERBOSE=true
				shift
				;;
			-*|--*)
				echo "Unknown option: $1"
				echo "Usage: $0 --message \"text or file.txt\" [--filepath /path/to/file] [--target 628xxxx] [--verbose]"
				exit 1
				;;
			*)
				shift
				;;
		esac
	done

	# ===================================
	# Validate and handle message argument
	# ===================================
	if [ -z "$MESSAGE" ]; then
		echo "❌ Error: --message is required"
		echo "Usage: $0 --message \"text or file.txt\" [--filepath /path/to/file] [--target 628xxxx]"
		exit 1
	fi

	# If message points to a text file, load its content
	if [ -f "$MESSAGE" ]; then
		if [[ "$MESSAGE" == *.txt ]]; then
			echo "📝 Reading message content from file: $MESSAGE"
			MESSAGE_CONTENT=$(cat "$MESSAGE")
			MESSAGE="$MESSAGE_CONTENT"
		else
			echo "⚠️  '$MESSAGE' exists but is not a .txt file, using its path as message text."
		fi
	fi

	# ===================================
	# Send message or media
	# ===================================
	if [ -n "$FILEPATH" ] && [ -f "$FILEPATH" ]; then
		MIMETYPE=$(file --mime-type -b "$FILEPATH")

		echo "📂 Sending file with caption..."
		# Capture response and HTTP status code
		HTTP_RESPONSE=$(curl --silent --show-error --location 'https://dialogwa.web.id/api/send-media' \
		--header "Authorization: Bearer $WA_TOKEN" \
		--form "session=$WA_SESSION" \
		--form "target=$TARGET" \
		--form "message=$MESSAGE" \
		--form "file=@$FILEPATH;type=$MIMETYPE" \
		--write-out '%{http_code}')
		
		# Extract HTTP status code (last 3 digits)
		HTTP_CODE="${HTTP_RESPONSE: -3}"
		# Extract response body (everything except last 3 digits)
		RESPONSE_BODY="${HTTP_RESPONSE%???}"

	else
		echo "💬 Sending text message..."
		# Capture response and HTTP status code
		HTTP_RESPONSE=$(curl --silent --show-error --location 'https://dialogwa.web.id/api/send-text' \
		--header "Authorization: Bearer $WA_TOKEN" \
		--form "session=$WA_SESSION" \
		--form "target=$TARGET" \
		--form "message=$MESSAGE" \
		--write-out '%{http_code}')
		
		# Extract HTTP status code (last 3 digits)
		HTTP_CODE="${HTTP_RESPONSE: -3}"
		# Extract response body (everything except last 3 digits)
		RESPONSE_BODY="${HTTP_RESPONSE%???}"
	fi

	# ===================================
	# Handle response
	# ===================================
	if [ "$VERBOSE" = true ] || [ "$HTTP_CODE" != "200" ]; then
		echo "HTTP Status Code: $HTTP_CODE"
		echo "Response Body: $RESPONSE_BODY"
	fi

	echo "$RESPONSE_BODY"
	exit 1
fi

echo "Set konfigurasi bot whatsapp terlebih dahulu..."
echo "WA_TOKEN: $(if [ -z "$WA_TOKEN" ]; then echo "❌"; else echo "✅"; fi)"
echo "WA_SESSION: $(if [ -z "$WA_SESSION" ]; then echo "❌"; else echo "✅"; fi)"
echo "WA_TARGET: $(if [ -z "$WA_TARGET" ]; then echo "❌"; else echo "✅"; fi)"
exit 1
