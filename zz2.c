#include <stdio.h>

int reverse(int a[], int n) {
    int *p = a + n - 1; // 마지막 원소를 가리키는 포인터
    for(int i = 0; i < n; i++) {
        printf("%d\n", *(p - i));
    }
}

int main() {
    int arr[5] = { 10, 20, 30, 40, 50 };
    reverse(arr, 5);
    return 0;
}
