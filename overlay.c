#include "raylib.h"
#include <math.h>
#include <stdlib.h>

int main(int argc, char **argv) {
  SetConfigFlags(FLAG_WINDOW_UNDECORATED | FLAG_WINDOW_TRANSPARENT |
                 FLAG_WINDOW_TOPMOST | FLAG_WINDOW_MOUSE_PASSTHROUGH |
                 FLAG_WINDOW_RESIZABLE);

  int width = 100;
  int height = 100;

  if (argc >= 3) {
    width = atoi(argv[1]);
    height = atoi(argv[2]);
  }

  InitWindow(width, height, "longshot_overlay");
  SetTargetFPS(60);

  float time = 0.0f;

  while (!WindowShouldClose()) {
    time += GetFrameTime();

    int sw = GetScreenWidth();
    int sh = GetScreenHeight();

    BeginDrawing();
    ClearBackground(BLANK);

    float alpha = (sinf(time * 5.0f) + 1.0f) / 2.0f;
    DrawRectangleLinesEx((Rectangle){0, 0, sw, sh}, 3.0f, Fade(RED, alpha));
    DrawCircle(15, 15, 6.0f, Fade(RED, alpha));

    EndDrawing();
  }

  CloseWindow();
  return 0;
}
