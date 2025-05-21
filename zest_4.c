#include <stdio.h>

int main(void)
{
    int a[] = { 10, 20, 30, 40, 50 };

    // 코드 작성
    int *p = a; // 배열 a의 시작 주소를 포인터 p에 저장

    printf("p[0] = %d p[1] = %d p[2] = %d\n", p[0], p[1], p[2]);
    return 0;
}
