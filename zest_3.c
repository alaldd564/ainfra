#include <stdio.h>

int main(){
    char code;
    char* p;         // char형 포인터 p 선언
    p = &code;       // 포인터에 변수 code의 주소 대입
    *p = 'a';        // 포인터를 통하여 변수 code에 'a' 대입

    printf("%c\n", code);  
    return 0;
}
