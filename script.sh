#!/bin/bash
D=drivers/media/platform/exynos/fimc-is2
H=$D/include/fimc-is-metadata.h

cat > /tmp/pre.h <<'EOF'
#include <stddef.h>
typedef unsigned char      u8;
typedef unsigned short     u16;
typedef unsigned int       u32;
typedef unsigned long long u64;
typedef signed char        s8;
typedef short              s16;
typedef int                s32;
typedef long long          s64;
typedef unsigned char      uint8_t;
typedef unsigned short     uint16_t;
typedef unsigned int       uint32_t;
typedef unsigned long long uint64_t;
typedef signed char        int8_t;
typedef short              int16_t;
typedef int                int32_t;
typedef long long          int64_t;
EOF

cat > /tmp/t.c <<'EOF'
#include <stdio.h>
#include "fimc-is-metadata.h"
int main(void){
  printf("%zu %zu\n",
    sizeof(struct camera2_shot_ext),
    offsetof(struct camera2_shot_ext, shot) + offsetof(struct camera2_shot, magicNumber));
  return 0;
}
EOF

try() {
  c=$1
  o=/tmp/m_$c; rm -rf $o; mkdir -p $o/stub
  git archive $c $D 2>/dev/null | tar -x -C $o --wildcards '*.h' 2>/dev/null
  M=$(find $o -name fimc-is-metadata.h | head -1)
  [ -z "$M" ] && { echo "no header"; return; }
  sed -i '/#include <linux\//d; /#include "fimc-is-framemgr.h"/d' "$M"
  INC=$(find $o -type d | sed 's/^/-I/' | tr '\n' ' ')
  for i in $(seq 1 40); do
    if gcc -std=gnu11 -w -include /tmp/pre.h -include $PWD/include/generated/autoconf.h \
          $INC -o $o/t /tmp/t.c 2> $o/err; then
      $o/t; return
    fi
    miss=$(sed -n 's/.*fatal error: \(.*\): No such file.*/\1/p' $o/err | head -1)
    if [ -n "$miss" ]; then
      mkdir -p "$o/stub/$(dirname "$miss")"; : > "$o/stub/$miss"
    else
      echo "build error: $(head -1 $o/err | cut -c1-150)"; return
    fi
  done
}

for c in $(git log --format=%h -- $H); do
  r=$(try $c)
  tag=""; case "$r" in *" 38440") tag="  <== MATCH";; esac
  echo "$(git log -1 --format='%h %ad %s' --date=short $c) | $r$tag"
done
