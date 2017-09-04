

#define BYTES_PER_PIXEL  2
#define NO_ELEV_VALUE   -30001
#define VERBOSE          0
#define PRINT_LINE       228

#define DX_COLORMAP      40001
#define DY_COLORMAP      3
#define COLORMAP_ADD     20000

#define FUNC_ELEV_MAX         101
#define FUNC_ELEV_ADD         102
#define FUNC_ELEV_ADD_PREV    103
#define FUNC_ELEV_MIN_MAX     104
#define FUNC_ELEV_SUBTRACT    105
#define FUNC_ELEV_SUBTRACT_CENTER    106
#define FUNC_ELEV_MIN_SHIFT   107
#define FUNC_ELEV_MAX_SHIFT   108

#define FLAG_LAND_AREA        1



typedef signed short *TILE;
typedef signed short *LINE;
typedef signed short VALUE;

typedef struct {
	int dx;
	int dy;
	TILE tile;
} map_tile;

typedef struct {
	int d;
	LINE line;
} map_line;




/*
map_tile convert_tile( char *method,
	map_tile t00, map_tile t01, map_tile t02, map_tile t10, map_tile t11, map_tile t12, map_tile t20, map_tile t21, map_tile t22 );
*/

map_tile convert_tile( char *method, map_tile tSrc, char *opt );

map_tile combine_complete_tileset(
	map_tile t00, map_tile t01, map_tile t02, map_tile t10, map_tile t11, map_tile t12, map_tile t20, map_tile t21, map_tile t22 );

map_tile combine_tiles( int offsetX, int offsetY, int dxTotal, int dyTotal,
	map_tile t00, map_tile t01, map_tile t02, map_tile t10, map_tile t11, map_tile t12, map_tile t20, map_tile t21, map_tile t22 );

map_tile surround_central_tile( int margin,
	map_tile t00, map_tile t01, map_tile t02, map_tile t10, map_tile t11, map_tile t12, map_tile t20, map_tile t21, map_tile t22 );

void copy_subtile( int offXdst, int offYdst, int offXsrc, int offYsrc, int dxSub, int dySub, map_tile tDst, map_tile tSrc );

map_tile extract_subtile( int offsetX, int offsetY, int dxSub, int dySub, map_tile tSrc );
map_tile extract_central_tile( int margin, map_tile tSrc );

map_line extract_row( map_tile tSrc, int y );
map_line extract_col( map_tile tSrc, int x );
void set_row( map_tile tDst, int y, map_line ln );
void set_col( map_tile tDst, int x, map_line ln );

int verify_contour_lines( map_tile tCnr, map_tile tElev );
void set_sea_level( map_tile tElev, VALUE val );

map_tile *split_tile( map_tile tSrc, int numX, int numY );
map_tile inflate_tile( map_tile tSrc, int numX, int numY );

int pixel_offset( map_tile t, int x, int y );
void set_pixel( map_tile t, int x, int y, VALUE val );
void set_pixel_max( map_tile t, int x, int y, VALUE val, VALUE maxVal );
VALUE get_pixel( map_tile t, int x, int y );

map_tile data_tile( int dx, int dy, TILE tData );
map_tile new_tile( int dx, int dy );
map_line new_line( int d );
void free_tile( map_tile t );
void free_line( map_line ln );

void *mallocOrDie( int amount );
void errorExit( char *errTxt );

void print_tile( char *text, map_tile t );
void print_line( char *text, map_line ln );


map_tile convert_tile_weighted_linear( map_tile tComb );
map_tile convert_tile_average_linear( map_tile tComb );
map_tile convert_tile_gradient( map_tile tComb );

map_tile convert_tile_radius( map_tile tComb, int radius );
map_tile make_line_matrix( int radius );
map_line make_line_points( int radius, int x0, int y0, map_line *ln );
void print_line_matrix( map_tile lineMatrix, int radius );
VALUE radius_value( map_tile tComb, int radius, map_tile lineMatrix, int x, int y );
int reachable( int y0, int x0, int y, int x, map_tile tComb, map_tile lineMatrix );
double point_distance( double x0, double y0, double x, double y );

void interpolate_linear( map_line ln, int verbose, map_line *lnGrad );


void map_tile_shift_values( map_tile tElev, int dx, int dy, VALUE vEmpty );

void apply_elevation_max( map_tile tCanvas, int x0, int y0, map_tile tPaint, double mult, map_tile tPrev, int flags );
void apply_elevation_add( map_tile tCanvas, int x0, int y0, map_tile tPaint, double mult, map_tile tPrev, int flags );
void apply_elevation_subtract( map_tile tCanvas, int x0, int y0, map_tile tPaint, double mult, map_tile tPrev, int flags );
void apply_elevation_subtract_center( map_tile tCanvas, int x0, int y0, map_tile tPaint, double mult, map_tile tPrev, int flags );
void apply_elevation_min_shift( map_tile tCanvas, int x0, int y0, map_tile tPaint, double min, map_tile tPrev, int flags );
void apply_elevation_max_shift( map_tile tCanvas, int x0, int y0, map_tile tPaint, double min, map_tile tPrev, int flags );

void apply_elevation_min_max( map_tile tCanvas, int x0, int y0, map_tile tPaint, double mult, int *minMax );
void apply_elevation_add_prev( map_tile tCanvas, int x0, int y0, map_tile tPaint, double mult, map_tile tPrev, int dx, int dy );

char *make_scanline_str( int dx, int dy );
void init_global_color_map( map_tile tColorMap );
map_tile *get_global_color_map();
void get_color_values( char *dst, map_tile tCanvas, int x0, int y0, int dx, int dy, map_tile *tColorMap );
void relief_color_transform( int *pR, int *pB, int *pG, map_tile tCanvas, int x, int y );

int opt_int_value( char *opt, char *name, int defaultVal );





