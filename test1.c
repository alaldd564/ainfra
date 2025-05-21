#include <stdio.h>
void reverse(int a[], int n);

int main()
{
	int a[] = { 10,20,30,40,50 };
	reverse(a, 5);
	return 0;
}

void reverse(int a[], int n)
{
	int* p;
	p = a;

	for (int c = n-1;c >=0;c--)
	{
		printf("%d\n", p[c]);

	}
	return 0;
}