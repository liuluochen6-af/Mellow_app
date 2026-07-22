import uuid
import os
from io import BytesIO

from PIL import Image, ImageOps

UPLOAD_DIR = "uploads"
MAX_WIDTH = 1080
JPEG_QUALITY = 70


def compress_and_save_image(file_bytes: bytes, original_filename: str) -> str:
    img = Image.open(BytesIO(file_bytes))

    img = ImageOps.exif_transpose(img)

    if img.mode in ("RGBA", "P"):
        img = img.convert("RGB")

    if img.width > MAX_WIDTH:
        ratio = MAX_WIDTH / img.width
        new_height = int(img.height * ratio)
        img = img.resize((MAX_WIDTH, new_height), Image.LANCZOS)

    filename = f"{uuid.uuid4().hex}.jpg"
    filepath = os.path.join(UPLOAD_DIR, filename)

    img.save(filepath, "JPEG", quality=JPEG_QUALITY)
    return f"/uploads/{filename}"
