#include <cstddef>

#define VAL  alignof(std::max_align_t)

const char info_alingof_max_align_t[] = {
    '_', '_', 'm', 'a', 'x', 'a', 'l', 'i', 'g', 'n', '_', '_',
    '[', '0' + ((VAL / 10) % 10), '0' + (VAL % 10), ']', '\0',
};

int main(int argc, char *argv[]) {
  return  info_alingof_max_align_t[argc];
}