#include <stdio.h>
#include <math.h>

struct point {
    int x;   // 코드입력
    int y;   // 코드입력
};

int main() {
    struct point p1, p2;
    int xd, yd;
    double dist;

    printf("점의 좌표를 입력하시오(x y) >> ");
    scanf("%d %d", &p1.x, &p1.y);

    printf("점의 좌표를 입력하시오(x y) >> ");
    scanf("%d %d", &p2.x, &p2.y);

    xd = p1.x - p2.x;   // 코드입력
    yd = p1.y - p2.y;   // 코드입력

    dist = sqrt(xd * xd + yd * yd);   // 코드입력
    printf("거리는 %f이다.\n", dist);
    return 0;
}

