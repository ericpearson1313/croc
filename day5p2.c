#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdint.h>

	typedef struct {
		long lower;
		long upper;
		void *next;
	} range_type;

	range_type *list; // linked list
void dump_list ()
{
	range_type *ptr;
	if( list == NULL ) printf("(Empty)\n");
	for( ptr = list; ptr != NULL; ptr = ptr->next ) 
		printf("(%ld-%ld)\n", ptr->lower, ptr->upper );
	return;
}

void insert_range( range_type *in )  // horrible, shoi;d use a library
{
	range_type *new, *cur, *ptr;
	range_type *new_list, *new_cur;


	new = (range_type *) malloc( sizeof( range_type ));
	new->upper = in->upper;
	new->lower = in->lower;

	new_list = new; 

	if( list == NULL ) {
		list = new_list;
		return;
	}

	for( cur = new_list, ptr = list; ptr != NULL; ptr=ptr->next ) {
		if( cur->upper < ptr->lower ) { // list passes us, just point to its tail and exit
			cur->next = ptr;
			list = new_list;
			return;
		} else if( cur->lower > ptr->upper ) {// we pass list, put it on ours and step
			new_cur = (range_type *) malloc( sizeof( range_type ));
			new_cur->lower = cur->lower;
			new_cur->upper = cur->upper;
			cur->next = new_cur;
			cur->upper = ptr->upper;
			cur->lower = ptr->lower;
			cur = new_cur;
		} else { // intersectg
			cur->lower = (cur->lower <= ptr->lower) ? cur->lower : ptr->lower;
			cur->upper = (cur->upper >= ptr->upper) ? cur->upper : ptr->upper;
		}
	}
	list = new_list;
	return;
}

int main( int argc, char **argv )
{
	FILE *fp;
	printf("open Puzzle file\n");
	fp = fopen( "day5p2_puzzle.txt", "r" );
	
	long word;
	char c;
	range_type in;
	word = 0;
	c = fgetc( fp );
	while( !feof( fp ) ) {
		switch( c ) {
			case '0': case '1': case '2': case '3': case '4': case '5': case '6': case '7': case '8': case '9': 
				word = word * 10 + c - '0';
			break;
			case '-' :
				in.lower = word;
				word = 0;
			break;
			case 0x0a :
				in.upper = word;
				word = 0;
				insert_range( &in );
				printf("%ld-%ld\n", in.lower, in.upper );
				dump_list();
			break;
		}
		c =getc( fp );
	}
	fclose( fp );
	printf("Accumulate sum of non_overlaping ranges\n");
	dump_list();
	range_type *ptr;
	long sum;
	for( sum = 0, ptr = list; ptr != NULL; ptr = ptr->next ) 
		sum = sum + ptr->upper - ptr->lower + 1;
	printf("Sum = %ld\n", sum );
		
	return( 0 );
}

