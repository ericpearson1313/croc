#include <stdio.h>

int data[2][1000];

long dist( int a, int b ) {
	long dist = 0;
	int dx, dy;
	dx = data[1][a]-data[1][b];
	dx = (dx<0)?-dx:dx;
	dy = data[0][a]-data[0][b];
	dy = (dy<0)?-dy:dy;
	dist += ((long)dx+1L) * ((long)dy+1L);
	return( dist );
}

int main( int argc, char **argv )
{
	FILE *fp;
	long max;
	fp = fopen("day9_puzzle.txt","r");
	// read in data file
	for( int ii = 0; ii < 496 ; ii++ )
		fscanf(fp, "%d,%d", &data[0][ii], &data[1][ii] );
	fclose( fp );
	// echo
	for( int ii = 0; ii < 496; ii++ )
		printf("%d %d\n", data[0][ii], data[1][ii] );

	// Find and report the max area
	max = 0;
	for( int ii = 0; ii < 496-1; ii++ ) 
		for( int jj = ii+1; jj < 496;  jj++ ) 
			max = ( max < dist(ii,jj) ) ? dist(ii,jj) : max;

	// Report
	printf("Max area = %ld\n", max );
	// done
	return( 0 );
}
	

