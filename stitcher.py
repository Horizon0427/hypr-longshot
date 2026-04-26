import os
import sys

import cv2
import numpy as np

CROP = 10  # 裁剪边框像素（对应 shell 脚本 PADDING=10）
BOTTOM_RATIO = 0.15  # 底部模板占帧高比例
MID_START_RATIO = 0.40  # 中部模板起始比例
MID_END_RATIO = 0.60  # 中部模板结束比例
MATCH_THRESHOLD = 0.80  # 模板匹配最低置信度
MIN_MOVEMENT = 5  # 最小有效滚动像素（过滤抖动）
STATIC_THRESH = 1.0  # 静态帧判定阈值（每像素平均灰度差）
TARGET_SAMPLE_FPS = 10  # 目标采样帧率（帧/秒），自适应计算间隔


def stitch_video(video_path: str, output_path: str) -> None:
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        print(f"[ERROR] Cannot open video: {video_path}", file=sys.stderr)
        sys.exit(1)

    try:
        ret, first_frame = cap.read()
        if not ret:
            print("[ERROR] Video file is empty.", file=sys.stderr)
            sys.exit(1)

        first_frame = first_frame[CROP:-CROP, CROP:-CROP]
        h, w = first_frame.shape[:2]

        bottom_th = int(h * BOTTOM_RATIO)
        mid_start = int(h * MID_START_RATIO)
        mid_end = int(h * MID_END_RATIO)

        src_fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
        sample_interval = max(1, round(src_fps / TARGET_SAMPLE_FPS))
        total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        print(
            f"[INFO] {w}x{h} @ {src_fps:.1f}fps | "
            f"~{total_frames} frames | sample every {sample_interval}"
        )

        prev_frame = first_frame
        gray_prev = cv2.cvtColor(prev_frame, cv2.COLOR_BGR2GRAY)

        slices: list[np.ndarray] = [prev_frame]

        frame_count = 0
        stitch_count = 0

        while True:
            ret, curr_frame = cap.read()
            if not ret:
                break

            frame_count += 1
            if frame_count % sample_interval != 0:
                continue

            curr_frame = curr_frame[CROP:-CROP, CROP:-CROP]
            gray_curr = cv2.cvtColor(curr_frame, cv2.COLOR_BGR2GRAY)

            if cv2.norm(gray_curr, gray_prev, cv2.NORM_L1) / (h * w) < STATIC_THRESH:
                continue

            gray_bottom = gray_prev[h - bottom_th : h, :]
            res_b = cv2.matchTemplate(gray_curr, gray_bottom, cv2.TM_CCOEFF_NORMED)
            _, max_val_b, _, max_loc_b = cv2.minMaxLoc(res_b)

            bottom_match_y = max_loc_b[1]
            bottom_movement = (h - bottom_th) - bottom_match_y

            if max_val_b > MATCH_THRESHOLD and bottom_movement > MIN_MOVEMENT:
                new_content = curr_frame[bottom_match_y + bottom_th : h, :]
                if new_content.shape[0] > 0:
                    slices.append(new_content)
                    stitch_count += 1
                prev_frame = curr_frame
                gray_prev = gray_curr  # 同步更新缓存
                continue

            gray_mid = gray_prev[mid_start:mid_end, :]
            res_m = cv2.matchTemplate(gray_curr, gray_mid, cv2.TM_CCOEFF_NORMED)
            _, max_val_m, _, max_loc_m = cv2.minMaxLoc(res_m)

            mid_match_y = max_loc_m[1]
            mid_movement = mid_start - mid_match_y

            if max_val_m > MATCH_THRESHOLD and mid_movement > MIN_MOVEMENT:
                dy = mid_movement
                new_content = curr_frame[h - dy : h, :]
                if new_content.shape[0] > 0:
                    slices.append(new_content)
                    stitch_count += 1
                prev_frame = curr_frame
                gray_prev = gray_curr

        print(f"[INFO] Stitching {stitch_count} segments ({len(slices)} slices)...")
        result_img = np.vstack(slices)

        out_dir = os.path.dirname(os.path.abspath(output_path))
        if not os.path.isdir(out_dir):
            print(
                f"[ERROR] Output directory does not exist: {out_dir}", file=sys.stderr
            )
            sys.exit(1)

        ok = cv2.imwrite(output_path, result_img)
        if not ok:
            print(f"[ERROR] Failed to write image: {output_path}", file=sys.stderr)
            sys.exit(1)

        print(f"[OK] {result_img.shape[1]}x{result_img.shape[0]}px → {output_path}")

    finally:
        cap.release()


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: python stitcher.py <input_video> <output_image>", file=sys.stderr)
        sys.exit(1)

    stitch_video(sys.argv[1], sys.argv[2])
