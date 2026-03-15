#include "my_application.h"

int main(int argc, char** argv) {
  g_autoptr(MyApplication) app = my_application_new("com.lutris_game_station.app", G_APPLICATION_NON_UNIQUE);
  return g_application_run(G_APPLICATION(app), argc, argv);
}
