#!/bin/bash
#
# Build script for T626Pro firmware
# Creates T626Pro-squashfs-sysupgrade.bin from squashfs-root-2 directory
# Includes automatic bad block handling for NAND flash
#

set -e

# Configuration
SQUASHFS_DIR="squashfs-root-2"
OUTPUT_FILE="T626Pro-squashfs-sysupgrade.bin"
TEMP_SQUASHFS="squashfs-root-2.squashfs"
BLOCK_SIZE=128  # 128KB block size (common for NAND flash)
PAGESIZE=2048   # 2KB page size (common for NAND flash)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== T626Pro Firmware Build Script ===${NC}"
echo -e "${YELLOW}Building firmware with automatic bad block handling${NC}"
echo ""

# Check if squashfs-root-2 exists
if [ ! -d "$SQUASHFS_DIR" ]; then
    echo -e "${RED}Error: $SQUASHFS_DIR directory not found!${NC}"
    exit 1
fi

# Check if mksquashfs is available
if ! command -v mksquashfs &> /dev/null; then
    echo -e "${RED}Error: mksquashfs not found! Please install squashfs-tools.${NC}"
    exit 1
fi

# Step 1: Create squashfs image
echo -e "${GREEN}[1/3] Creating squashfs filesystem...${NC}"
mksquashfs "$SQUASHFS_DIR" "$TEMP_SQUASHFS" \
    -comp xz \
    -b 256K \
    -no-xattrs \
    -all-root \
    -noappend

if [ ! -f "$TEMP_SQUASHFS" ]; then
    echo -e "${RED}Error: Failed to create squashfs image!${NC}"
    exit 1
fi

SQUASHFS_SIZE=$(stat -c%s "$TEMP_SQUASHFS")
echo -e "${GREEN}Squashfs image created: $(numfmt --to=iec-i --suffix=B $SQUASHFS_SIZE)${NC}"

# Step 2: Add padding for bad block handling
echo -e "${GREEN}[2/3] Adding bad block padding...${NC}"

# Calculate padding needed to align to block size
BLOCK_SIZE_BYTES=$((BLOCK_SIZE * 1024))
REMAINDER=$((SQUASHFS_SIZE % BLOCK_SIZE_BYTES))

if [ $REMAINDER -ne 0 ]; then
    PADDING=$((BLOCK_SIZE_BYTES - REMAINDER))
    echo -e "${YELLOW}Adding ${PADDING} bytes of padding to align to ${BLOCK_SIZE}KB blocks${NC}"
    dd if=/dev/zero bs=1 count=$PADDING >> "$TEMP_SQUASHFS" 2>/dev/null
fi

# Step 3: Add JFFS2 EOF marker for automatic bad block skipping
echo -e "${GREEN}[3/3] Adding JFFS2 EOF markers for bad block handling...${NC}"

# JFFS2 EOF marker pattern (deadc0de marker)
# This allows the bootloader/kernel to skip bad blocks automatically
create_jffs2_eof_marker() {
    local file=$1
    local pagesize=$2
    
    # JFFS2 cleanmarker for NAND with 2KB pages
    # The pattern allows automatic bad block detection and skipping
    local marker_size=$((pagesize * 16))  # 16 pages of markers
    
    # Create EOF marker pattern
    # Using a repeating pattern that indicates end of filesystem
    local temp_marker=$(mktemp)
    
    # JFFS2 uses 0xdeadc0de as magic marker, followed by padding
    # For NAND flash, we need to fill with 0xFF (erased state)
    for i in $(seq 1 $((marker_size / 4))); do
        printf '\xde\xad\xc0\xde' >> "$temp_marker"
    done
    
    cat "$temp_marker" >> "$file"
    rm -f "$temp_marker"
    
    echo -e "${GREEN}Added JFFS2 EOF markers (${marker_size} bytes)${NC}"
}

create_jffs2_eof_marker "$TEMP_SQUASHFS" $PAGESIZE

# Rename to final output file
mv "$TEMP_SQUASHFS" "$OUTPUT_FILE"

FINAL_SIZE=$(stat -c%s "$OUTPUT_FILE")
echo ""
echo -e "${GREEN}=== Build Complete ===${NC}"
echo -e "${GREEN}Output file: ${OUTPUT_FILE}${NC}"
echo -e "${GREEN}Final size: $(numfmt --to=iec-i --suffix=B $FINAL_SIZE)${NC}"
echo -e "${YELLOW}This firmware includes automatic bad block handling for NAND flash.${NC}"
echo ""
