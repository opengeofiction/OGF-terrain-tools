#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"


#ifdef WIN32
#define snprintf _snprintf
#endif


#include <stdio.h>
#include "tile_util.h"



/* surroundTile( dx, dy, margin, t00, t01, t02, t10, t11, t12, t20, t21, t22 )
	char *  t00
	char *  t01
	char *  t02
	char *  t10
	char *  t11
	char *  t12
	char *  t20
	char *  t21
	char *  t22
*/


MODULE = OGF::TileUtil		PACKAGE = OGF::TileUtil		

PROTOTYPES: ENABLE



void
printTest()
	CODE:
		printf( "* 1\n" );
		printf( "+ printf\n" );
		fprintf( stdout, "+ stdout\n" );
		fprintf( stderr, "+ stderr\n" );




SV *
surroundTile( dx, dy, margin, ... )
	int     dx
	int     dy
    int     margin
	CODE:
	{
		map_tile tSrnd;

		if( items < 12 ){
		    croak( "surroundTile: not enough items in tileList" );
		}

		if( VERBOSE >= 1 ){
			printf( "--- surroundTile ---\n" );  /* _DEBUG_ */
			printf( "dx <%d>\n", dx );           /* _DEBUG_ */
			printf( "dy <%d>\n", dy );           /* _DEBUG_ */
			printf( "margin <%d>\n", margin );   /* _DEBUG_ */
		}

		tSrnd = surround_central_tile( margin,
			data_tile( dx, dy, (TILE) SvPV_nolen( ST(3) ) ),
			data_tile( dx, dy, (TILE) SvPV_nolen( ST(4) ) ),
			data_tile( dx, dy, (TILE) SvPV_nolen( ST(5) ) ),
			data_tile( dx, dy, (TILE) SvPV_nolen( ST(6) ) ),
			data_tile( dx, dy, (TILE) SvPV_nolen( ST(7) ) ),
			data_tile( dx, dy, (TILE) SvPV_nolen( ST(8) ) ),
			data_tile( dx, dy, (TILE) SvPV_nolen( ST(9) ) ),
			data_tile( dx, dy, (TILE) SvPV_nolen( ST(10) ) ),
			data_tile( dx, dy, (TILE) SvPV_nolen( ST(11) ) )
		);

		RETVAL = newSVpvn( (char*) tSrnd.tile, tSrnd.dx * tSrnd.dy * BYTES_PER_PIXEL );
		free_tile( tSrnd );
	}
	OUTPUT:
	RETVAL




SV *
convertTile( method, dx, dy, tSrnd )
	char *		method
	int     dx
	int     dy
	char *		tSrnd
	CODE:
	{
		map_tile tConv;

		if( VERBOSE >= 1 ){
			printf( "--- convertTile ---\n" );  /* _DEBUG_ */
			printf( "method <%s>\n", method );  /* _DEBUG_ */
			printf( "dx <%d>\n", dx );          /* _DEBUG_ */
			printf( "dy <%d>\n", dy );          /* _DEBUG_ */
			printf( "tSrnd <%p>\n", tSrnd );    /* _DEBUG_ */
		}

		tConv = convert_tile( method, data_tile(dx,dy,(TILE) tSrnd) );

		RETVAL = newSVpvn( (char*) tConv.tile, tConv.dx * tConv.dy * BYTES_PER_PIXEL );
		free_tile( tConv );
	}
	OUTPUT:
	RETVAL




SV *
extractSubtile( xOff, yOff, dxSub,dySub, dx, dy, tSrc )
	int     xOff
	int     yOff
	int     dxSub
	int     dySub
	int     dx
	int     dy
	char *		tSrc
	CODE:
	{
		map_tile tSub;

		if( VERBOSE >= 1 ){
			printf( "--- extractSubtile ---\n" );  /* _DEBUG_ */
			printf( "xOff <%d>\n", xOff );         /* _DEBUG_ */
			printf( "yOff <%d>\n", yOff );         /* _DEBUG_ */
			printf( "dxSub <%d>\n", dxSub );       /* _DEBUG_ */
			printf( "dySub <%d>\n", dySub );       /* _DEBUG_ */
			printf( "dx <%d>\n", dx );             /* _DEBUG_ */
			printf( "dy <%d>\n", dy );             /* _DEBUG_ */
			printf( "tSrc <%p>\n", tSrc );         /* _DEBUG_ */
		}

		tSub = extract_subtile( xOff, yOff, dxSub,dySub, data_tile(dx,dy,(TILE) tSrc) );

		if( VERBOSE >= 1 ){
			printf( "tSub.dx <%d>\n", tSub.dx );  /* _DEBUG_ */
			printf( "tSub.dy <%d>\n", tSub.dy );  /* _DEBUG_ */
		}

		RETVAL = newSVpvn( (char*) tSub.tile, tSub.dx * tSub.dy * BYTES_PER_PIXEL );
		free_tile( tSub );
	}
	OUTPUT:
	RETVAL



SV *
inflateTile( dx, dy, tSrc, numX, numY )
	int     dx
	int     dy
	char *		tSrc
	int     numX
	int     numY
	CODE:
	{
		map_tile tInf;

		if( VERBOSE >= 1 ){
			printf( "--- inflateTile ---\n" );  /* _DEBUG_ */
			printf( "dx <%d>\n", dx );          /* _DEBUG_ */
			printf( "dy <%d>\n", dy );          /* _DEBUG_ */
			printf( "numX <%d>\n", numX );      /* _DEBUG_ */
			printf( "numY <%d>\n", numY );      /* _DEBUG_ */
			printf( "tSrc <%p>\n", tSrc );      /* _DEBUG_ */
		}

		tInf = inflate_tile( data_tile(dx,dy,(TILE) tSrc), numX, numY );

		if( VERBOSE >= 1 ){
			printf( "tSub.dx <%d>\n", tInf.dx );  /* _DEBUG_ */
			printf( "tSub.dy <%d>\n", tInf.dy );  /* _DEBUG_ */
		}

		RETVAL = newSVpvn( (char*) tInf.tile, tInf.dx * tInf.dy * BYTES_PER_PIXEL );
		free_tile( tInf );
	}
	OUTPUT:
	RETVAL




void
splitTile( dx, dy, tSrc, numX, numY )
	int     dx
	int     dy
	char *		tSrc
	int     numX
	int     numY
	PPCODE:
	{
		int i, n;
		map_tile *tile_list;

		if( VERBOSE >= 1 ){
			printf( "--- splitTile ---\n" );  /* _DEBUG_ */
			printf( "dx <%d>\n", dx );        /* _DEBUG_ */
			printf( "dy <%d>\n", dy );        /* _DEBUG_ */
			printf( "numX <%d>\n", numX );    /* _DEBUG_ */
			printf( "numY <%d>\n", numY );    /* _DEBUG_ */
			printf( "tSrc <%p>\n", tSrc );    /* _DEBUG_ */
		}

		n = numX * numY;
		tile_list = split_tile( data_tile(dx,dy,(TILE) tSrc), numX, numY );

		for( i = 0; i < n; ++i ){
			map_tile t = tile_list[i];
			XPUSHs(sv_2mortal( newSVpvn((char*) t.tile, t.dx * t.dy * BYTES_PER_PIXEL) ));
			free_tile( t );
		}
		free( tile_list );
	}




SV*
newTile( dx, dy )
	int     dx
	int     dy
	CODE:
	{
		map_tile tNew;

		if( VERBOSE >= 1 ){
			printf( "--- newTile ---\n" );  /* _DEBUG_ */
			printf( "dx <%d>\n", dx );      /* _DEBUG_ */
			printf( "dy <%d>\n", dy );      /* _DEBUG_ */
		}

		tNew = new_tile( dx, dy );
		RETVAL = newSVpvn( (char*) tNew.tile, tNew.dx * tNew.dy * BYTES_PER_PIXEL );
		free_tile( tNew );
	}
	OUTPUT:
	RETVAL


void
copySubtile( offXdst,offYdst, offXsrc,offYsrc, dxSub,dySub, dxDst,dyDst,tDst, dxSrc,dySrc,tSrc )
	int     offXdst
	int     offYdst
	int     offXsrc
	int     offYsrc
	int     dxSub
	int     dySub
	int     dxDst
	int     dyDst
	char *  tDst
	int     dxSrc
	int     dySrc
	char *  tSrc
	PPCODE:
	{
		if( VERBOSE >= 1 ){
			printf( "--- copySubtile ---\n" );    /* _DEBUG_ */
			printf( "offXdst <%d>\n", offXdst );  /* _DEBUG_ */
			printf( "offYdst <%d>\n", offYdst );  /* _DEBUG_ */
			printf( "offXsrc <%d>\n", offXsrc );  /* _DEBUG_ */
			printf( "offYsrc <%d>\n", offYsrc );  /* _DEBUG_ */
			printf( "dxSub <%d>\n", dxSub );      /* _DEBUG_ */
			printf( "dySub <%d>\n", dySub );      /* _DEBUG_ */
			printf( "tDst <%p>\n", tDst );        /* _DEBUG_ */
			printf( "tSrc <%p>\n", tSrc );        /* _DEBUG_ */
		}
//		void copy_subtile( int offXdst, int offYdst, int offXsrc, int offYsrc, int dxSub, int dySub, map_tile tDst, map_tile tSrc ){
		copy_subtile( offXdst, offYdst, offXsrc, offYsrc, dxSub, dySub, data_tile(dxDst,dyDst, (TILE) tDst), data_tile(dxSrc,dySrc, (TILE) tSrc) );
	}



void
initColorMap( cmStruct )
	SV      * cmStruct
	PPCODE:
	{
		int i, r, g, b;
		map_tile tColorMap;
		SV **sVal;
		AV *aColorList;
		AV *aColor;

		tColorMap = new_tile( DX_COLORMAP, DY_COLORMAP );

		if( (!SvROK(cmStruct)) || (SvTYPE(SvRV(cmStruct)) != SVt_PVAV) ){
			croak( "initColorMap: invalid colorMap parameter (not an arrayref)" );
		}
		aColorList = (AV*) SvRV(cmStruct);

		for( i = 0; i < DX_COLORMAP; ++i ){

			sVal = av_fetch( aColorList, i, 0 );
			if( (sVal == NULL) || (!SvROK(*sVal)) || (SvTYPE(SvRV(*sVal)) != SVt_PVAV) ){
				croak( "initColorMap: invalid color value for index '%d' (not an array ref)", i );
			}
			aColor = (AV*) SvRV(*sVal);

			r = SvIV( *(av_fetch(aColor,0,0)) );
			g = SvIV( *(av_fetch(aColor,1,0)) );
			b = SvIV( *(av_fetch(aColor,2,0)) );

			set_pixel( tColorMap, i,0, r );
			set_pixel( tColorMap, i,1, g );
			set_pixel( tColorMap, i,2, b );
		}
		init_global_color_map( tColorMap );
	}



void
applyDrawFunction( func, dxC, dyC, tCanvas, x0, y0, dxP, dyP, tPaint, mult, strR=NULL, tPrev=NULL, flags=0, ddx=0, ddy=0 )
	int     func
	int     dxC
	int     dyC
	char *  tCanvas
	int     x0
	int     y0
	int     dxP
	int     dyP
	char *  tPaint
	double  mult
	char *  tPrev
    int     flags
	int     ddx
	int     ddy
	char *  strR
	PPCODE:
	{
		int minMax = 0;
//		printf( "dxP <%d>  dyP <%d>\n", dxP,dyP );  /* _DEBUG_ */
//		printf( "func = %d\n", func );  /* -- _DEBUG_ */
		switch( func ){
		case FUNC_ELEV_MAX:
			apply_elevation_max( data_tile(dxC,dyC,(TILE) tCanvas), x0,y0, data_tile(dxP,dyP,(TILE) tPaint), mult, data_tile(dxC,dyC,(TILE) tPrev), flags );
			break;
		case FUNC_ELEV_ADD:
			apply_elevation_add( data_tile(dxC,dyC,(TILE) tCanvas), x0,y0, data_tile(dxP,dyP,(TILE) tPaint), mult, data_tile(dxC,dyC,(TILE) tPrev), flags );
			break;
		case FUNC_ELEV_SUBTRACT:
			apply_elevation_subtract( data_tile(dxC,dyC,(TILE) tCanvas), x0,y0, data_tile(dxP,dyP,(TILE) tPaint), mult, data_tile(dxC,dyC,(TILE) tPrev), flags );
			break;
		case FUNC_ELEV_SUBTRACT_CENTER:
			apply_elevation_subtract_center( data_tile(dxC,dyC,(TILE) tCanvas), x0,y0, data_tile(dxP,dyP,(TILE) tPaint), mult, data_tile(dxC,dyC,(TILE) tPrev), flags );
			break;
		case FUNC_ELEV_ADD_PREV:
			apply_elevation_add_prev( data_tile(dxC,dyC,(TILE) tCanvas), x0,y0, data_tile(dxP,dyP,(TILE) tPaint), mult, data_tile(dxP,dyP,(TILE) tPrev), ddx, ddy );
			break;
		case FUNC_ELEV_MIN_MAX:
			apply_elevation_min_max( data_tile(dxC,dyC,(TILE) tCanvas), x0,y0, data_tile(dxP,dyP,(TILE) tPaint), mult, &minMax );
			break;
		case FUNC_ELEV_MIN:
			apply_elevation_min( data_tile(dxC,dyC,(TILE) tCanvas), x0,y0, data_tile(dxP,dyP,(TILE) tPaint), mult, data_tile(dxP,dyP,(TILE) tPrev), flags );
			break;
		default:
			printf( "applyDrawFunction: unknown function code %d\n", func );
			break;
		}
		if( strR != NULL ){
			get_color_values( strR, data_tile(dxC,dyC,(TILE) tCanvas), x0, y0, dxP, dyP, get_global_color_map() );
		}
	}


void
getElevationColors( dxC, dyC, tCanvas, x0, y0, dxP, dyP, strR=NULL )
	int     dxC
	int     dyC
	char *  tCanvas
	int     x0
	int     y0
	int     dxP
	int     dyP
	char *  strR
	PPCODE:
	{
//		printf( "dxP <%d>  dyP <%d>\n", dxP,dyP );  /* _DEBUG_ */
		get_color_values( strR, data_tile(dxC,dyC,(TILE) tCanvas), x0, y0, dxP, dyP, get_global_color_map() );
	}





int
getPixel( dx, dy, tSrc, x, y )
	int     dx
	int     dy
	char *		tSrc
	int     x
	int     y
	CODE:
	{
		RETVAL = get_pixel( data_tile(dx,dy,(TILE) tSrc), x, y );
	}
	OUTPUT:
	RETVAL


void
setPixel( dx, dy, tSrc, x, y, val )
	int     dx
	int     dy
	char *		tSrc
	int     x
	int     y
	int     val
	PPCODE:
	{
		set_pixel( data_tile(dx,dy,(TILE) tSrc), x, y, val );
	}


void
setPixel_max( dx, dy, tSrc, x, y, val, valMax )
	int     dx
	int     dy
	char *		tSrc
	int     x
	int     y
	int     val
	int     valMax
	PPCODE:
	{
		set_pixel_max( data_tile(dx,dy,(TILE) tSrc), x, y, val, valMax );
	}





