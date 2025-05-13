#!/bin/bash

# --- Colors ---
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
NC="\033[0m" # No Color

# --- Usage ---
usage() {
    echo -e "${YELLOW}Usage:${NC} $0 <bucket-name> | -f <bucket-list.txt> [threads]"
    echo -e "${YELLOW}Example 1:${NC} $0 my-bucket"
    echo -e "${YELLOW}Example 2:${NC} $0 -f buckets.txt 15"
    exit 1
}

# --- Init Summary Counters ---
ACCESSIBLE=0
WRITABLE=0
DELETABLE=0
INACCESSIBLE=0

# --- Single Bucket Check ---
check_bucket() {
    BUCKET="$1"
    TMP_FILE="s3scanner-test-$(date +%s)-$RANDOM.txt"
    TMP_LOG="s3scanner-result-$RANDOM.log"

    echo -e "\n${BLUE}[*] Checking bucket:${NC} $BUCKET"
    echo "------------------------------------------"

    echo -e "${BLUE}[+] List check:${NC}"
    aws s3 ls s3://$BUCKET/ --no-sign-request > /dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo -e "${RED}[-] Inaccessible or doesn't exist.${NC}"
        echo "INACCESSIBLE $BUCKET" >> summary.tmp
        return
    fi
    echo -e "${GREEN}[+] Bucket is accessible.${NC}"
    echo "ACCESSIBLE $BUCKET" >> summary.tmp

    echo -e "${BLUE}[+] Region:${NC}"
    aws s3api get-bucket-location --bucket $BUCKET --no-sign-request 2>&1

    echo -e "${BLUE}[+] ACL:${NC}"
    aws s3api get-bucket-acl --bucket $BUCKET --no-sign-request 2>&1

    echo -e "${BLUE}[+] Policy:${NC}"
    aws s3api get-bucket-policy --bucket $BUCKET --no-sign-request 2>&1

    echo -e "${BLUE}[+] Upload test file:${NC}"
    echo "Security test file for $BUCKET" > "$TMP_FILE"
    aws s3 cp "$TMP_FILE" s3://$BUCKET/$TMP_FILE --no-sign-request > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[!] Upload succeeded – public WRITE access.${NC}"
        echo "WRITABLE $BUCKET" >> summary.tmp

        echo -e "${BLUE}[+] Delete test file:${NC}"
        aws s3 rm s3://$BUCKET/$TMP_FILE --no-sign-request > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}[!] Delete succeeded – public DELETE access.${NC}"
            echo "DELETABLE $BUCKET" >> summary.tmp
        else
            echo -e "${YELLOW}[-] Delete failed – DELETE may be restricted.${NC}"
        fi
    else
        echo -e "${YELLOW}[-] Upload failed – no WRITE access.${NC}"
    fi

    echo -e "${BLUE}[+] Versioning status:${NC}"
    aws s3api get-bucket-versioning --bucket $BUCKET --no-sign-request 2>&1

    rm -f "$TMP_FILE"
    echo -e "${BLUE}[+] Done:${NC} $BUCKET"
}

# Export for xargs
export -f check_bucket
export GREEN RED YELLOW BLUE NC

# --- Main Logic ---
if [ "$1" == "-f" ]; then
    BUCKET_FILE="$2"
    THREADS="${3:-10}"
    [ ! -f "$BUCKET_FILE" ] && echo -e "${RED}[-] File not found:${NC} $BUCKET_FILE" && exit 1
    > summary.tmp
    cat "$BUCKET_FILE" | grep -v '^#' | grep -v '^$' | sort -u | xargs -P "$THREADS" -n 1 -I {} bash -c 'check_bucket "$@"' _ {}
elif [ -n "$1" ]; then
    > summary.tmp
    check_bucket "$1"
else
    usage
fi

# --- Final Summary ---
ACCESSIBLE=$(grep -c "^ACCESSIBLE" summary.tmp)
WRITABLE=$(grep -c "^WRITABLE" summary.tmp)
DELETABLE=$(grep -c "^DELETABLE" summary.tmp)
INACCESSIBLE=$(grep -c "^INACCESSIBLE" summary.tmp)
TOTAL=$((ACCESSIBLE + INACCESSIBLE))

echo -e "\n${BLUE}=========== Scan Summary ===========${NC}"
echo -e "${BLUE}Total buckets checked:${NC}     $TOTAL"
echo -e "${GREEN}Accessible:${NC}              $ACCESSIBLE"
echo -e "${GREEN}Writable:${NC}                $WRITABLE"
echo -e "${GREEN}Deletable:${NC}              $DELETABLE"
echo -e "${RED}Inaccessible:${NC}           $INACCESSIBLE"
echo -e "${BLUE}====================================${NC}"

rm -f summary.tmp
