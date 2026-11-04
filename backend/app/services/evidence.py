from __future__ import annotations

import math


def crop_bounds(bbox: list, width: int, height: int) -> tuple[int, int, int, int]:
    if len(bbox) != 4 or width <= 0 or height <= 0:
        raise ValueError("Invalid bounding box or image size")
    try:
        x, y, box_width, box_height = (float(value) for value in bbox)
    except (TypeError, ValueError):
        raise ValueError("Bounding box must contain four numbers") from None
    values = (x, y, box_width, box_height)
    if not all(math.isfinite(value) for value in values) or box_width <= 0 or box_height <= 0:
        raise ValueError("Bounding box must contain finite coordinates and positive dimensions")

    largest = max(abs(value) for value in values)
    if largest <= 1:
        x_scale, y_scale = width, height
    elif largest <= 1000:
        x_scale, y_scale = width / 1000, height / 1000
        pixel_box_fits = (
            0 <= x < width
            and 0 <= y < height
            and x + box_width <= width
            and y + box_height <= height
        )
        scaled_width, scaled_height = box_width * x_scale, box_height * y_scale
        min_useful_size = max(24, min(width, height) * 0.06)
        if (pixel_box_fits
                and (scaled_width < min_useful_size or scaled_height < min_useful_size)
                and box_width >= 12 and box_height >= 12):
            x_scale = y_scale = 1
    else:
        x_scale = y_scale = 1

    x1 = max(0, min(width, int(x * x_scale)))
    y1 = max(0, min(height, int(y * y_scale)))
    x2 = max(0, min(width, int((x + box_width) * x_scale)))
    y2 = max(0, min(height, int((y + box_height) * y_scale)))
    if x2 <= x1 or y2 <= y1:
        raise ValueError("Bounding box is outside the image")
    return x1, y1, x2, y2


def expand_crop_bounds(
    bounds: tuple[int, int, int, int],
    width: int,
    height: int,
    min_fraction: float = 0.18,
) -> tuple[int, int, int, int]:
    x1, y1, x2, y2 = bounds
    target_width = min(width, max(64, int(width * min_fraction)))
    target_height = min(height, max(64, int(height * min_fraction)))
    crop_width, crop_height = x2 - x1, y2 - y1
    center_x, center_y = (x1 + x2) // 2, (y1 + y2) // 2
    crop_width = min(width, max(crop_width, target_width))
    crop_height = min(height, max(crop_height, target_height))
    x1 = max(0, min(width - crop_width, center_x - crop_width // 2))
    y1 = max(0, min(height - crop_height, center_y - crop_height // 2))
    return x1, y1, x1 + crop_width, y1 + crop_height
