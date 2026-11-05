# /// script
# dependencies = ["cairosvg", "pillow"]
# ///
import io, pathlib, cairosvg
from PIL import Image
here = pathlib.Path(__file__).parent
out = here.parent / "pkyt/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
png = cairosvg.svg2png(url=str(here / "icon.svg"), output_width=1024, output_height=1024)
Image.open(io.BytesIO(png)).convert("RGB").save(out)
