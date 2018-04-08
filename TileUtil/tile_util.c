
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <math.h>
#include <malloc.h>
#include "tile_util.h"



map_tile tGlobalColorMap;



map_tile convert_tile( char *method, map_tile tSrc, char *opt ){
	int dx = tSrc.dx;
	int dy = tSrc.dy;
	map_tile tDst;

	if( VERBOSE >= 3 )  print_tile( "tSrc", tSrc );

	/*
	map_tile t00, map_tile t01, map_tile t02, map_tile t10, map_tile t11, map_tile t12, map_tile t20, map_tile t21, map_tile t22 ){

	int dx = t11.dx;
	int dy = t11.dy;
	map_tile tDst;
	int margin = 128;
	int dxL = dx + 2 * margin;
	int dyL = dy + 2 * margin;

	if( VERBOSE >= 3 )  print_tile( "t11", t11 );

	tDst = surround_central_tile( margin, t00, t01, t02, t10, t11, t12, t20, t21, t22 );
	*/

	if( strcmp(method,"linear") == 0 ){
		tDst = convert_tile_average_linear( tSrc ); 
	}else if( strcmp(method,"weighted") == 0 ){
		tDst = convert_tile_weighted_linear( tSrc ); 
	}else if( strcmp(method,"gradient") == 0 ){
		tDst = convert_tile_gradient( tSrc );
	}else if( strcmp(method,"radius") == 0 ){
        int radius = opt_int_value( opt, "radius", 20 );
		tDst = convert_tile_radius( tSrc, radius );
	}else{
		errorExit( "Unknown method\n" );
	}
	/*
	tDst = extract_subtile( margin,margin, dx,dy, tDst );
	*/

	/* verify_contour_lines( tSrc, tDst ); */
	set_sea_level( tDst, 0 );

	return tDst;
}


int opt_int_value( char *opt, char *name, int defaultVal ){
    char *ptr;
    
    if( opt == NULL ){
        return defaultVal;
    }

    ptr = strstr( opt, name );
    if( ptr != NULL ){
        int val = atoi( ptr + strlen(name) + 1 );
        return val;
    }else{
        return defaultVal;
    }
}


void set_sea_level( map_tile tElev, VALUE seaLevel ){
	int x, y;
	for( y = 0; y < tElev.dy; ++y ){
		for( x = 0; x < tElev.dx; ++x ){
			int val = get_pixel( tElev, x,y );
			if( val < 0 && val != NO_ELEV_VALUE ){
				set_pixel( tElev, x,y, seaLevel );
			}
		}
	}
}



int verify_contour_lines( map_tile tCnr, map_tile tElev ){
	int x, y, ok = 1;
	if( tCnr.dx != tElev.dx || tCnr.dy != tElev.dy ){
		errorExit( "verify_contour_lines: non-matching tile size\n" );
	}

	for( y = 0; y < tCnr.dy; ++y ){
		for( x = 0; x < tCnr.dx; ++x ){
			int valCnr = get_pixel( tCnr, x, y );
			if( valCnr != NO_ELEV_VALUE ){
				int valElev = get_pixel( tElev, x, y );
				if( valElev != valCnr ){
					ok = 0;
					printf( "Non-identical contour/elevation values at (%d,%d): valCnr = %d, valElev = %d\n", x, y, valCnr, valElev );
					break;
				}
			}
		}
	}
	if( ok == 1 )  printf( "Verify contour lines: OK\n" );
	return ok;
}


map_tile convert_tile_radius( map_tile tComb, int radius ){
	map_tile tOut;
	map_tile lineMatrix;	
	int x, y, ctUndef = 0;

	lineMatrix = make_line_matrix( radius );
	if( VERBOSE >= 2 )  print_line_matrix( lineMatrix, radius );

	tOut = new_tile( tComb.dx, tComb.dy );

	/*
	pxx = radius_value( tComb, radius, lineMatrix, 115+128,404+128 );
	printf( "[%d,%d] pxx <%d>\n", 404+128,115+128, pxx );
	if( radius <= 100 ) exit( 1 );
	*/

	for( y = radius; y < tComb.dy-radius; ++y ){
		if( y % 100 == 0 )  printf( "[%d]\n", y );
		for( x = radius; x < tComb.dx-radius; ++x ){
			VALUE px = radius_value( tComb, radius, lineMatrix, x,y );
			/* printf( "[%d,%d] px <%d>\n", y,x, px ); */
			set_pixel( tOut, x,y, px );
			if( px == NO_ELEV_VALUE )  ++ctUndef;
		}
	}
	printf( "Points of unknown elevation = %d\n", ctUndef );

	return tOut;
}


#define GRAD_MATRIX_SIZE  2000

VALUE radius_value( map_tile tComb, int radius, map_tile lineMatrix, int x0, int y0 ){
	int x, y;
	VALUE val;
	double elevMin = 9999, elevMax = -9999;
	double dist, grad;
	double distMin = 1000, distMax = 1000, gradMax = -9999;	
	int xMin = -1, yMin = -1, xMax = -1, yMax = -1;

	double gradMatrix[GRAD_MATRIX_SIZE]; 
	int i, j;
	
	val = get_pixel( tComb, x0, y0 );
	if( val != NO_ELEV_VALUE	)  return val;

	for( i = 0; i < GRAD_MATRIX_SIZE; ++i )  gradMatrix[i] = NO_ELEV_VALUE;
	i = 0;

	for( y = y0-radius; y <= y0+radius; ++y ){
		for( x = x0-radius; x <= x0+radius; ++x ){
			val = get_pixel( tComb, x, y );
			if( val == NO_ELEV_VALUE )  continue;

			dist = point_distance( x0,y0, x,y );
			if( dist > radius )  continue;

			if( ! reachable(x0,y0, x,y, tComb, lineMatrix) )  continue;
			
			gradMatrix[i]   = val;
			gradMatrix[i+1] = dist;
			i += 2;
		}
	}

	for( i = 0; i < GRAD_MATRIX_SIZE; i+=2 ){
		if( gradMatrix[i] == NO_ELEV_VALUE )  break;
		if( i == GRAD_MATRIX_SIZE-2 )  errorExit( "GRAD_MATRIX_SIZE reached" );
		for( j = 0; j < GRAD_MATRIX_SIZE; j+=2 ){
			if( gradMatrix[j] == NO_ELEV_VALUE )  break;
			if( j == GRAD_MATRIX_SIZE-2 )  errorExit( "GRAD_MATRIX_SIZE reached" );

			grad = (gradMatrix[j] - gradMatrix[i]) / (gradMatrix[j+1] + gradMatrix[i+1]);
			if( grad > gradMax ){
				gradMax = grad;
				elevMin = gradMatrix[i];
				distMin = gradMatrix[i+1];
				elevMax = gradMatrix[j];
				distMax = gradMatrix[j+1];
			}
		}
	}


	if(VERBOSE >= 3)  printf( "min = (%d,%d) %d    max = (%d,%d) %d\n", yMin,xMin,elevMin, yMax,xMax,elevMax );

	if( gradMax <= 0.1 )  return NO_ELEV_VALUE;
	return (int) ((elevMin * distMax + elevMax * distMin) / (distMin + distMax) + 0.5);
}

double point_distance( double x0, double y0, double x, double y ){
	return sqrt( (x0 - x)*(x0 - x) + (y0 - y)*(y0 - y) );
}

int reachable( int x0, int y0, int x, int y, map_tile tComb, map_tile lineMatrix ){
	map_line linePoints;	
	int xi, yi, xp, yp, i, radius;
	VALUE val;
	int ret = 1;

	if( VERBOSE >= 3 )  printf( "reachable (%d,%d) -> (%d,%d)\n", x0,y0, x,y );

	radius = lineMatrix.dx / 4;
	xi = x - x0;
	yi = y - y0;

	linePoints = extract_row( lineMatrix, (yi+radius)*(2*radius+1)+(xi+radius) );
	/* linePoints = make_line_points( radius, x-x0, y-y0, NULL ); // three times slower */

	for( i = 0; i < linePoints.d; i += 2 ){
		if( linePoints.line[i] == NO_ELEV_VALUE )  break;
		xp =	x0 + linePoints.line[i];	
		yp = y0 + linePoints.line[i+1];
		val = get_pixel( tComb, xp, yp );
		if( VERBOSE >= 3 )  printf( "  (%d,%d): %d\n", xp,yp, val );
		if( val != NO_ELEV_VALUE ){
			ret = 0;
			break;
		}
	}	
	free_line( linePoints );

	return ret;
}





map_tile make_line_matrix( int radius ){
	map_tile lineMatrix;
	map_line linePoints;
	int x, y;

	lineMatrix = new_tile( 4*radius, (2*radius+1)*(2*radius+1) );
	if( VERBOSE >= 2 )  printf( "make_line_matrix: dx=%d, dy=%d\n", 2*radius, (2*radius+1)*(2*radius+1) );

	/*
	linePoints = make_line_points( radius, -20, -19, NULL );
	if( radius <= 100 )  exit( 1 );
	*/

	for( y = -radius; y <= radius; ++y ){
		for( x = -radius; x <= radius; ++x ){
			if( VERBOSE >= 2 )  printf( "make_line_matrix: y <%d>  x <%d>\n", y, x );
			linePoints = make_line_points( radius, x, y, NULL );
			if( VERBOSE >= 2 )  printf( "make_line_matrix: set_row %d\n", (y+radius)*(2*radius+1)+(x+radius) );
			set_row( lineMatrix, (y+radius)*(2*radius+1)+(x+radius), linePoints );
		}
	}

	return lineMatrix;
}

map_line make_line_points( int radius, int x0, int y0, map_line *ln ){
	map_line linePoints;
	int x, y, i;
	VALUE val;
	double dd;

	linePoints = new_line( 4*radius );
	if( ln == NULL ){
		for( i = 0; i < 4*radius; i+=2 ){
			linePoints.line[i]   = NO_ELEV_VALUE;
			linePoints.line[i+1] = NO_ELEV_VALUE;
		}
	}else{
		for( i = 0; i < 4*radius; i+=2 ){
			linePoints.line[i]   = ln->line[i];
			linePoints.line[i+1] = ln->line[i+1];
		}
		free_line( *ln );
	}
	/* print_line( "--- line ---", linePoints ); */

	if( y0 == 0 && x0 == 0 ){
		/* do nothing */
	}else if( abs(x0) > abs(y0) ){
		linePoints = make_line_points( radius, y0, x0, &linePoints );
		for( i = 0; i < linePoints.d; i+=2 ){
			if( linePoints.line[i] == NO_ELEV_VALUE )  break;
			val = linePoints.line[i];
			linePoints.line[i] = linePoints.line[i+1];
			linePoints.line[i+1] = val;
			if( VERBOSE >= 2 )  printf( "make_line_points: [%d] postproc A (%d,%d)\n", i, linePoints.line[i], linePoints.line[i+1] );
		}
	}else if( y0 < 0 ){
		linePoints = make_line_points( radius, x0, -y0, &linePoints );
		for( i = 0; i < linePoints.d; i+=2 ){
			if( linePoints.line[i] == NO_ELEV_VALUE )  break;
			linePoints.line[i+1] = -linePoints.line[i+1];
			if( VERBOSE >= 2 )  printf( "make_line_points: [%d] postproc B (%d,%d)\n", i, linePoints.line[i], linePoints.line[i+1] );
		}
	}else{
		dd = x0 / (double) y0;
		i = 0;
		for( y = 0; y < y0; ++y ){
			x = (VALUE) floor( dd * (y + 0.5) + 0.5 );
			if( VERBOSE >= 2 )  printf( "make_line_points: --- y <%d>  x <%d>\n", y, x );
			if( !(i >= 2 && linePoints.line[i-2] == x && linePoints.line[i-1] == y) && !(y == 0 && x == 0) ){
				if( VERBOSE >= 2 )  printf( "make_line_points: [%d] y <%d>  x <%d>\n", i, y, x );
				linePoints.line[i]   = x;
				linePoints.line[i+1] = y;
				i += 2;
			}
			if( !(y+1 == y0 && x == x0) ){
				if( VERBOSE >= 2 )  printf( "make_line_points: [%d] y+1 <%d>  x <%d>\n", i, y+1, x );
				linePoints.line[i]   = x;
				linePoints.line[i+1] = y + 1;
				i += 2;
			}
		}
	}

	return linePoints;
}

void print_line_matrix( map_tile lineMatrix, int radius ){
	int x, y, i;
	map_line linePoints;

	for( y = -radius; y <= radius; ++y ){
		for( x = -radius; x <= radius; ++x ){
			printf( "-------------------\n[%d,%d]\n", y, x );
			linePoints = extract_row( lineMatrix, (y+radius)*(2*radius+1)+(x+radius) );
			for( i = 0; i < 4*radius; i+=2 ){
				if( linePoints.line[i] == NO_ELEV_VALUE )  break;
				if( i > 0 )  printf( " " );
				printf( "(%d:%d,%d)", i/2, linePoints.line[i+1] ,	linePoints.line[i] );
			}
			printf( "\n" );
		}
	}
}



map_tile convert_tile_gradient( map_tile tComb ){
	map_tile tGrad;
	int x, y;

	tGrad = new_tile( tComb.dx, tComb.dy );	

	for( y = 1; y < tComb.dy-1; ++y ){
		for( x = 1; x < tComb.dx-1; ++x ){
			VALUE val, valN = 0, valS = 0, valW = 0, valE = 0;
			int i;
			double dN = tComb.dy, dS = tComb.dy, dW = tComb.dx, dE = tComb.dx;
			val = get_pixel( tComb, x,y );
			if( val != NO_ELEV_VALUE ){
				set_pixel( tGrad, x,y, val );
				continue;
			}
			for( i = x-1; i >= 0; --i ){
				val = get_pixel( tComb, i,y );
				if( val != NO_ELEV_VALUE ){
					valE = val;
					dE = x - i;
					break;
				}
			}
			for( i = x+1; i < tComb.dx; ++i ){
				val = get_pixel( tComb, i,y );
				if( val != NO_ELEV_VALUE ){
					valW = val;
					dW = i - x;
					break;
				}
			}
			for( i = y-1; i >= 0; --i ){
				val = get_pixel( tComb, x,i );
				if( val != NO_ELEV_VALUE ){
					valN = val;
					dN = y - i;
					break;
				}
			}
			for( i = y+1; i < tComb.dy; ++i ){
				val = get_pixel( tComb, x,i );
				if( val != NO_ELEV_VALUE ){
					valS = val;
					dS = i - y;
					break;
				}
			}
			dN = 1 / dN;
			dS = 1 / dS;
			dW = 1 / dW;
			dE = 1 / dE;
			val = (VALUE) floor((dN * valN + dS *valS + dE * valE + dW * valW) / (dN + dS + dW + dE) + .5);
			set_pixel( tGrad, x,y, val );
		}
	}

	return tGrad;
}



map_tile convert_tile_weighted_linear( map_tile tComb ){
	map_tile tOut;
	map_tile tHoriz;
	map_tile tVert;
	map_tile tGradHoriz;
	map_tile tGradVert;
	int x, y;
	map_line ln;
	map_line lnGrad;
	int ctUndef;

	tOut       = new_tile( tComb.dx, tComb.dy );
	tHoriz     = new_tile( tComb.dx, tComb.dy );
	tVert      = new_tile( tComb.dx, tComb.dy );
	tGradHoriz = new_tile( tComb.dx, tComb.dy );
	tGradVert  = new_tile( tComb.dx, tComb.dy );

	for( y = 0; y < tComb.dy; ++y ){
		ln = extract_row( tComb, y );
		lnGrad = new_line( tComb.dx );
		interpolate_linear( ln, 0, &lnGrad );
		set_row( tHoriz, y, ln );
		set_row( tGradHoriz, y, lnGrad );
		free_line( ln );
		free_line( lnGrad );
	}

	for( x = 0; x < tComb.dx; ++x ){
		ln = extract_col( tComb, x );
		lnGrad = new_line( tComb.dy );
		interpolate_linear( ln, 0, &lnGrad );
		set_col( tVert, x, ln );
		set_col( tGradVert, x, lnGrad );
		free_line( ln );
		free_line( lnGrad );
	}

	ctUndef = 0;
	for( y = 0; y < tOut.dy; ++y ){
		for( x = 0; x < tOut.dx; ++x ){
			VALUE pxH = get_pixel( tHoriz, x,y );
			VALUE pxV = get_pixel( tVert, x,y );
			VALUE gradH = get_pixel( tGradHoriz, x,y );
			VALUE gradV = get_pixel( tGradVert, x,y );
			double dd, dH, dV;
			VALUE px;

			/*
			if( (gradH + gradV) == 0 ){
				set_pixel( tOut, x,y, NO_ELEV_VALUE );
				++ctUndef;
				continue;
			}
			*/

			dd = gradH + gradV + .01;
			dH = (gradH + .005) / dd;
			dV = (gradV + .005) / dd;

			px = (int) floor( dH * pxH + dV * pxV + .5 );
			if( VERBOSE >= 2 && y == PRINT_LINE ){
				printf( "[%d][%d]  H = %d  V = %d  --> %d\n", x, y, pxH, pxV, px );
			}
			set_pixel( tOut, x,y, px );
		}
	}
	printf( "Points of unknown elevation = %d\n", ctUndef );

	free_tile( tHoriz );
	free_tile( tVert );
	free_tile( tGradHoriz );
	free_tile( tGradVert );

	return tOut;
}




map_tile convert_tile_average_linear( map_tile tComb ){
	map_tile tHoriz;
	map_tile tVert;
	int x, y;
	map_line ln;

	tHoriz = new_tile( tComb.dx, tComb.dy );
	tVert  = new_tile( tComb.dx, tComb.dy );

	for( y = 0; y < tComb.dy; ++y ){
		ln = extract_row( tComb, y );
		interpolate_linear( ln, 0, NULL );
		set_row( tHoriz, y, ln );
		free_line( ln );
	}

	for( x = 0; x < tComb.dx; ++x ){
		ln = extract_col( tComb, x );
		interpolate_linear( ln, 0, NULL );  		
		set_col( tVert, x, ln );
		free_line( ln );
	}

	for( y = 0; y < tComb.dy; ++y ){
		for( x = 0; x < tComb.dx; ++x ){
			VALUE pxH = get_pixel( tHoriz, x,y );
			VALUE pxV = get_pixel( tVert, x,y );
			VALUE px  = (pxH + pxV) / 2;
			if( VERBOSE >= 2 && y == PRINT_LINE ){
				printf( "[%d][%d]  H = %d  V = %d  --> %d\n", x, y, pxH, pxV, px );

			}
			set_pixel( tComb, x,y, px );
		}
	}

	free_tile( tHoriz );
	free_tile( tVert );

	return tComb;
}

map_line extract_row( map_tile tSrc, int y ){
	map_line ln;
	int x;

	ln = new_line( tSrc.dx );
	for( x = 0; x < tSrc.dx; ++x ){
		ln.line[x] = get_pixel( tSrc, x,y );
	}
	return ln;
}

map_line extract_col( map_tile tSrc, int x ){
	map_line ln;
	int y;

	ln = new_line( tSrc.dy );
	for( y = 0; y < tSrc.dy; ++y ){
		ln.line[y] = get_pixel( tSrc, x,y );
	}
	return ln;
}

void set_row( map_tile tDst, int y, map_line ln ){
	int x;
	for( x = 0; x < tDst.dx; ++x ){
		set_pixel( tDst, x,y, ln.line[x] );
	}
}

void set_col( map_tile tDst, int x, map_line ln ){
	int y;
	for( y = 0; y < tDst.dy; ++y ){
		set_pixel( tDst, x,y, ln.line[y] );
	}
}

void interpolate_linear( map_line ln, int verbose, map_line *lnGrad ){
	int i,j, idxP = -1; 
	double dd;
	VALUE val, valP = 0;

	if( verbose )  printf( "--- interpolate_linear ---\n" );  /* _DEBUG_ */
	for( i = 0; i <= ln.d; ++i ){
		if( i < ln.d ){
			val = ln.line[i];
			if( val == NO_ELEV_VALUE )  continue;
			ln.line[i] = val;
			if( lnGrad != NULL )  lnGrad->line[i] = 1;
			if( verbose ){
				if( lnGrad != NULL ){
					printf( "  ln[%d] = %d  (%d)\n", j, ln.line[j], lnGrad->line[j] );  /* _DEBUG_ */
				}else{	
					printf( "* ln[%d] = %d\n", i, ln.line[i] );  /* _DEBUG_ */
				}
			}
		}else{
			val = 0;
		}

		dd = ((double) (val-valP)) / (i-idxP);
		for( j = idxP+1; j < i; ++j ){	
			ln.line[j] = (VALUE) floor( valP + (j - idxP) * dd + .5 );
			if( lnGrad != NULL )  lnGrad->line[j] = abs((int) floor(dd+.5));
			if( verbose ){
				if( lnGrad != NULL ){
					printf( "  ln[%d] = %d  (%d)\n", j, ln.line[j], lnGrad->line[j] );  /* _DEBUG_ */
				}else{	
					printf( "  ln[%d] = %d\n", j, ln.line[j] );  /* _DEBUG_ */
				}
			}
		}

		idxP = i;
		valP = val;
	}
}


map_tile combine_complete_tileset(
	map_tile t00, map_tile t01, map_tile t02, map_tile t10, map_tile t11, map_tile t12, map_tile t20, map_tile t21, map_tile t22 ){

	int dx = t11.dx;
	int dy = t11.dy;
	map_tile tComb;
	int dxDst = 3 * dx;
	int dyDst = 3 * dy;

	tComb = new_tile( dx * 3, dy * 3 );

	copy_subtile(    0,    0, 0,0, dx,dy, tComb, t00 );
	copy_subtile(   dx,    0, 0,0, dx,dy, tComb, t01 );
	copy_subtile( 2*dx,    0, 0,0, dx,dy, tComb, t02 );
	copy_subtile(    0,   dy, 0,0, dx,dy, tComb, t10 );
	copy_subtile(   dx,   dy, 0,0, dx,dy, tComb, t11 );
	copy_subtile( 2*dx,   dy, 0,0, dx,dy, tComb, t12 );
	copy_subtile(    0, 2*dy, 0,0, dx,dy, tComb, t20 );
	copy_subtile(   dx, 2*dy, 0,0, dx,dy, tComb, t21 );
	copy_subtile( 2*dx, 2*dy, 0,0, dx,dy, tComb, t22 );

	return tComb;
}

map_tile combine_tiles( int offsetX, int offsetY, int dxTotal, int dyTotal,
	map_tile t00, map_tile t01, map_tile t02, map_tile t10, map_tile t11, map_tile t12, map_tile t20, map_tile t21, map_tile t22 ){

	int dx = t11.dx;
	int dy = t11.dy;
	map_tile tComb;
	map_tile tSub;
	tComb = combine_complete_tileset( t00, t01, t02, t10, t11, t12, t20, t21, t22 );

	if( offsetX < 0 || offsetY < 0 || offsetX + dxTotal > 3*dx || offsetY + dyTotal > 3*dx ){
		errorExit( "combine_tiles: invalid offset/size combination\n" );
	}
	if( offsetX > 0 || offsetY > 0 || dxTotal < 3*dx || dyTotal < 3*dx ){
		tSub = extract_subtile( offsetX, offsetY, dxTotal, dyTotal, tComb );
	}
	free_tile( tComb );

	return tSub;
}

map_tile surround_central_tile( int margin,
	map_tile t00, map_tile t01, map_tile t02, map_tile t10, map_tile t11, map_tile t12, map_tile t20, map_tile t21, map_tile t22 ){

	int dx = t11.dx;
	int dy = t11.dy;
	map_tile tComb;
	tComb = combine_tiles( dx-margin, dy-margin, dx+2*margin, dy+2*margin, t00, t01, t02, t10, t11, t12, t20, t21, t22 );
	
	return tComb;
}


/* void copy_subtile( int dxDst, int dyDst, int dxSrc, int dySrc, int offXdst, int offYdst, int offXsrc, int offYsrc, int dxSub, int dySub, TILE tDst, TILE tSrc ){ */
void copy_subtile( int offXdst, int offYdst, int offXsrc, int offYsrc, int dxSub, int dySub, map_tile tDst, map_tile tSrc ){
	int y, x;

	if( VERBOSE >= 1 )  printf( "copy_subtile dst %p (%dx%d+%d+%d) src %p (%dx%d+%d+%d)\n", tDst.tile, tDst.dx,tDst.dy,offXdst,offYdst, tSrc.tile, tSrc.dx,tSrc.dy,offXsrc,offYsrc );

	if( offXsrc >= tSrc.dx || tSrc.dx <= 0 ){
		errorExit( "copy_subtile: offXsrc >= tSrc.dx || tSrc.dx <= 0\n" );
	}
	if( offYsrc >= tSrc.dy || tSrc.dy <= 0 ){
		errorExit( "copy_subtile: offYsrc >= tSrc.dy || tSrc.dy <= 0\n" );
	}

	if( offXsrc + dxSub > tSrc.dx ){
		errorExit( "copy_subtile: offXsrc + dxSub > tSrc.dx\n" );
	}
	if( offYsrc + dySub > tSrc.dy ){
		errorExit( "copy_subtile: offYsrc + dySub > tSrc.dy\n" );
	}
	if( offXdst + dxSub > tDst.dx ){
		errorExit( "copy_subtile: offXdst + dxSub > tDst.dx\n" );
	}
	if( offYdst + dySub > tDst.dy ){
		errorExit( "copy_subtile: offYdst + dySub > tDst.dy\n" );
	}

/*
	for( y = 0; y < dySub; ++y ){  
		ptr = memcpy( &(tDst[offYdst+y][offXdst]), &(tSrc[offYsrc+y][offXsrc]), dxSub * BYTES_PER_PIXEL );
		if( ptr == NULL ){
			errorExit( "memcpy error!!!\n" );
		}
	}
*/

	/* print_tile( "--- IN ---\n", tDst ); */

	for( y = 0; y < dySub; ++y ){  
		for( x = 0; x < dxSub; ++x ){  
			if( VERBOSE >= 3 )  printf( "  tDst[%d][%d] = tSrc[%d][%d] --> %d\n", offYdst+y,offXdst+x, offYsrc+y,offXsrc+x, get_pixel(tSrc,offXsrc+x,offYsrc+y) );
			set_pixel( tDst, offXdst+x, offYdst+y, get_pixel(tSrc,offXsrc+x,offYsrc+y) );
		}
	}

	/* print_tile( "--- OUT ---\n", tDst ); */
}

map_tile *split_tile( map_tile tSrc, int numX, int numY ){
	map_tile *tile_list;
	int x, y, dxDst, dyDst;

	if( tSrc.dx % numX != 0 ){
		errorExit( "split_tile: tSrc.dx not divisible by numX" );
	}
	if( tSrc.dy % numY != 0 ){
		errorExit( "split_tile: tSrc.dx not divisible by numX" );
	}

	dxDst = tSrc.dx / numX;
	dyDst = tSrc.dy / numY;

	tile_list = mallocOrDie( sizeof(map_tile) * numX * numY );

	for( y = 0; y < numY; ++y ){
		for( x = 0; x < numX; ++x ){
			tile_list[numX*y+x] = extract_subtile( x*dxDst,y*dyDst, dxDst,dyDst, tSrc );
		}
	}

	return tile_list;
}

map_tile inflate_tile( map_tile tSrc, int numX, int numY ){
	map_tile tInf;
	int x, y, xx, yy, dxDst, dyDst;

	dxDst = tSrc.dx * numX;
	dyDst = tSrc.dy * numY;
	
	tInf = new_tile( dxDst, dyDst );

	for( y = 0; y < tSrc.dy; ++y ){
		for( x = 0; x < tSrc.dx; ++x ){
			VALUE val = get_pixel( tSrc, x, y );
			for( yy = 0; yy < numY; ++yy ){ 
				for( xx = 0; xx < numX; ++xx ){ 
					set_pixel( tInf, x*numX+xx, y*numY+yy, val );
				}
			}
		}
	}

	return tInf;
}



int pixel_offset( map_tile t, int x, int y ){
	return y * t.dx + x;
}

void set_pixel( map_tile t, int x, int y, VALUE val ){
	t.tile[pixel_offset(t,x,y)] = val;
}

void set_pixel_max( map_tile t, int x, int y, VALUE val, VALUE maxVal ){
	int off;	
	VALUE vPrev;

	off = pixel_offset( t, x, y );
	vPrev = t.tile[off];
	if( (vPrev > maxVal && val > vPrev) || val < maxVal ){
		t.tile[off] = val;
	}
}

void set_pixel_min( map_tile t, int x, int y, VALUE val ){
	int off;	
	VALUE vPrev;

	off = pixel_offset( t, x, y );
	vPrev = t.tile[off];
	if( val < vPrev && val != NO_ELEV_VALUE ){
		t.tile[off] = val;
	}
}

VALUE get_pixel( map_tile t, int x, int y ){
	return t.tile[pixel_offset(t,x,y)];
}


map_tile extract_subtile( int offsetX, int offsetY, int dxSub, int dySub, map_tile tSrc ){
	map_tile tSub;

	if( VERBOSE >= 1 )  printf( "extract_subtile %p %dx%d --> %dx%d+%d+%d\n", tSrc.tile, tSrc.dx,tSrc.dy, dxSub,dySub,offsetX,offsetY );
	tSub = new_tile( dxSub, dySub );
	copy_subtile( 0,0, offsetX,offsetY, dxSub,dySub, tSub, tSrc );

	return tSub;
}

map_tile extract_central_tile( int margin, map_tile tSrc ){
	map_tile tSub;
	tSub = extract_subtile( margin, margin, tSrc.dx-2*margin, tSrc.dy-2*margin, tSrc );
	return tSub;
}

map_tile data_tile( int dx, int dy, TILE tData ){
	map_tile t;
	t.dx = dx;
	t.dy = dy;
	t.tile = tData;
	return t;
}

map_tile new_tile( int dx, int dy ){
	map_tile t;

	if( VERBOSE >= 1 )  printf( "new_tile: %d x %d --> %d\n", dx, dy, dx * dy * BYTES_PER_PIXEL );
	t.tile = (TILE) mallocOrDie( dx * dy * BYTES_PER_PIXEL );

	t.dx = dx;
	t.dy = dy;
	return t;
}

map_line new_line( int d ){
	map_line ln;
	ln.line = (LINE) mallocOrDie( d * BYTES_PER_PIXEL );
	ln.d = d;
	return ln;
}

void free_tile( map_tile t ){
	free( t.tile );
}

void free_line( map_line ln ){
	free( ln.line );
}




void print_tile( char *text, map_tile t ){
	int x, y;
	printf( "--- %s ---\n", text );
	for( y = 0; y < t.dy; ++y ){
		printf( "[%d]", y );
		for( x = 0; x < t.dx; ++x ){
			printf( " %04d", get_pixel(t,x,y) );
		}
		printf( "\n" );
	}
	fflush(stdout);
}

void print_line( char *text, map_line ln ){
	int i;
	printf( "--- %s ---\n", text );
	for( i = 0; i < ln.d; ++i ){
		printf( "[%d] %4d\n", i, ln.line[i] );
	}
}



void *mallocOrDie( int amount ){
	void *ptr;
//	ptr = malloc( amount );
	ptr = calloc( amount, 1 );
	if( ptr == NULL ){
		errorExit( "malloc error!!!\n" );
	}
	
	return ptr;
}

void errorExit( char *errTxt ){
	printf( errTxt );
	exit( 1 );
}



void map_tile_shift_values( map_tile tElev, int dx, int dy, VALUE vEmpty ){
	int x0 = 0, x1 = 0, y0 = 0, y1 = 0, stepX, stepY;
	int x, y, xp, yp;
	VALUE vElev;

	/* printf( "map_tile_shift_values: dx <%d> dy <%d>\n", dx, dy );  ** _DEBUG_ */

	if( dy >= 0 ){
		y0 = tElev.dy-1;
		y1 = 0;
	}else{
		y0 = 0;
		y1 = tElev.dy;
	}
	if( dx >= 0 ){
		x0 = tElev.dx-1;
		x1 = 0;
	}else{
		x0 = 0;
		x1 = tElev.dx;
	}
	stepX = (x1 < x0)? -1 : 1;
	stepY = (y1 < y0)? -1 : 1;
	/* printf( "x [%d;%d;%d]  y [%d;%d;%d]\n", x0,x1,stepX, y0,y1,stepY ); fflush(stdout); */

	for( y = y0; ((stepY == 1)? (y < y1) : (y >= y1)); y += stepY ){
		for( x = x0; ((stepX == 1)? (x < x1) : (x >= x1)); x += stepX ){
			xp = x - dx;
			yp = y - dy;
			/* printf( "xp:%d  yp:%d\n", xp, yp ); */
			if( xp >= 0 && xp < tElev.dx && yp >= 0 && yp < tElev.dy ){
				vElev = get_pixel( tElev, xp, yp );
			}else{
				vElev = vEmpty;
			}
			set_pixel( tElev, x, y, vElev );
		}
	}
}


void apply_elevation_max( map_tile tCanvas, int x0, int y0, map_tile tPaint, double mult, map_tile tPrev, int flags ){
	int x, y, xp, yp;
	VALUE vPaint, vCanvas, vPrev;	

	for( y = 0; y < tPaint.dy; ++y ){
		yp = y0 + y;
		if( yp >= tCanvas.dy ) break; if( yp < 0 ) continue;
		for( x = 0; x < tPaint.dx; ++x ){
			xp = x0 + x;
			if( xp >= tCanvas.dx ) break; if( xp < 0 ) continue;
			/* printf( "y:%d x:%d yp:%d xp:%d\n", y,x, yp,xp  );  -- _DEBUG_ */
			vPrev   = get_pixel( tPrev, xp,yp );
			if( (flags & FLAG_LAND_AREA) && vPrev <= 0 ) continue;
			vPaint  = get_pixel( tPaint, x,y );
			vCanvas = get_pixel( tCanvas, xp,yp );
			/* printf( "y:%d x:%d yp:%d xp:%d  P=%d M=%lf C=%d\n", y,x, yp,xp, vPaint*mult, mult, vCanvas );  -- _DEBUG_ */
			if( vPaint*mult > vCanvas )  set_pixel( tCanvas, xp,yp, (VALUE) (vPaint*mult) );
		}
	}
}

void apply_elevation_max_shift( map_tile tCanvas, int x0, int y0, map_tile tPaint, double max, map_tile tPrev, int flags ){
	int x, y, xp, yp;
	VALUE vPaint, vPaintC, vCanvas, vPrev;	

	x = tPaint.dx / 2;
	y = tPaint.dy / 2;
	vPaintC = get_pixel( tPaint, x, y );
	/* printf( "min:%lf vPaintC:%d\n", min, vPaintC );  -- _DEBUG_ */ 

	for( y = 0; y < tPaint.dy; ++y ){
		yp = y0 + y;
		if( yp >= tCanvas.dy ) break; if( yp < 0 ) continue;
		for( x = 0; x < tPaint.dx; ++x ){
			xp = x0 + x;
			if( xp >= tCanvas.dx ) break; if( xp < 0 ) continue;
			/* printf( "y:%d x:%d yp:%d xp:%d\n", y,x, yp,xp ); -- _DEBUG_ */
			/* printf( "y:%d x:%d yp:%d xp:%d off:%d\n", y,x, yp,xp, 2*pixel_offset(tCanvas,xp,yp) ); -- _DEBUG_ */
			/* vPrev   = get_pixel( tPrev, xp,yp ); */
			/* if( (flags & FLAG_LAND_AREA) && vPrev <= 0 ) continue; */
			vPaint  = get_pixel( tPaint, x,y );
			vCanvas = get_pixel( tCanvas, xp,yp );
			if( max - (vPaintC - vPaint) > vCanvas )  set_pixel( tCanvas, xp,yp, (VALUE) (max - (vPaintC - vPaint)) );
		}
	}
}

void apply_elevation_min_shift( map_tile tCanvas, int x0, int y0, map_tile tPaint, double min, map_tile tPrev, int flags ){
	int x, y, xp, yp;
	VALUE vPaint, vPaintC, vCanvas, vPrev;	

	x = tPaint.dx / 2;
	y = tPaint.dy / 2;
	vPaintC = get_pixel( tPaint, x, y );
	/* printf( "min:%lf vPaintC:%d\n", min, vPaintC );  -- _DEBUG_ */ 

	for( y = 0; y < tPaint.dy; ++y ){
		yp = y0 + y;
		if( yp >= tCanvas.dy ) break; if( yp < 0 ) continue;
		for( x = 0; x < tPaint.dx; ++x ){
			xp = x0 + x;
			if( xp >= tCanvas.dx ) break; if( xp < 0 ) continue;
			/* printf( "y:%d x:%d yp:%d xp:%d\n", y,x, yp,xp ); -- _DEBUG_ */
			/* printf( "y:%d x:%d yp:%d xp:%d off:%d\n", y,x, yp,xp, 2*pixel_offset(tCanvas,xp,yp) ); -- _DEBUG_ */
			/* vPrev   = get_pixel( tPrev, xp,yp ); */
			/* if( (flags & FLAG_LAND_AREA) && vPrev <= 0 ) continue; */
			vPaint  = get_pixel( tPaint, x,y );
			vCanvas = get_pixel( tCanvas, xp,yp );
			if( min + vPaintC - vPaint < vCanvas )  set_pixel( tCanvas, xp,yp, (VALUE) (min + vPaintC - vPaint) );
		}
	}
}

void apply_elevation_add( map_tile tCanvas, int x0, int y0, map_tile tPaint, double mult, map_tile tPrev, int flags ){
	int x, y, xp, yp;
	VALUE vPaint, vCanvas, vPrev;	

	for( y = 0; y < tPaint.dy; ++y ){
		yp = y0 + y;
		if( yp >= tCanvas.dy ) break; if( yp < 0 ) continue;
		for( x = 0; x < tPaint.dx; ++x ){
			xp = x0 + x;
			if( xp >= tCanvas.dx ) break; if( xp < 0 ) continue;
			vPrev   = get_pixel( tPrev, xp,yp );
			/* if( (flags & FLAG_LAND_AREA) && vPrev <= 0 ) continue; */
			vPaint  = get_pixel( tPaint, x,y );
			vCanvas = get_pixel( tCanvas, xp,yp );
			if( vPrev + vPaint*mult > vCanvas )  set_pixel( tCanvas, xp,yp, vPrev + (VALUE) (vPaint*mult) );
		}
	}
}

void apply_elevation_subtract( map_tile tCanvas, int x0, int y0, map_tile tPaint, double mult, map_tile tPrev, int flags ){
	int x, y, xp, yp;
	VALUE vPaint, vCanvas, vPrev;	

	for( y = 0; y < tPaint.dy; ++y ){
		yp = y0 + y;
		if( yp >= tCanvas.dy ) break; if( yp < 0 ) continue;
		for( x = 0; x < tPaint.dx; ++x ){
			xp = x0 + x;
			if( xp >= tCanvas.dx ) break; if( xp < 0 ) continue;
			vPrev   = get_pixel( tPrev, xp,yp );
			/* if( (flags & FLAG_LAND_AREA) && vPrev <= 0 ) continue; */
			vPaint  = get_pixel( tPaint, x,y );
			vCanvas = get_pixel( tCanvas, xp,yp );
			VALUE vNew = vPrev - (VALUE) (vPaint*mult);
			if( (flags & FLAG_LAND_AREA) && vNew < 1 ) vNew = 1;
			if( vNew < vCanvas ) 	set_pixel( tCanvas, xp,yp, vNew );
		}
	}
}

void apply_elevation_subtract_center( map_tile tCanvas, int x0, int y0, map_tile tPaint, double mult, map_tile tPrev, int flags ){
	int x, y, xp, yp;
	VALUE vPaint, vCanvas, vPrev, vCenter, vPaintC;

	x = tPaint.dx / 2;
	y = tPaint.dy / 2;
	xp = x0 + x;
	yp = y0 + y;
	if( yp >= tCanvas.dy || yp < 0 || xp >= tCanvas.dx || xp < 0 ) return;
	vPrev   = get_pixel( tPrev,   xp,yp );
	vPaintC = get_pixel( tPaint,  x,y );
	/* vCanvas = get_pixel( tCanvas, xp,yp ); */
	vCenter = vPrev - vPaintC*mult;

	for( y = 0; y < tPaint.dy; ++y ){
		yp = y0 + y;
		if( yp >= tCanvas.dy ) break; if( yp < 0 ) continue;
		for( x = 0; x < tPaint.dx; ++x ){
			xp = x0 + x;
			if( xp >= tCanvas.dx ) break; if( xp < 0 ) continue;
			/* if( (flags & FLAG_LAND_AREA) && vPrev <= 0 ) continue; */
			vPaint  = get_pixel( tPaint, x,y );
			if( vPaint == 0 )  continue;
			vPrev   = get_pixel( tPrev, xp,yp );
			vCanvas = get_pixel( tCanvas, xp,yp );
			/* if( vPrev - vPaint*mult < vCanvas )  set_pixel( tCanvas, xp,yp, vPrev - (VALUE) (vPaint*mult) ); */
			if( vCenter + (vPaintC-vPaint)*mult < vCanvas )  set_pixel( tCanvas, xp,yp, vCenter + (VALUE) ((vPaintC - vPaint)*mult) );
		}
	}
}



void apply_elevation_min_max( map_tile tCanvas, int x0, int y0, map_tile tPaint, double mult, int *minMax ){
	int x, y, xp, yp;
	VALUE vPaint, vCanvas;	
	int sign = *minMax;

	if( sign == 0 ){
		x = tPaint.dx / 2;
		y = tPaint.dy / 2;
		xp = x0 + x;
		yp = y0 + y;
		if( yp >= tCanvas.dy || yp < 0 || xp >= tCanvas.dx || xp < 0 ) return;
		vPaint  = get_pixel( tPaint,  x,y );
		vCanvas = get_pixel( tCanvas, xp,yp );
		if( vPaint * mult > vCanvas )  sign =  1;
		if( vPaint * mult < vCanvas )  sign = -1;
		if( sign == 0 )  return;
		*minMax = sign;
	}

	for( y = 0; y < tPaint.dy; ++y ){
		yp = y0 + y;
		if( yp >= tCanvas.dy ) break; if( yp < 0 ) continue;
		for( x = 0; x < tPaint.dx; ++x ){
			xp = x0 + x;
			if( xp >= tCanvas.dx ) break; if( xp < 0 ) continue;
			/* printf( "y:%d x:%d yp:%d xp:%d\n", y,x, yp,xp  );  -- _DEBUG_ */
			vPaint  = get_pixel( tPaint, x,y );
			vCanvas = get_pixel( tCanvas, xp,yp );
			if( vPaint*mult*sign > vCanvas*sign )  set_pixel( tCanvas, xp,yp, (VALUE) (vPaint*mult) );
		}
	}
}




void apply_elevation_add_prev( map_tile tCanvas, int x0, int y0, map_tile tPaint, double mult, map_tile tPrev, int dx, int dy ){
	int x, y, xp, yp;

/*	map_tile_shift_values( tPrev, -dx, -dy, tCanvas, x0, y0 ); */
	map_tile_shift_values( tPrev, -dx, -dy, NO_ELEV_VALUE );

	for( y = 0; y < tPaint.dy; ++y ){
		yp = y0 + y;
		if( yp >= tCanvas.dy ) break; if( yp < 0 ) continue;
		for( x = 0; x < tPaint.dx; ++x ){
			xp = x0 + x;
			if( xp >= tCanvas.dx ) break; if( xp < 0 ) continue;
			VALUE vCanvas = get_pixel( tCanvas, xp,yp );
			VALUE vPrev   = get_pixel( tPrev, x,y );
			VALUE vPaint  = get_pixel( tPaint, x,y );
			vPaint = (VALUE) (vPaint * mult);
			if( vPrev == NO_ELEV_VALUE ){
				set_pixel( tCanvas, xp,yp, vCanvas + vPaint );
				set_pixel( tPrev, x,y, vCanvas );
			}else{
				if(mult >= 0 && (vPrev+vPaint > vCanvas) || mult < 0 && (vPrev+vPaint < vCanvas)) set_pixel( tCanvas, xp,yp, vPrev + vPaint );
			}
		}
	}
}

char *make_scanline_str( int dx, int dy ){
	char *str;
	int len = dy * (2 + dx * 8);
	str = mallocOrDie( len + 1 );
	str[len] = 0;
	return str;
}

void init_global_color_map( map_tile tColorMap ){
	tGlobalColorMap = tColorMap;
}

map_tile *get_global_color_map(){
	return &tGlobalColorMap;
}

void get_color_values( char *dst, map_tile tCanvas, int x0, int y0, int dx, int dy, map_tile *tColorMap ){
	char *ptr = dst;
	int x, y, xp, yp;

	if( tColorMap == NULL ){
		tColorMap = &tGlobalColorMap;
	}
	/* print_tile( "tColorMap", *tColorMap );   -- _DEBUG */

	for( y = 0; y < dy; ++y ){
		yp = y0 + y;
		if( yp >= tCanvas.dy ) break; if( yp < 0 ) continue;
		sprintf( ptr, "{" );
		ptr += 1;
		for( x = 0; x < dx; ++x ){
			xp = x0 + x;
			if( xp >= tCanvas.dx ) break; if( xp < 0 ) continue;
			int vCanvas = get_pixel( tCanvas, xp,yp );
			int r = get_pixel( *tColorMap, vCanvas+COLORMAP_ADD,0 );
			int g = get_pixel( *tColorMap, vCanvas+COLORMAP_ADD,1 );
			int b = get_pixel( *tColorMap, vCanvas+COLORMAP_ADD,2 );
			/* printf( "%d,%d elev[%d] r:%d g:%d b:%d --> #%02x%02x%02x\n", xp,yp, vCanvas, r,g,b, r,g,b );  fflush(stdout);  -- _DEBUG_ */

			relief_color_transform( &r, &g, &b, tCanvas, xp, yp );

			/* printf( "%d,%d elev[%d] r:%d g:%d b:%d --> #%02x%02x%02x\n", xp,yp, vCanvas, r,g,b, r,g,b );  fflush(stdout);  -- _DEBUG_ */
			sprintf( ptr, "#%02x%02x%02x ", r,g,b );
			ptr += 8;
		}
		sprintf( ptr, "}" );
		ptr += 1;
	}
}



double VERT_EX = 5;
double C_POS = .4;
double C_NEG = .9;
double MP_X = 500;
double MP_Y = 500;

/*   light from direction  [ -1, -1, .2 ]   */
double vL0 = -1, vL1 = -1, vL2 = .2;
double dL = 1.42828568570857;   /* sqrt( vL0*vL0 + vL1*vL1 + vL2*vL2 ) */


void relief_color_transform( int *pR, int *pB, int *pG, map_tile tCanvas, int x, int y ){
	int r = *pR, g = *pG, b = *pB;
	double gradX, gradY;
	double vX0 = MP_X, vX1 = 0,    vX2;
	double vY0 = 0,    vY1 = MP_Y, vY2;
	double vN0, vN1, vN2;
	double dd, prod;

	if( x == 0 || y == 0 || x == tCanvas.dx || y == tCanvas.dy )  return;
	gradX = (get_pixel(tCanvas,x+1,y) - get_pixel(tCanvas,x-1,y)) / 2;
	gradY = (get_pixel(tCanvas,x,y+1) - get_pixel(tCanvas,x,y-1)) / 2;
	vX2 = VERT_EX * gradX;
	vY2 = VERT_EX * gradY;

	vN0 = vX1 * vY2 - vX2 * vY1;
	vN1 = vX2 * vY0 - vX0 * vY2;
	vN2 = vX0 * vY1 - vX1 * vY0;

	dd   = dL * sqrt( vN0*vN0 + vN1*vN1 + vN2*vN2 );
	prod = (vN0*vL0 + vN1*vL1 + vN2*vL2) / dd;

	*pR = (prod > 0)? floor( r + C_POS * prod * (255-r) ) : floor( r + C_NEG * prod * r );
	*pG = (prod > 0)? floor( g + C_POS * prod * (255-g) ) : floor( g + C_NEG * prod * g );
	*pB = (prod > 0)? floor( b + C_POS * prod * (255-b) ) : floor( b + C_NEG * prod * b );
}






