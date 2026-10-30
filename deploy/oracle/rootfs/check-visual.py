#!/usr/bin/env python3
"""Exercise the pinned image runtime inside a new Linux rootfs; no Oracle claim."""
from io import BytesIO
import hashlib
import importlib.metadata
import json
import platform
import sys

import numpy as np
from PIL import Image, ImageFilter, features

assert sys.platform == "linux" and platform.machine() == "x86_64"
assert sys.version_info[:2] == (3, 12)
assert importlib.metadata.version("pillow") == "11.3.0"
assert features.check("jpg") and features.check("zlib")

rgba = Image.new("RGBA", (64, 48), (210, 40, 80, 128))
rgba.putpixel((7, 9), (10, 200, 40, 255))
png = BytesIO()
rgba.save(png, format="PNG")
assert len(png.getvalue()) <= 8192
decoded = Image.open(BytesIO(png.getvalue()))
decoded.load()
assert decoded.format == "PNG" and decoded.n_frames == 1
assert decoded.convert("RGBA").tobytes() == rgba.tobytes()

jpeg = BytesIO()
Image.new("RGB", (64, 48), (210, 40, 80)).save(jpeg, format="JPEG", quality=95)
assert len(jpeg.getvalue()) <= 8192
decoded_jpeg = Image.open(BytesIO(jpeg.getvalue()))
decoded_jpeg.load()
assert decoded_jpeg.format == "JPEG" and getattr(decoded_jpeg, "n_frames", 1) == 1
pixel = decoded_jpeg.convert("RGB").getpixel((32, 24))
assert max(abs(a - b) for a, b in zip(pixel, (210, 40, 80))) <= 3

features32 = np.asarray(decoded.convert("RGB").resize((32, 32), Image.Resampling.LANCZOS))
assert features32.shape == (32, 32, 3) and features32.dtype == np.uint8
canvas = Image.new("RGBA", (512, 512), (255, 255, 255, 255))
sprite = decoded.convert("RGBA")
sprite.thumbnail((256, 256), Image.Resampling.LANCZOS)
shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
shadow.paste((0, 0, 0, 100), (132, 132, 132 + sprite.width, 132 + sprite.height))
canvas = Image.alpha_composite(canvas, shadow.filter(ImageFilter.GaussianBlur(5)))
canvas.alpha_composite(sprite, (128, 128))
output = BytesIO()
canvas.save(output, format="PNG")
assert len(output.getvalue()) <= 512 * 1024
roundtrip = Image.open(BytesIO(output.getvalue()))
roundtrip.load()
assert roundtrip.size == (512, 512) and roundtrip.tobytes() == canvas.tobytes()

print(json.dumps({
    "pillow": importlib.metadata.version("pillow"), "numpy": np.__version__,
    "png_input_bytes": len(png.getvalue()), "jpeg_input_bytes": len(jpeg.getvalue()),
    "png_output_bytes": len(output.getvalue()),
    "png_output_sha256": hashlib.sha256(output.getvalue()).hexdigest(),
    "operations": ["PNG lossless decode", "JPEG decode", "RGB/RGBA conversion",
                   "NumPy pixels", "Lanczos resize", "Gaussian blur", "alpha composite", "PNG encode"],
    "scope": "Image dependency behavior only; no OCR, font inventory, Oracle route or specialist qualification."
}, sort_keys=True))
