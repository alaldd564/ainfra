#include <stdio.h>
#include <stdlib.h>

struct point {
    int x, y;  // 코드입력
};

struct rect {
    struct point leftTop;  // 코드입력
    struct point rightBottom;  // 코드입력
};

int main() {
    struct rect r;
    int w, h, area, peri;

    printf("왼쪽 상단 좌표 입력 : ");
    scanf("%d %d", &r.leftTop.x, &r.leftTop.y);  // 코드입력

    printf("오른쪽 하단 좌표 입력 : ");
    scanf("%d %d", &r.rightBottom.x, &r.rightBottom.y);  // 코드입력

    w = abs(r.rightBottom.x - r.leftTop.x);  // 코드입력
    h = abs(r.rightBottom.y - r.leftTop.y);  // 코드입력

    area = w * h;  // 코드입력
    peri = 2 * (w + h);  // 코드입력

    printf("면적은 %d, 둘레는 %d이다", area, peri);

    return 0;
}
