import numpy as np
import matplotlib.pyplot as plt
from PIL import Image

# 1. Load full image from BMP
def load_bmp_image(filename):
    img = Image.open(filename).convert('L')
    return np.array(img, dtype=np.uint8)

# 2. Load cropped templates from BMP
def load_bmp_template(filename):
    img = Image.open(filename).convert('L')
    return np.array(img, dtype=np.uint8)

# Load images
full_img = load_bmp_image('input-64x64.bmp')
img_7 = load_bmp_template('input-7.bmp')   # 12x8
img_8 = load_bmp_template('input-8.bmp')   # 12x8

print(f"Full image shape: {full_img.shape}")
print(f"Digit 7 shape: {img_7.shape}")
print(f"Digit 8 shape: {img_8.shape}")

# Invert (background=0, digit>0)
full_img_inv = 255 - full_img

# 3. Build kernels with normalization
threshold = 128
kernel_7 = np.where(img_7 < threshold, 1, -1)   # digit = +1, background = -1
kernel_8 = np.where(img_8 < threshold, 1, -1)

# Normalize to zero mean
kernel_7_norm = kernel_7 - np.mean(kernel_7)
kernel_8_norm = kernel_8 - np.mean(kernel_8)

print(f"Kernel 7 mean: {np.mean(kernel_7_norm):.6f}")
print(f"Kernel 8 mean: {np.mean(kernel_8_norm):.6f}")

# 4. Convolution function
def apply_convolution(image, kernel):
    k_h, k_w = kernel.shape
    h, w = image.shape
    
    out_h = h - k_h + 1
    out_w = w - k_w + 1
    conv_map = np.zeros((out_h, out_w), dtype=np.float32)
    
    for r in range(out_h):
        for c in range(out_w):
            window = image[r:r+k_h, c:c+k_w]
            conv_map[r, c] = np.sum(window * kernel)
    
    return conv_map

# 5. Apply convolution
conv_7 = apply_convolution(full_img_inv, kernel_7_norm)
conv_8 = apply_convolution(full_img_inv, kernel_8_norm)

# 6. Find maximum points
y7, x7 = np.unravel_index(np.argmax(conv_7), conv_7.shape)
y8, x8 = np.unravel_index(np.argmax(conv_8), conv_8.shape)

print("="*60)
print(f"Digit 7: Max = {conv_7[y7, x7]:.0f} at (X={x7}, Y={y7})")
print(f"Digit 8: Max = {conv_8[y8, x8]:.0f} at (X={x8}, Y={y8})")
print("="*60)

# 7. Save kernels for Verilog (FIXED)
def save_kernel_verilog(kernel, name, filename):
    with open(filename, 'w') as f:
        f.write(f"// Kernel for digit {name}\n")
        f.write(f"// Shape: {kernel.shape[0]}x{kernel.shape[1]}\n")
        f.write(f"// Normalized zero-mean kernel\n")
        f.write(f"reg signed [7:0] kernel_{name} [0:{kernel.shape[0]-1}][0:{kernel.shape[1]-1}];\n")
        f.write(f"initial begin\n")
        for i in range(kernel.shape[0]):
            f.write(f"    kernel_{name}[{i}] = {{")
            for j in range(kernel.shape[1]):
                val = kernel[i, j]
                # Quantize to 8-bit signed with proper clamping
                quantized = np.clip(val * 127, -128, 127)
                # Convert to integer and ensure it's in 0-255 range for hex
                int_val = int(round(quantized))
                # Handle negative values for 8-bit signed representation
                if int_val < 0:
                    hex_val = format(int_val + 256, '02X')
                else:
                    hex_val = format(int_val, '02X')
                f.write(f"8'h{hex_val}")
                if j < kernel.shape[1] - 1:
                    f.write(", ")
            f.write("};\n")
        f.write("end\n")

save_kernel_verilog(kernel_7_norm, "7", "kernel_7.v")
save_kernel_verilog(kernel_8_norm, "8", "kernel_8.v")

print("\n✅ Kernels saved to kernel_7.v and kernel_8.v")

# 8. Print Verilog format (FIXED)
def print_verilog_kernel(kernel, name):
    print(f"\n// Verilog Array for {name} ({kernel.shape[0]}x{kernel.shape[1]}):")
    for i, row in enumerate(kernel):
        hex_values = []
        for val in row:
            # Quantize with proper clamping
            quantized = np.clip(val * 127, -128, 127)
            int_val = int(round(quantized))
            # Handle negative values for 8-bit signed representation
            if int_val < 0:
                hex_val = format(int_val + 256, '02X')
            else:
                hex_val = format(int_val, '02X')
            hex_values.append(f"8'h{hex_val}")
        if i == kernel.shape[0] - 1:
            print(f"{{{', '.join(hex_values)}}}")
        else:
            print(f"{{{', '.join(hex_values)}}},")

print("\n" + "="*60)
print("VERILOG KERNELS (Copy these into your Verilog code):")
print("="*60)
print_verilog_kernel(kernel_7_norm, "Kernel 7")
print_verilog_kernel(kernel_8_norm, "Kernel 8")

# 9. Visualize results
fig, axes = plt.subplots(2, 3, figsize=(15, 10))

# Original image with detected positions
axes[0, 0].imshow(full_img_inv, cmap='gray')
axes[0, 0].plot(x7, y7, 'bx', markersize=12, markeredgewidth=3, label='Digit 7')
axes[0, 0].plot(x8, y8, 'rx', markersize=12, markeredgewidth=3, label='Digit 8')
axes[0, 0].set_title('Detected Positions')
axes[0, 0].legend()
axes[0, 0].axis('off')

# Convolution map for 7
im1 = axes[0, 1].imshow(conv_7, cmap='hot')
axes[0, 1].plot(x7, y7, 'bx', markersize=12, markeredgewidth=3)
axes[0, 1].set_title(f'Conv 7 Max at ({x7}, {y7})')
axes[0, 1].axis('off')
plt.colorbar(im1, ax=axes[0, 1], fraction=0.046, pad=0.04)

# Convolution map for 8
im2 = axes[0, 2].imshow(conv_8, cmap='hot')
axes[0, 2].plot(x8, y8, 'bx', markersize=12, markeredgewidth=3)
axes[0, 2].set_title(f'Conv 8 Max at ({x8}, {y8})')
axes[0, 2].axis('off')
plt.colorbar(im2, ax=axes[0, 2], fraction=0.046, pad=0.04)

# Cropped templates
axes[1, 0].imshow(img_7, cmap='gray')
axes[1, 0].set_title('Digit 7 Template')
axes[1, 0].axis('off')

# Normalized kernels
axes[1, 1].imshow(kernel_7_norm, cmap='RdBu', vmin=-1, vmax=1)
axes[1, 1].set_title('Kernel 7 (Normalized)')
axes[1, 1].axis('off')

axes[1, 2].imshow(kernel_8_norm, cmap='RdBu', vmin=-1, vmax=1)
axes[1, 2].set_title('Kernel 8 (Normalized)')
axes[1, 2].axis('off')

plt.tight_layout()
plt.show()

# 10. Print statistics
print("\n" + "="*60)
print("KERNEL STATISTICS:")
print("="*60)
print(f"Digit 7 - Max: {np.max(kernel_7_norm):.3f}, Min: {np.min(kernel_7_norm):.3f}")
print(f"Digit 8 - Max: {np.max(kernel_8_norm):.3f}, Min: {np.min(kernel_8_norm):.3f}")

print("\n✅ Done!")