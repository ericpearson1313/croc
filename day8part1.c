#include <stdio.h>

int data[1000][3];
int arc[1000][2];
long cost[1000];
int color[1000];
int hist[1000];

long dist( int a, int b ) {
	long dist = 0;
	for( int ii = 0; ii<3; ii++ )
		dist += (long)(data[a][ii]-data[b][ii]) * (long)(data[a][ii]-data[b][ii]);
	return( dist );
}

int main( int argc, char **argv )
{
	FILE *fp;
	long thresh;
	long min;
	fp = fopen("day8_full_puzzle.txt","r");
	// read in data file
	for( int ii = 0; ii < 1000; ii++ )
		fscanf(fp, "%d,%d,%d", &data[ii][0], &data[ii][1], &data[ii][2] );
	fclose( fp );
	// echo
	//for( int ii = 0; ii < 1000; ii++ )
	//	printf("%d %d %d\n", data[ii][0], data[ii][1], data[ii][2] );

	// Find the mins
	thresh = 0;
	for( int kk = 0; kk < 1000; kk++ ) {
		cost[kk]= (10000L*10000L)*3L;
		for( int ii = 0; ii < 1000-1; ii++ ) {
			for( int jj = ii+1; jj < 1000; jj++ ) {
				if( dist(ii,jj) > thresh && dist(ii,jj) < cost[kk]) {
					arc[kk][0] = ii;
					arc[kk][1] = jj;
					cost[kk] = dist( ii, jj );
				}
			}
		}
		thresh = cost[kk];
	}

	// set arc gets a color
	for( int ii = 0; ii < 1000; ii++ ) 
		color[ii] = ii;

	
	// merge colors
	int hit;
	hit = 1;
	while( hit > 0 ) {
		hit = 0;
		for( int ii = 0; ii < 1000; ii++ ) {
			for( int jj = 0; jj < 1000; jj++ ) {
				if( ii != jj && ( arc[ii][0] == arc[jj][0] ||
 						       	arc[ii][0] == arc[jj][1] ||
 						       	arc[ii][1] == arc[jj][0] ||
 						       	arc[ii][1] == arc[jj][1]  ) ) {
					if( color[jj] < color[ii] ) {
						//printf("hit %d-%d\n", color[ii], color[jj] );
						color[ii] = color[jj];
						hit++;
				        } else if ( color[ii] < color[jj] ) {
						//printf("hit %d-%d\n", color[ii], color[jj] );
						color[jj] = color[ii];
						hit++;
					}
				}
			}
		}
		//printf("hit %d\n", hit);
	}
	// Walk thru original set and color data
	int node_color[1000];
	for( int ii = 0; ii < 1000; ii++ )
		node_color[ii] = -1; 
	for ( int ii = 0; ii < 1000; ii++ ) {
		node_color[arc[ii][0]] = color[ii];
		node_color[arc[ii][1]] = color[ii];
	}

	// Create a color histogram
	for( int ii = 0; ii < 1000; ii++ ) 
		hist[ii] = 0;
	for( int ii = 0; ii < 1000; ii++ ) 
		if( node_color[ii] >= 0 ) 
			hist[node_color[ii]]++;
	

	// Dump data
	//for( int ii = 0; ii < 1000; ii++ ) {
	//	printf( "[%d][%d] color = %d, cost = %ld (%d,%d,%d),(%d,%d,%d)\n", arc[ii][0], arc[ii][1], color[ii], cost[ii],
	//	data[arc[ii][0]][0], data[arc[ii][0]][1], data[arc[ii][0]][2], data[arc[ii][1]][0], data[arc[ii][1]][1], data[arc[ii][1]][2]);
	//}
	
	for( int ii = 0; ii < 1000; ii++ ) 
		printf( "%d\n", hist[ii] );

	// done
	return( 0 );
}
	

