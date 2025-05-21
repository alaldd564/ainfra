#include <stdio.h>

int main(void)
{
	int *pi;
	char *pc;
	double *pd;

printf("증가 전 pi : %d, pc : %d, pd : %d\n", pi, pc, pd);                     

printf("*pi = %d, *pc : %d, *pd : %d\n",*pi, *pc, *pd);

pi++;
pc++;
pd++;

printf("증가 후 pi : %d, pc : %d, pd : %d\n", pi, pc, pd);  
printf("pi : %d, pc : %d, pd : %d\n", pi+2, pc+2, pd+2);
printf("1pi : %d, 1pc : %d, 1pd : %d\n", (*pi)+2, (*pc)+2, (*pd)+2);
return 0;
} 
