from PIL import Image

# UPC-A digit encoding (left-hand, odd parity)
UPC_A_ENCODING_LEFT = {
    "0": "0001101",
    "1": "0011001",
    "2": "0010011",
    "3": "0111101",
    "4": "0100011",
    "5": "0110001",
    "6": "0101111",
    "7": "0111011",
    "8": "0110111",
    "9": "0001011",
}

UPC_A_ENCODING_RIGHT = {
    "0": "1110010",
    "1": "1100110",
    "2": "1101100",
    "3": "1000010",
    "4": "1011100",
    "5": "1001110",
    "6": "1010000",
    "7": "1000100",
    "8": "1001000",
    "9": "1110100",
}

# UPC-A guard patterns
START_GUARD = "101"
CENTER_GUARD = "01010"
END_GUARD = "101"

def generate_upc_a_bmp(
    bmp_width,
    bmp_height,
    barcode_width,
    barcode_height,
    digits,
    output_file="barcode_with_digits.bmp",
    x_offset=0,
    y_offset=0,
):
    """
    Generate a 1bpp BMP image for a UPC-A barcode with digits underneath.
    :param bmp_width: Width of the BMP image in pixels.
    :param bmp_height: Height of the BMP image in pixels.
    :param barcode_width: Width of the barcode area in pixels.
    :param barcode_height: Height of the barcode area in pixels.
    :param digits: 12-digit UPC-A code (as a string or list of integers).
    :param output_file: Output file name.
    :param x_offset: Horizontal offset for the barcode within the BMP.
    :param y_offset: Vertical offset for the barcode within the BMP.
    """
    if len(digits) != 12 or not all(d.isdigit() for d in digits):
        raise ValueError("UPC-A must consist of exactly 12 numeric digits.")

    # Build the full barcode pattern
    barcode_pattern = START_GUARD  # Start guard

    # Left side (first 6 digits)
    for digit in digits[:6]:
        barcode_pattern += UPC_A_ENCODING_LEFT[digit]

    # Center guard
    barcode_pattern += CENTER_GUARD

    # Right side (last 6 digits)
    for digit in digits[6:]:
        barcode_pattern += UPC_A_ENCODING_RIGHT[digit]

    # End guard
    barcode_pattern += END_GUARD

    # Validate total bits (should be 95)
    if len(barcode_pattern) != 95:
        raise ValueError("Barcode pattern must be 95 bits long.")

    # Create a blank BMP image (1 bpp mode)
    img = Image.new("1", (bmp_width, bmp_height), "white")  # White background

    # Determine the width of each bar (bit) in the barcode area
    bar_width = barcode_width // len(barcode_pattern)

    # Determine starting positions with the specified offset
    x_start = x_offset
    y_start = y_offset

    # Ensure the barcode fits within the image
    if x_start + barcode_width > bmp_width or y_start + barcode_height > bmp_height:
        raise ValueError("Barcode dimensions and offset exceed BMP boundaries.")

    # Draw the barcode
    pixels = img.load()
    for i, bit in enumerate(barcode_pattern):
        color = 0 if bit == "1" else 1  # Black for '1', White for '0'
        bar_x_start = x_start + i * bar_width
        bar_x_end = bar_x_start + bar_width

        # Prolong the first and last bars to cover the digits
        if i == 0 or i == len(barcode_pattern) - 1:  # First or last bar
            prolonged_y_start = y_start - (barcode_height // 5)  # Extend upward
            prolonged_y_end = y_start + barcode_height + (barcode_height // 5)  # Extend downward
        else:
            prolonged_y_start = y_start
            prolonged_y_end = y_start + barcode_height

        for x in range(bar_x_start, bar_x_end):
            for y in range(prolonged_y_start, prolonged_y_end):
                if 0 <= x < bmp_width and 0 <= y < bmp_height:  # Ensure within bounds
                    pixels[x, y] = color

    # Save the image as a BMP
    img.save(output_file, "BMP")
    print(f"Barcode with digits saved to {output_file}")


# Example Usage
generate_upc_a_bmp(
    bmp_width=1000, 
    bmp_height=1000, 
    barcode_width=95, 
    barcode_height=200, 
    digits="876543210911", 
    output_file="876543210911_with_offset.bmp",
    x_offset=50,   # Horizontal offset
    y_offset=200,  # Vertical offset
)
