#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <mach-o/loader.h>
#include <mach-o/fat.h>

// Insert LC_LOAD_DYLIB into arm64 slice of a fat Mach-O binary
int main(int argc, char *argv[]) {
    if (argc != 4) {
        fprintf(stderr, "Usage: %s <dylib_path> <input> <output>\n", argv[0]);
        return 1;
    }

    FILE *f = fopen(argv[2], "rb");
    if (!f) { perror("fopen input"); return 1; }
    fseek(f, 0, SEEK_END);
    long file_size = ftell(f);
    fseek(f, 0, SEEK_SET);
    unsigned char *data = malloc(file_size);
    if (!data) { fprintf(stderr, "malloc failed\n"); return 1; }
    if (fread(data, 1, file_size, f) != (size_t)file_size) { fprintf(stderr, "read failed\n"); return 1; }
    fclose(f);

    uint32_t magic = *(uint32_t *)data;
    long arm64_offset = 0;
    long arm64_size = file_size;

    if (magic == FAT_MAGIC || magic == FAT_CIGAM) {
        struct fat_header *fh = (struct fat_header *)data;
        uint32_t narch = OSSwapBigToHostInt32(fh->nfat_arch);
        for (uint32_t i = 0; i < narch; i++) {
            struct fat_arch *fa = (struct fat_arch *)(data + sizeof(*fh) + i * sizeof(*fa));
            if (OSSwapBigToHostInt32(fa->cputype) == CPU_TYPE_ARM64) {
                arm64_offset = OSSwapBigToHostInt32(fa->offset);
                arm64_size = OSSwapBigToHostInt32(fa->size);
                break;
            }
        }
    }

    struct mach_header_64 *mh = (struct mach_header_64 *)(data + arm64_offset);
    if (mh->magic != MH_MAGIC_64) {
        fprintf(stderr, "arm64 slice not found (magic=0x%x)\n", mh->magic);
        return 1;
    }

    uint32_t dylib_path_len = (uint32_t)(strlen(argv[1]) + 1);
    uint32_t dylib_path_padded = (dylib_path_len + 7) & ~7;
    uint32_t lc_size = sizeof(struct dylib_command) + dylib_path_padded - offsetof(struct dylib_command, dylib.name.offset);

    // Find end of existing load commands
    unsigned char *lc_ptr = (unsigned char *)mh + sizeof(*mh);
    for (uint32_t i = 0; i < mh->ncmds; i++) {
        struct load_command *lc = (struct load_command *)lc_ptr;
        lc_ptr += lc->cmdsize;
    }
    uint32_t old_cmds_size = mh->sizeofcmds;
    uint32_t new_cmds_size = old_cmds_size + lc_size;

    // Total output size = new header + new load commands + rest of slice
    long new_slice_size = (long)(sizeof(*mh) + new_cmds_size + (arm64_size - (lc_ptr - (unsigned char *)mh)));
    long new_file_size = (magic == FAT_MAGIC || magic == FAT_CIGAM) ? file_size : new_slice_size;

    if (magic == FAT_MAGIC || magic == FAT_CIGAM) {
        // For fat binaries, copy everything and adjust the arm64 slice
        new_file_size = file_size + lc_size;
    }

    unsigned char *out = calloc(1, new_file_size + 0x1000);
    if (!out) { fprintf(stderr, "malloc out failed\n"); return 1; }
    memcpy(out, data, file_size);

    struct mach_header_64 *out_mh = (struct mach_header_64 *)(out + arm64_offset);
    
    if (magic == FAT_MAGIC || magic == FAT_CIGAM) {
        // Expand the arm64 by inserting lc_size bytes
        unsigned char *out_lc_base = (unsigned char *)out_mh + sizeof(*out_mh);
        unsigned char *old_lc_end = out_lc_base + old_cmds_size;
        unsigned char *old_slice_end = out + arm64_offset + arm64_size;
        // Move everything after load commands to make room
        memmove(out_lc_base + new_cmds_size, old_lc_end, old_slice_end - old_lc_end);
        // Update arm64 size in fat arch
        for (uint32_t i = 0; i < OSSwapBigToHostInt32(((struct fat_header *)out)->nfat_arch); i++) {
            struct fat_arch *fa = (struct fat_arch *)(out + sizeof(struct fat_header) + i * sizeof(struct fat_arch));
            if (OSSwapBigToHostInt32(fa->cputype) == CPU_TYPE_ARM64) {
                fa->size = OSSwapHostToBigInt32((uint32_t)(arm64_size + lc_size));
                break;
            }
        }
    } else {
        // Thin binary: just pad
        // (not implemented for simplicity)
    }

    // Insert the load dylib command at the end of load commands
    struct dylib_command *dc = (struct dylib_command *)((unsigned char *)out_mh + sizeof(*out_mh) + old_cmds_size);
    dc->cmd = LC_LOAD_DYLIB;
    dc->cmdsize = lc_size;
    // name.offset = position of string relative to start of dylib_command
    dc->dylib.name.offset = offsetof(struct dylib_command, dylib) + sizeof(struct dylib);
    dc->dylib.timestamp = 2;
    dc->dylib.current_version = 0x10000;
    dc->dylib.compatibility_version = 0x10000;
    // Copy the dylib path string right after the dylib struct
    char *path_dst = (char *)dc + dc->dylib.name.offset;
    memcpy(path_dst, argv[1], dylib_path_len);

    out_mh->ncmds++;
    out_mh->sizeofcmds = new_cmds_size;

    f = fopen(argv[3], "wb");
    if (!f) { perror("fopen output"); return 1; }
    long write_size = (magic == FAT_MAGIC || magic == FAT_CIGAM) ? new_file_size : new_slice_size;
    fwrite(out, 1, write_size, f);
    fclose(f);
    chmod(argv[3], 0755);

    printf("✓ Patched %s: inserted LC_LOAD_DYLIB for %s\n", argv[3], argv[1]);
    free(data);
    free(out);
    return 0;
}
