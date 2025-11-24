#!/bin/bash
#
# Test script to verify T626Pro firmware build
#

set -e

# Cross-platform file size function
get_file_size() {
    local file=$1
    if [[ "$OSTYPE" == "darwin"* ]] || [[ "$(uname -s)" == "Darwin" ]]; then
        # macOS
        stat -f%z "$file"
    else
        # Linux and others
        stat -c%s "$file"
    fi
}

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== T626Pro Firmware Build Test ===${NC}\n"

# Clean up previous builds
echo -e "${YELLOW}[1/5] Cleaning up previous builds...${NC}"
rm -f T626Pro-squashfs-sysupgrade.bin squashfs-root-2.squashfs
echo -e "${GREEN}✓ Cleanup complete${NC}\n"

# Run the build
echo -e "${YELLOW}[2/5] Running build script...${NC}"
if bash build-firmware.sh > /tmp/build.log 2>&1; then
    echo -e "${GREEN}✓ Build completed successfully${NC}\n"
else
    echo -e "${RED}✗ Build failed!${NC}"
    cat /tmp/build.log
    exit 1
fi

# Check output file exists
echo -e "${YELLOW}[3/5] Checking output file...${NC}"
if [ -f T626Pro-squashfs-sysupgrade.bin ]; then
    echo -e "${GREEN}✓ Output file exists${NC}"
else
    echo -e "${RED}✗ Output file not found!${NC}"
    exit 1
fi

# Verify file format
echo -e "${YELLOW}[4/5] Verifying file format...${NC}"
FILE_TYPE=$(file T626Pro-squashfs-sysupgrade.bin)
if echo "$FILE_TYPE" | grep -q "Squashfs filesystem"; then
    echo -e "${GREEN}✓ Valid Squashfs filesystem detected${NC}"
    echo -e "  $FILE_TYPE"
else
    echo -e "${RED}✗ Invalid file format!${NC}"
    echo -e "  $FILE_TYPE"
    exit 1
fi

# Verify JFFS2 EOF markers
echo -e "${YELLOW}[5/5] Verifying JFFS2 EOF markers...${NC}"
TAIL_BYTES=$(hexdump -C T626Pro-squashfs-sysupgrade.bin | tail -3 | head -1)
if echo "$TAIL_BYTES" | grep -q "de ad c0 de"; then
    echo -e "${GREEN}✓ JFFS2 EOF markers present${NC}"
else
    echo -e "${RED}✗ JFFS2 EOF markers not found!${NC}"
    echo "Last bytes:"
    hexdump -C T626Pro-squashfs-sysupgrade.bin | tail -5
    exit 1
fi

# Summary
echo -e "\n${GREEN}=== All Tests Passed ===${NC}"
echo -e "${GREEN}Firmware file: T626Pro-squashfs-sysupgrade.bin${NC}"
FILE_SIZE=$(get_file_size T626Pro-squashfs-sysupgrade.bin)
echo -e "${GREEN}Size: $(numfmt --to=iec-i --suffix=B $FILE_SIZE 2>/dev/null || echo "$((FILE_SIZE / 1024 / 1024))MB")${NC}"
echo ""

# Cleanup test build
rm -f /tmp/build.log

exit 0
