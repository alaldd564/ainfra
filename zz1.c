#include <stdio.h>

int main()
{
    int numArr[5] = { 11, 22, 33, 44, 55 };
    int* numPtrA;
    void* ptr;

    numPtrA = &numArr[2];
    ptr = numArr;

    printf("%d\n", *(numPtrA + 2)); // 55
    printf("%d\n", *((int*)ptr + 1)); // 22
    printf("%d\n", *((int*)ptr)); // 11
    printf("%d\n", *(numPtrA)); // 33

    return 0;
}
