#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#pragma pack(1)

// Struct for BMP file header (14 bytes)
typedef struct {
    unsigned short type;     // File type (BM in int)
    unsigned int size;       // Size of the BMP in bytes
    unsigned short res1;     
    unsigned short res2;     
    unsigned int offset;     
} BMP_FILE_HEADER;


typedef struct {
    unsigned int header_size;     // Size of this header
    int width;                    
    int height;                   
    unsigned short planes;        // Number of color planes
    unsigned short bit_count;     // Bits per pixel
    unsigned int compression;     // Compression type
    unsigned int image_size;      // Size of the pixel data in bytes
    int x_ppm;                    // Horizontal resolution
    int y_ppm;                    // Vertical resolution 
    unsigned int colors_used;     // Number of colors in the palette
    unsigned int colors_important; // Number of important colors 
} BMP_INFO_HEADER;


extern int readupca(void *img, uint32_t width, uint32_t height, uint8_t *digits);

int main(int args, char **argv) {
    // Check if the user provided the BMP file as an argument
    if (args < 2) {
        printf("Usage: %s <bmp_file>\n", argv[0]); // Print usage instructions
        return 1;
    }

    // Get the file name from the command-line argument
    char *file_name = argv[1];

    // Open the BMP file in binary read mode
    FILE *fp = fopen(file_name, "rb");
    if (!fp) { // If the file cannot be opened
        printf("ERROR: Cannot open file %s\n", file_name);
        return 1;
    }

    // Read the BMP file header
    BMP_FILE_HEADER file_header;
    fread(&file_header, sizeof(BMP_FILE_HEADER), 1, fp);

    // Check if the file is a valid BMP by verifying the 'BM' identifier
    if (file_header.type != (('M' << 8) | 'B')) {
        printf("ERROR: Not a BMP file\n");
        fclose(fp); 
        return 1;
    }

    // Read the BMP info header
    BMP_INFO_HEADER info_header;
    fread(&info_header, sizeof(BMP_INFO_HEADER), 1, fp);

    printf("%d",info_header.bit_count);
    // Verify if the image is 1 bpp (bits per pixel)
    if (info_header.bit_count != 1) {
        printf("ERROR: Only 1 bpp BMP files are supported.\n");
        fclose(fp);
        return 1;
    }

    // Allocate a buffer to hold the entire BMP file
    unsigned char *bmp_data = (unsigned char *)malloc(file_header.size);
    if (!bmp_data) {
        printf("ERROR: Memory allocation failed\n");
        fclose(fp);
        return 1;
    }

    // Move the file pointer to the beginning of the file and read the entire file into the buffer
    fseek(fp, 0, SEEK_SET);
    fread(bmp_data, file_header.size, 1, fp);

    // Calculate the pointer to the start of the pixel data
    unsigned char *pixel_data = bmp_data + file_header.offset;

    printf("BMP INFO:\n");
    printf("Size: %i bytes\n", file_header.size);
    printf("Offset: %i bytes\n", file_header.offset);
    printf("Width: %d px\n", info_header.width); 
    printf("Height: %d px\n", info_header.height);

    uint8_t digits[12] = {0};

    int result = readupca(pixel_data, info_header.width-1, info_header.height-1, digits);
    
    printf("\nDetected UPC-A Barcode:\n");
    for (int i = 0; i < 12; i++) {
        printf("%d ", digits[i]);
    }

    printf("\n");
    fclose(fp);

    return 0;
}
