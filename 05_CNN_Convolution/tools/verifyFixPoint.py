import numpy as np
from PIL import Image


def load_bmp_image(filename):
    """Load BMP image and convert to grayscale numpy array"""
    img = Image.open(filename).convert('L')
    return np.array(img, dtype=np.uint8)

full_img = load_bmp_image('input-64x64.bmp')
full_img_inv = 255 - full_img  

print(f"Full image shape: {full_img.shape}")

img_7 = load_bmp_image('input-7.bmp')   # 12x8
img_8 = load_bmp_image('input-8.bmp')   # 12x8

print(f"Digit 7 shape: {img_7.shape}")
print(f"Digit 8 shape: {img_8.shape}")


def create_kernel(img):
    """Create normalized kernel from BMP image"""
    img_inv = 255 - img
    
    kernel_binary = np.where(img_inv > 100, 1, -1)
    
    kernel_norm = kernel_binary - np.mean(kernel_binary)
    
    return kernel_norm

kernel_7_float = create_kernel(img_7)
kernel_8_float = create_kernel(img_8)

print(f"\nFloat kernels:")
print(f"Kernel 7 - Mean: {np.mean(kernel_7_float):.6f}")
print(f"Kernel 8 - Mean: {np.mean(kernel_8_float):.6f}")



def quantize_kernel(kernel_float, bits=8):
    """
    Convert float kernel (-1 to +1) to signed fixed-point
    bits: number of bits (including sign)
    """
    max_val = 2**(bits-1) - 1  # 127 for 8-bit
    min_val = -2**(bits-1)      # -128 for 8-bit
    
    # Scale from [-1, 1] to [-max_val, max_val]
    scaled = kernel_float * max_val
    
    # Round to nearest integer
    quantized = np.round(scaled)
    
    # Clamp to range
    quantized = np.clip(quantized, min_val, max_val)
    
    return quantized.astype(np.int8)

kernel_7_fixed = quantize_kernel(kernel_7_float, bits=8)
kernel_8_fixed = quantize_kernel(kernel_8_float, bits=8)

print(f"\nFixed-point kernels (8-bit signed):")
print(f"Kernel 7 - Min: {np.min(kernel_7_fixed)}, Max: {np.max(kernel_7_fixed)}")
print(f"Kernel 8 - Min: {np.min(kernel_8_fixed)}, Max: {np.max(kernel_8_fixed)}")

error_7 = np.abs(kernel_7_float - kernel_7_fixed.astype(np.float32) / 127)
error_8 = np.abs(kernel_8_float - kernel_8_fixed.astype(np.float32) / 127)

print(f"\nQuantization error:")
print(f"Kernel 7 - Mean: {np.mean(error_7):.6f}, Max: {np.max(error_7):.6f}")
print(f"Kernel 8 - Mean: {np.mean(error_8):.6f}, Max: {np.max(error_8):.6f}")



def apply_convolution_fixed(img, kernel_fixed):
    """Convolution with fixed-point kernels"""
    k_h, k_w = kernel_fixed.shape
    h, w = img.shape
    out_h = h - k_h + 1
    out_w = w - k_w + 1
    
    conv_map = np.zeros((out_h, out_w), dtype=np.int64)
    
    for r in range(out_h):
        for c in range(out_w):
            acc = 0
            for i in range(k_h):
                for j in range(k_w):
                    acc += img[r+i, c+j].astype(np.int64) * kernel_fixed[i, j].astype(np.int64)
            conv_map[r, c] = acc
    
    return conv_map

# اجرای کانولوشن
print("\nRunning convolution with fixed-point kernels...")
conv_7_fixed = apply_convolution_fixed(full_img_inv, kernel_7_fixed)
conv_8_fixed = apply_convolution_fixed(full_img_inv, kernel_8_fixed)

print(f"Conv 7 shape: {conv_7_fixed.shape}")
print(f"Conv 8 shape: {conv_8_fixed.shape}")


y7_fixed, x7_fixed = np.unravel_index(np.argmax(conv_7_fixed), conv_7_fixed.shape)
y8_fixed, x8_fixed = np.unravel_index(np.argmax(conv_8_fixed), conv_8_fixed.shape)

print("\n" + "="*60)
print("RESULTS WITH FIXED-POINT KERNELS (8-bit):")
print("="*60)
print(f"Digit 7: Max = {conv_7_fixed[y7_fixed, x7_fixed]} at (X={x7_fixed}, Y={y7_fixed})")
print(f"Digit 8: Max = {conv_8_fixed[y8_fixed, x8_fixed]} at (X={x8_fixed}, Y={y8_fixed})")
print("="*60)



def save_fixed_kernel_verilog(kernel, name, filename):
    with open(filename, 'w') as f:
        f.write(f"// Fixed-point Kernel for digit {name}\n")
        f.write(f"// Shape: {kernel.shape[0]}x{kernel.shape[1]}\n")
        f.write(f"// 8-bit signed fixed-point\n")
        f.write(f"reg signed [7:0] kernel_{name} [0:{kernel.shape[0]-1}][0:{kernel.shape[1]-1}];\n")
        f.write(f"initial begin\n")
        for i in range(kernel.shape[0]):
            f.write(f"    kernel_{name}[{i}] = {{")
            for j in range(kernel.shape[1]):
                val = int(kernel[i, j])
                if val < 0:
                    hex_val = format(val & 0xFF, '02X')
                else:
                    hex_val = format(val, '02X')
                f.write(f"8'h{hex_val}")
                if j < kernel.shape[1] - 1:
                    f.write(", ")
            f.write("};\n")
        f.write("end\n")

save_fixed_kernel_verilog(kernel_7_fixed, "7", "kernel_7_fixed.v")
save_fixed_kernel_verilog(kernel_8_fixed, "8", "kernel_8_fixed.v")

print("\n✅ Fixed-point kernels saved to:")
print("   - kernel_7_fixed.v")
print("   - kernel_8_fixed.v")


def print_fixed_kernel_verilog(kernel, name):
    print(f"\n// Fixed-point Kernel {name} (8-bit signed):")
    for i, row in enumerate(kernel):
        hex_values = []
        for val in row:
            val_int = int(val)
            if val_int < 0:
                hex_val = format(val_int & 0xFF, '02X')
            else:
                hex_val = format(val_int, '02X')
            hex_values.append(f"8'h{hex_val}")
        if i == kernel.shape[0] - 1:
            print(f"{{{', '.join(hex_values)}}}")
        else:
            print(f"{{{', '.join(hex_values)}}},")

print("\n" + "="*60)
print("FIXED-POINT KERNELS FOR VERILOG (Copy these):")
print("="*60)
print_fixed_kernel_verilog(kernel_7_fixed, "7")
print_fixed_kernel_verilog(kernel_8_fixed, "8")


print("\n" + "="*60)
print("ACCUMULATOR WIDTH CALCULATION:")
print("="*60)
print(f"Kernel size: 12 x 8 = 96 taps")
print(f"Input bits: 8-bit unsigned (0-255)")
print(f"Kernel bits: 8-bit signed (-128 to 127)")
print(f"Product bits: 8 + 8 = 16 bits")
print(f"Number of taps: 96")
print(f"Accumulator bits needed: 16 + log2(96) = 16 + 7 = 23 bits")
print(f"Recommended accumulator: 24 bits signed")

max_product = 255 * 127
max_accum = max_product * 96
bits_needed = int(np.ceil(np.log2(max_accum + 1)) + 1)

print(f"\nWorst-case accumulator value: {max_accum:,}")
print(f"Bits needed: {bits_needed} bits")

print("\n" + "="*60)
print("✅ Step 2 Complete!")
print("="*60)