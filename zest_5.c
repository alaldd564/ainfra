#include <stdio.h>

void sub(int* b, int n)
{
    for(int i = 0; i < n; i++) {
        b[i] += 3;
    }
}

int main()
{
    int a[3] = {1, 2, 3};
    
    printf("%d %d %d \n",a[0],a[1],a[2]);
    sub(a, 3);
    printf("%d %d %d \n",a[0],a[1],a[2]);


    return 0;
}
