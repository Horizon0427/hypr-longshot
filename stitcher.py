import sys
import cv2
import numpy as np


def stitch_video(video_path, output_path):
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        print(f"Error: cannot open file: {video_path}")
        sys.exit(1)

    ret, prev_frame = cap.read()
    if not ret:
        print("Error: empty file.")
        sys.exit(1)

    CROP = 10
    prev_frame = prev_frame[CROP:-CROP, CROP:-CROP]

    result_img = prev_frame.copy()
    h, w, _ = prev_frame.shape

    bottom_th = int(h * 0.15)

    mid_start = int(h * 0.4)
    mid_end = int(h * 0.6)

    frame_count = 0
    while True:
        ret, curr_frame = cap.read()
        if not ret:
            break

        frame_count += 1
        if frame_count % 5 != 0:
            continue

        curr_frame = curr_frame[CROP:-CROP, CROP:-CROP]
        gray_curr = cv2.cvtColor(curr_frame, cv2.COLOR_BGR2GRAY)

        bottom_template = prev_frame[h - bottom_th : h, :]
        gray_bottom = cv2.cvtColor(bottom_template, cv2.COLOR_BGR2GRAY)

        res_b = cv2.matchTemplate(gray_curr, gray_bottom, cv2.TM_CCOEFF_NORMED)
        min_val_b, max_val_b, min_loc_b, max_loc_b = cv2.minMaxLoc(res_b)

        bottom_match_y = max_loc_b[1]
        bottom_movement = (h - bottom_th) - bottom_match_y

        if max_val_b > 0.8 and bottom_movement > 5:
            new_content = curr_frame[bottom_match_y + bottom_th : h, :]
            result_img = np.vstack((result_img, new_content))
            prev_frame = curr_frame
            continue

        mid_template = prev_frame[mid_start:mid_end, :]
        gray_mid = cv2.cvtColor(mid_template, cv2.COLOR_BGR2GRAY)

        res_m = cv2.matchTemplate(gray_curr, gray_mid, cv2.TM_CCOEFF_NORMED)
        min_val_m, max_val_m, min_loc_m, max_loc_m = cv2.minMaxLoc(res_m)

        mid_match_y = max_loc_m[1]
        mid_movement = mid_start - mid_match_y

        if max_val_m > 0.8 and mid_movement > 5:
            dy = mid_movement

            new_content = curr_frame[h - bottom_th - dy : h - bottom_th, :]

            result_img = np.vstack(
                (result_img[:-bottom_th, :], new_content, result_img[-bottom_th:, :])
            )

            prev_frame = curr_frame

    cv2.imwrite(output_path, result_img)
    cap.release()
    print(f"Complete: {result_img.shape[1]}x{result_img.shape[0]} pixels")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python stitcher.py <input path> <output path>")
        sys.exit(1)

    video_file = sys.argv[1]
    output_file = sys.argv[2]

    stitch_video(video_file, output_file)
