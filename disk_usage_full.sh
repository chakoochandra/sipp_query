#!/bin/bash

WA_TOKEN=""
WA_SESSION=""
WA_TARGET=""

TELEGRAM_BOT_TOKEN=""
MY_CHAT_ID=""

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

	if [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$MY_CHAT_ID" ]; then
		DEFAULT_PARSE_MODE="Markdown"
		MAX_PHOTO_SIZE=$((10 * 1024 * 1024)) # 10 MB
		MAX_FILE_SIZE=$((50 * 1024 * 1024)) # 50 MB - Telegram limit

		# Response handling options
		OUTPUT_MODE="human"  # Options: human, json, silent, raw
		LOG_RESPONSES=false
		RESPONSE_LOG_FILE="/tmp/telegram_alerts.log"
		INCLUDE_RESPONSE_BODY=false  # Include raw response in human/json output

		BOT_TOKEN="$TELEGRAM_BOT_TOKEN"
		DEFAULT_CHAT_ID="$MY_CHAT_ID"

		# === ESCAPE MESSAGE FOR MARKDOWN ===
		escape_message() {
			echo "$1" | sed -e 's/\*/\\*/g' \
							-e 's/_/\\_/g' \
							-e 's/\`/\\\`/g' \
							-e 's/\[/\\[/g'
		}

		# === MIME TYPE CHECK ===
		get_mime_type() {
			file --mime-type -b "$1"
		}

		# === PHOTO RESIZE IF NEEDED ===
		resize_image_if_needed() {
			local img="$1"
		local size
		size=$(stat -c %s "$img")
		if [ "$size" -le "$MAX_PHOTO_SIZE" ]; then
			echo "$img"
			return
		fi
		if ! command -v convert &>/dev/null; then
			echo "❌ Image too large and ImageMagick not installed."
			echo "$img"
			return
		fi
		local resized="/tmp/resized_$(basename "$img")"
		convert "$img" -resize 1024x1024\> "$resized"
		echo "$resized"
	}

	# === FORMAT FILE SIZE ===
	format_size() {
		local size=$1
		if command -v numfmt &>/dev/null; then
			numfmt --to=iec-i --suffix=B "$size"
		else
			if [ "$size" -lt 1024 ]; then
				echo "${size}B"
			elif [ "$size" -lt 1048576 ]; then
				echo "$((size / 1024))KB"
			else
				echo "$((size / 1048576))MB"
			fi
		fi
	}

	# === CURL REQUEST HELPER ===
	make_curl_request() {
		local url="$1"
		local method="${2:-POST}"
		local data_type="$3"  # form or urlencoded
		shift 3
		local args=("$@")

		# Execute curl command directly based on data type to avoid eval issues
		local temp_file=$(mktemp)
		if [[ "$data_type" == "form" ]]; then
			# Use curl with form data
			local http_code=$(curl --silent --location --output "$temp_file" --write-out '%{http_code}' -X "$method" "$url" "${args[@]/#/--form }")
		else
			# Use curl with urlencoded data - construct proper curl parameters
			local curl_params=()
			for arg in "${args[@]}"; do
				curl_params+=(-d "$arg")
			done
			local http_code=$(curl --silent --location --output "$temp_file" --write-out '%{http_code}' -X "$method" "$url" "${curl_params[@]}")
		fi

		local response=$(cat "$temp_file")
		rm "$temp_file"

		# Log response if enabled
		if [[ "$LOG_RESPONSES" == "true" ]]; then
			echo "[$(date '+%Y-%m-%d %H:%M:%S')] HTTP $http_code: $response" >> "$RESPONSE_LOG_FILE"
		fi

		# Return response based on output mode
		if [[ "$OUTPUT_MODE" == "raw" ]]; then
			# Always return the raw response body like send_wa_alert.sh does
			echo "$response"
		elif [[ "$OUTPUT_MODE" == "json" ]]; then
			if [[ "$INCLUDE_RESPONSE_BODY" == "true" ]]; then
				# Properly escape response for JSON
				local escaped_response=$(printf '%s' "$response" | sed 's/"/\\"/g; s/\\/\\\\/g; s/\t/\\t/g; s/\r/\\r/g; s/\n/\\n/g')
				echo "{\"status\": $http_code, \"response\": \"$escaped_response\"}"
			else
				echo "{\"status\": $http_code}"
			fi
		elif [[ "$OUTPUT_MODE" == "silent" ]]; then
			# Do nothing - no output
			:
		else  # default human mode
			if [[ "$http_code" == "200" ]]; then
				echo "✅ Kirim notifikasi telegram berhasil (HTTP $http_code)"
				if [[ "$INCLUDE_RESPONSE_BODY" == "true" ]]; then
					echo "Response: $response"
				fi
			else
				echo "❌ Kirim notifikasi telegram gagal (HTTP $http_code): $response"
			fi
		fi

		# Return appropriate exit code
		if [[ "$http_code" == "200" ]]; then
			return 0
		else
			return 1
		fi
	}

	# === SEND FILE WITH SIZE CHECK ===
	send_file_with_check() {
		local file="$1"
		local caption="$2"
		local chat_id="$3"
		local size
		size=$(stat -c %s "$file")
		
		if [ "$size" -gt "$MAX_FILE_SIZE" ]; then
			local size_formatted=$(format_size "$size")
			local limit_formatted=$(format_size "$MAX_FILE_SIZE")
			local filename=$(basename "$file")
			
			local error_msg="⚠️ *File Size Limit Exceeded*\n\n"
			error_msg+="📁 File: \`$filename\`\n"
			error_msg+="📊 Size: *$size_formatted*\n"
			error_msg+="🚫 Telegram Limit: *$limit_formatted*\n\n"
			error_msg+="❌ File cannot be sent via Telegram bot.\n"
			
			if [ -n "$caption" ]; then
				error_msg+="\n$caption"
			fi
			
			ESCAPED_MSG=$(escape_message "$error_msg")
			make_curl_request "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
				"POST" "urlencoded" \
				"chat_id=$chat_id" \
				"text=$ESCAPED_MSG" \
				"parse_mode=$DEFAULT_PARSE_MODE" \
				"disable_web_page_preview=true"
			
			local curl_result=$?
			if [[ "$curl_result" -eq 0 ]]; then
				echo "⚠️  File too large ($size_formatted). Notification sent instead."
			else
				echo "⚠️  File too large ($size_formatted). Failed to send notification."
			fi
			return 1
		fi
		
		ESCAPED_CAPTION=$(escape_message "$caption")
		make_curl_request "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument" \
			"POST" "form" \
			"chat_id=$chat_id" \
			"document=@$file" \
			"caption=$ESCAPED_CAPTION" \
			"parse_mode=$DEFAULT_PARSE_MODE"
		
		local curl_result=$?
		if [[ "$curl_result" -eq 0 ]]; then
			echo "✅ File sent successfully"
			return 0
		else
			echo "❌ Failed to send file"
			return 1
		fi
	}

	MODE="message"
	# Parse additional options
	while [[ $# -gt 0 && "$1" == --* ]]; do
		case "$1" in
			--output-mode)
				OUTPUT_MODE="$2"
				shift 2
				;;
			--log-responses)
				LOG_RESPONSES=true
				shift
				;;
			--include-response)
				INCLUDE_RESPONSE_BODY=true
				shift
				;;
			--file|--photo)
				MODE="${1:2}"
				shift
				FILE="$1"
				shift
				if [[ ! -f "$FILE" ]]; then echo "❌ File not found: $FILE"; exit 1; fi
				CAPTION="$1"
				shift
				CHAT_IDS=("$@")
				[[ ${#CHAT_IDS[@]} -eq 0 ]] && CHAT_IDS=("$DEFAULT_CHAT_ID")
				break
				;;
			*)
				echo "Unknown option: $1"
				usage
				;;
		esac
	done

	# If we didn't process --file/--photo in the loop, handle regular arguments
	MESSAGE="$OUTPUT_FILE"
	shift
	CHAT_IDS=("$@")
	[[ ${#CHAT_IDS[@]} -eq 0 ]] && CHAT_IDS=("$DEFAULT_CHAT_ID")

	# If message is a file path, load its content
	if [[ -f "$MESSAGE" ]]; then
		MESSAGE="$(cat "$MESSAGE")"
	fi

	# === SEND LOGIC ===
	overall_success=true
	for CHAT_ID in "${CHAT_IDS[@]}"; do
		if [[ "$MODE" == "message" ]]; then
			ESCAPED_MSG=$(escape_message "$MESSAGE")
			make_curl_request "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
				"POST" "urlencoded" \
				"chat_id=$CHAT_ID" \
				"text=$ESCAPED_MSG" \
				"parse_mode=$DEFAULT_PARSE_MODE" \
				"disable_web_page_preview=true"
			
			if [[ $? -ne 0 ]]; then
				overall_success=false
			fi
		elif [[ "$MODE" == "file" ]]; then
			if [[ "$FILE" == *.log ]]; then
				txt_copy="/tmp/$(basename "$FILE" .log).txt"
				cp "$FILE" "$txt_copy"
				FILE="$txt_copy"
			fi
			send_file_with_check "$FILE" "$CAPTION" "$CHAT_ID"
			if [[ $? -ne 0 ]]; then
				overall_success=false
			fi
		elif [[ "$MODE" == "photo" ]]; then
			MIME=$(get_mime_type "$FILE")
			if [[ "$MIME" != image/* ]]; then
				echo "❌ Not a valid image: $MIME"
				exit 1
			fi
			SEND_FILE=$(resize_image_if_needed "$FILE")
			ESCAPED_CAPTION=$(escape_message "$CAPTION")
			
			# Try to send as photo first
			make_curl_request "https://api.telegram.org/bot${BOT_TOKEN}/sendPhoto" \
				"POST" "form" \
				"chat_id=$CHAT_ID" \
				"photo=@$SEND_FILE" \
				"caption=$ESCAPED_CAPTION" \
				"parse_mode=$DEFAULT_PARSE_MODE"
			
			local photo_result=$?
			if [[ "$photo_result" -ne 0 ]]; then
				# Fallback to sending as document
				make_curl_request "https://api.telegram.org/bot${BOT_TOKEN}/sendDocument" \
					"POST" "form" \
					"chat_id=$CHAT_ID" \
					"document=@$FILE" \
					"caption=$ESCAPED_CAPTION" \
					"parse_mode=$DEFAULT_PARSE_MODE"
				
				if [[ $? -ne 0 ]]; then
					overall_success=false
				fi
			fi
		fi
	done
	fi
	exit 1
fi

echo "Set konfigurasi bot whatsapp terlebih dahulu..."
echo "WA_TOKEN: $(if [ -z "$WA_TOKEN" ]; then echo "❌"; else echo "✅"; fi)"
echo "WA_SESSION: $(if [ -z "$WA_SESSION" ]; then echo "❌"; else echo "✅"; fi)"
echo "WA_TARGET: $(if [ -z "$WA_TARGET" ]; then echo "❌"; else echo "✅"; fi)"
exit 1
