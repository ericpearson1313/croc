#include <stdio.h>
#define	idxof( a, b, c ) (((a)-'a')+26*(((b)-'a')+26*((c)-'a')))
int main( int argc, char **argv )
{


	FILE *fp, *decfp, *opfp;
	char c;
	char id[26*26*26];  // id utilization list 0-not seen, 1-seen, 2-special
	char word[32][3];
	int cc, ww;
	int node;
	fp = fopen( "day11_puzzle.txt", "r" );
	decfp = fopen( "day11_declaration.sv", "w" );
	opfp = fopen( "day11_operation.sv", "w" );
	
	for( int ii = 0; ii < 26*26*26; ii++ )
		id[ii] = 0;
	id[idxof('y','o','u')] = 2; // You
	id[idxof('o','u','t')] = 2; // Out
	id[idxof('s','v','r')] = 2; // SVR
	id[idxof('d','a','c')] = 3; // DAC
	id[idxof('f','f','t')] = 3; // FFT

	c = fgetc( fp );
	cc = 0;
	ww = 0;
	while( !feof( fp ) ) {
		//putchar( c );
		switch( c ) {
		case 'a': case 'b': case 'c': case 'd': case 'e': case 'f': case 'g': case 'h': case 'i': case 'j': case 'k': case 'l': case 'm': 
                case 'n': case 'o': case 'p': case 'q': case 'r': case 's': case 't': case 'u': case 'v': case 'w': case 'x': case 'y': case 'z': 
			word[ww][cc++] = c;
			break;
		case ' ':
			node = idxof( word[ww][0], word[ww][1], word[ww][2] );
			if( id[node] == 0 ) 
				id[node] = 1;
			ww++;
			cc=0;
			break;
		case 0x0a:
			if( id[idxof( word[0][0], word[0][1], word[0][2])] == 3 ) 
				fprintf(opfp, "assign %c%c%c = %c%c%c_ofs + %c%c%c ", word[0][0], word[0][1], word[0][2], word[0][0], word[0][1], word[0][2],  word[1][0], word[1][1], word[1][2] );
			else
				fprintf(opfp, "assign %c%c%c = %c%c%c ", word[0][0], word[0][1], word[0][2],  word[1][0], word[1][1], word[1][2] );
			for( int ii = 2; ii <= ww; ii++ ) 
				fprintf(opfp, "+ %c%c%c ", word[ii][0], word[ii][1], word[ii][2] );
			fprintf(opfp, ";\n");
			ww = 0;
			cc = 0;
			break;
		}
		c = fgetc( fp );
	}
	fclose(fp);
	fclose(opfp);
	printf("device file generated\n" );

	// Generate the declaration file
	decfp = fopen( "day11_declaration.sv", "w" );
	for( char ii = 'a' ; ii <= 'z'; ii++ ) 
		for( char jj = 'a' ; jj <= 'z'; jj++ ) 
			for( char kk = 'a' ; kk <= 'z'; kk++ )
				if( id[idxof(ii,jj,kk)] == 1 ) 
					fprintf(decfp, "logic [63:0] %c%c%c;\n", ii, jj, kk );
	fclose(decfp);
	printf("Declaration file generated\n" );
}
