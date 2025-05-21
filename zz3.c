#include <stdio.h>

void mergeArrays(int* arr1, int* arr2, int* mergedArray) {
    
    for (int i = 0; i < 4; i++) {
        *(mergedArray + i) = *(arr1 + i);
    }
    // arr2의 4개 요소 복사
    for (int i = 0; i < 4; i++) {
        *(mergedArray + 4 + i) = *(arr2 + i);
    }
}

int main() {
    int arr1[4] = { 1, 2, 3, 4 };
    int arr2[4] = { 5, 6, 7, 8 };
    int mergedArray[8];

    mergeArrays(arr1, arr2, mergedArray);

    // 결과 출력 코드
    for (int i = 0; i < 8; i++) {
        printf("%d ", *(mergedArray + i));
    }
    printf("\n");

    return 0;
}
