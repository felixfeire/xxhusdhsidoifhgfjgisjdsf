import struct
import os

# Configurações básicas
SECTOR_SIZE = 512
TOTAL_SECTORS = 2880  # 1.44MB floppy (512 * 2880 = 1,474,560 bytes)
FAT12_MEDIA_DESCRIPTOR = 0xF0

# Caminho do notepad.exe (ajuste se quiser)
NOTEPAD_PATH = "notepad.exe"
OUTPUT_IMG = "floppy.img"

# Constantes FAT12
RESERVED_SECTORS = 1
NUM_FATS = 2
SECTORS_PER_FAT = 9
ROOT_DIR_ENTRIES = 224
ROOT_DIR_SECTORS = (ROOT_DIR_ENTRIES * 32 + (SECTOR_SIZE - 1)) // SECTOR_SIZE
FIRST_DATA_SECTOR = RESERVED_SECTORS + NUM_FATS * SECTORS_PER_FAT + ROOT_DIR_SECTORS

def create_boot_sector():
    bs = bytearray(SECTOR_SIZE)
    # Jump instruction
    bs[0:3] = b'\xEB\x3C\x90'
    # OEM name
    bs[3:11] = b'MKFLOPPY'
    # Bytes per sector
    struct.pack_into('<H', bs, 11, SECTOR_SIZE)
    # Sectors per cluster
    bs[13] = 1
    # Reserved sectors count
    struct.pack_into('<H', bs, 14, RESERVED_SECTORS)
    # Number of FATs
    bs[16] = NUM_FATS
    # Root dir entries
    struct.pack_into('<H', bs, 17, ROOT_DIR_ENTRIES)
    # Total sectors (small)
    struct.pack_into('<H', bs, 19, TOTAL_SECTORS)
    # Media descriptor
    bs[21] = FAT12_MEDIA_DESCRIPTOR
    # Sectors per FAT
    struct.pack_into('<H', bs, 22, SECTORS_PER_FAT)
    # Sectors per track (18 for 1.44MB floppy)
    struct.pack_into('<H', bs, 24, 18)
    # Number of heads
    struct.pack_into('<H', bs, 26, 2)
    # Hidden sectors
    struct.pack_into('<I', bs, 28, 0)
    # Total sectors (large) - zero for floppy
    struct.pack_into('<I', bs, 32, 0)
    # Drive number
    bs[36] = 0x00
    # Reserved
    bs[37] = 0
    # Boot signature
    bs[38] = 0x29
    # Volume ID
    struct.pack_into('<I', bs, 39, 12345678)
    # Volume label (11 bytes)
    bs[43:54] = b'NO NAME    '
    # File system type
    bs[54:62] = b'FAT12   '
    # Boot sector signature
    bs[510:512] = b'\x55\xAA'
    return bs

def create_fat():
    # FAT12 - first 3 bytes encode media descriptor + EOF
    fat = bytearray(SECTOR_SIZE * SECTORS_PER_FAT)
    fat[0] = FAT12_MEDIA_DESCRIPTOR
    fat[1] = 0xFF
    fat[2] = 0xFF
    return fat

def filename_to_direntry_name(filename):
    # Converts "NOTEPAD.EXE" to 11-byte FAT name (8 + 3)
    name, ext = (filename.split('.') + [''])[:2]
    name = name.upper().ljust(8)
    ext = ext.upper().ljust(3)
    return (name + ext).encode('ascii')

def create_root_dir_entry(filename, start_cluster, size):
    entry = bytearray(32)
    entry[0:11] = filename_to_direntry_name(filename)
    entry[11] = 0x20  # Archive attribute
    # Reserved and time stamps zeroed (for simplicity)
    # First cluster
    struct.pack_into('<H', entry, 26, start_cluster)
    # File size
    struct.pack_into('<I', entry, 28, size)
    return entry

def write_file_clusters(disk_image, start_sector, data):
    cluster = 2
    offset = start_sector * SECTOR_SIZE
    disk_image.seek(offset)
    disk_image.write(data)
    # Pad last sector if needed
    remainder = len(data) % SECTOR_SIZE
    if remainder != 0:
        disk_image.write(b'\x00' * (SECTOR_SIZE - remainder))

def main():
    if not os.path.isfile(NOTEPAD_PATH):
        print(f"Erro: arquivo {NOTEPAD_PATH} não encontrado.")
        return

    with open(NOTEPAD_PATH, "rb") as f:
        file_data = f.read()
    file_size = len(file_data)

    # Cria imagem vazia
    with open(OUTPUT_IMG, "wb") as f:
        f.write(b'\x00' * SECTOR_SIZE * TOTAL_SECTORS)

    with open(OUTPUT_IMG, "r+b") as f:
        # Escreve boot sector
        bs = create_boot_sector()
        f.seek(0)
        f.write(bs)

        # Escreve FATs (2 vezes)
        fat = create_fat()
        for i in range(NUM_FATS):
            f.seek((RESERVED_SECTORS + i * SECTORS_PER_FAT) * SECTOR_SIZE)
            f.write(fat)

        # Escreve diretório raiz
        root_dir_offset = (RESERVED_SECTORS + NUM_FATS * SECTORS_PER_FAT) * SECTOR_SIZE
        f.seek(root_dir_offset)
        entry = create_root_dir_entry(os.path.basename(NOTEPAD_PATH), start_cluster=2, size=file_size)
        f.write(entry)

        # Escreve arquivo na cluster 2 (começa na data area)
        data_area_sector = FIRST_DATA_SECTOR
        f.seek(data_area_sector * SECTOR_SIZE)
        f.write(file_data)

    print(f"Imagem {OUTPUT_IMG} criada com sucesso!")

if __name__ == "__main__":
    main()
