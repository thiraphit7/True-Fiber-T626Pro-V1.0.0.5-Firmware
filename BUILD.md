# Building T626Pro Firmware

This document describes how to build the T626Pro firmware image from the squashfs-root-2 directory.

## Prerequisites

- Linux system (Ubuntu/Debian recommended)
- `squashfs-tools` package installed
- Bash shell

To install squashfs-tools on Ubuntu/Debian:
```bash
sudo apt-get install squashfs-tools
```

## Building the Firmware

To build the firmware image with automatic bad block handling, run:

```bash
./build-firmware.sh
```

This will create `T626Pro-squashfs-sysupgrade.bin` in the current directory.

## Build Process Details

The build script performs the following steps:

### 1. Create Squashfs Filesystem
- Uses `mksquashfs` to create a compressed filesystem from `squashfs-root-2/`
- Compression: XZ (high compression ratio)
- Block size: 256KB (optimized for flash storage)
- Options: no xattrs, all-root ownership

### 2. Add Bad Block Padding
- Adds padding to align the image to 128KB blocks
- This alignment is required for NAND flash devices
- Ensures proper flash sector alignment

### 3. Add JFFS2 EOF Markers
- Appends JFFS2 end-of-filesystem markers (0xdeadc0de pattern)
- These markers enable automatic bad block detection and skipping
- The bootloader/kernel can skip bad blocks during flashing and runtime
- Marker size: 32KB (16 pages × 2KB page size)

## Technical Details

### Bad Block Handling

NAND flash memory used in GPON devices can develop bad blocks over time. The firmware includes automatic bad block handling through:

1. **Block Alignment**: The firmware is aligned to 128KB boundaries, matching typical NAND erase block sizes.

2. **JFFS2 EOF Markers**: The firmware includes JFFS2 end-of-filesystem markers that signal to the flash driver where the filesystem ends. When bad blocks are encountered:
   - The bootloader can skip them during initial flashing
   - The kernel's MTD (Memory Technology Device) subsystem automatically handles bad block remapping
   - Data integrity is maintained by using redundant storage areas

3. **Flash Layout**: The firmware structure is:
   ```
   [Squashfs Filesystem] → [Padding] → [JFFS2 EOF Markers]
   ```

### Flash Specifications

The firmware is optimized for NAND flash with:
- Erase block size: 128KB
- Page size: 2KB
- Common in TC3162-based GPON ONTs

## Output File

- **Filename**: `T626Pro-squashfs-sysupgrade.bin`
- **Format**: Squashfs filesystem with bad block handling
- **Size**: ~19MB (may vary slightly based on content)
- **Compression**: XZ compressed

## Flashing Instructions

**Warning**: Flashing firmware can brick your device if done incorrectly. Proceed with caution.

The firmware can be flashed using:
1. Web interface (if supported by your device)
2. UART/serial console with bootloader commands
3. TFTP recovery mode

Example bootloader command (via UART):
```
tftpboot 0x84000000 T626Pro-squashfs-sysupgrade.bin
nand erase.chip
nand write 0x84000000 0x0 ${filesize}
reset
```

**Note**: Bad blocks will be automatically skipped during the NAND write operation.

## Troubleshooting

### Build Fails with "mksquashfs not found"
Install squashfs-tools:
```bash
sudo apt-get install squashfs-tools
```

### Firmware Too Large
If the firmware exceeds your flash partition size, you may need to:
- Remove unnecessary files from `squashfs-root-2/`
- Increase compression (already using XZ, the highest)
- Check if your device has sufficient flash capacity

### Bad Blocks During Flashing
The firmware includes automatic bad block handling. Modern bootloaders will:
- Detect bad blocks automatically
- Skip them during writing
- Use factory-marked bad block tables

If you encounter errors during flashing, ensure your bootloader supports bad block management.

## License

This firmware is for educational and research purposes. Ensure you have the right to modify and flash firmware on your device.
