
#include "raylib.h"
#include <errno.h>
#include <limits.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#define ANIM_FREQ_HZ 5.0f /* 边框闪烁频率，单位 Hz              */
#define BORDER_THICK 3.0f /* 边框基础厚度，逻辑像素              */
#define DOT_RADIUS 6.0f   /* 录制指示点基础半径，逻辑像素        */
#define DOT_MARGIN 15.0f  /* 指示点距左上角边距，逻辑像素        */
#define DEFAULT_W 100     /* 初始窗口宽度（由合成器 resize）      */
#define DEFAULT_H 100
#define MIN_DIM 10    /* 最小合法窗口尺寸                    */
#define MAX_DIM 32767 /* 单轴最大尺寸，防止整数溢出          */

static int safe_parse_dim(const char *s) {
  if (!s || *s == '\0')
    return -1;
  char *end;
  errno = 0;
  long val = strtol(s, &end, 10);
  if (errno != 0 || *end != '\0' || val < MIN_DIM || val > MAX_DIM)
    return -1;
  return (int)val;
}

int main(int argc, char **argv) {
  SetConfigFlags(FLAG_WINDOW_UNDECORATED | FLAG_WINDOW_TRANSPARENT |
                 FLAG_WINDOW_TOPMOST | FLAG_WINDOW_MOUSE_PASSTHROUGH |
                 FLAG_WINDOW_RESIZABLE);

  int width = DEFAULT_W;
  int height = DEFAULT_H;

  if (argc >= 3) {
    int w = safe_parse_dim(argv[1]);
    int h = safe_parse_dim(argv[2]);
    if (w < 0 || h < 0) {
      fprintf(stderr, "[overlay] Invalid dimensions: '%s' x '%s'\n", argv[1],
              argv[2]);
      return 1;
    }
    width = w;
    height = h;
  }

  InitWindow(width, height, "longshot_overlay");

  if (!IsWindowReady()) {
    fprintf(stderr,
            "[overlay] Failed to initialize window "
            "(WAYLAND_DISPLAY=%s)\n",
            getenv("WAYLAND_DISPLAY") ? getenv("WAYLAND_DISPLAY") : "unset");
    return 1;
  }

  SetTargetFPS(60);

  const double anim_period = (2.0 * M_PI) / (double)ANIM_FREQ_HZ;
  double anim_time = 0.0;

  while (!WindowShouldClose()) {
    anim_time = fmod(anim_time + (double)GetFrameTime(), anim_period);

    int rw = GetRenderWidth();
    int rh = GetRenderHeight();

    Vector2 dpi = GetWindowScaleDPI();
    float scale = (dpi.x + dpi.y) * 0.5f;
    if (scale < 1.0f)
      scale = 1.0f;

    float alpha = (sinf((float)anim_time * ANIM_FREQ_HZ) + 1.0f) * 0.5f;
    Color border_col = ColorAlpha(RED, alpha);

    BeginDrawing();
    ClearBackground(BLANK);

    DrawRectangleLinesEx((Rectangle){0.0f, 0.0f, (float)rw, (float)rh},
                         BORDER_THICK * scale, border_col);

    DrawCircle((int)(DOT_MARGIN * scale), (int)(DOT_MARGIN * scale),
               DOT_RADIUS * scale, border_col);

    EndDrawing();
  }

  CloseWindow();
  return 0;
}
