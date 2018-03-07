#include <tiffio.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

#define CopyField(tag, v) \
    if (TIFFGetField(base_fd, tag, &v)) TIFFSetField(output_fd, tag, v)
#define CopyField2(tag, c, v) \
    if (TIFFGetField(base_fd, tag, &c, &v)) TIFFSetField(output_fd, tag, c, v)


int main( int argc, char *argv[] ) {
  TIFF* base_fd = TIFFOpen(argv[1], "r");
  if ( ! base_fd ) {
    fprintf( stderr, "Can't open base %s\n", argv[1] );
    exit(1);
  }
    
  TIFF* imprint_fd = TIFFOpen(argv[2], "r");
  if ( ! imprint_fd ) {
    fprintf( stderr, "Can't open imprint %s\n", argv[2] );
    exit(1);
  }
  TIFF* output_fd = TIFFOpen(argv[3], "w");
  if ( ! output_fd ) {
    fprintf( stderr, "Can't open output %s\n", argv[3] );
    exit(1);
  }


  uint16 samplesperpixel, bitspersample = 1;
  TIFFGetField(base_fd, TIFFTAG_SAMPLESPERPIXEL, &samplesperpixel);
  if (samplesperpixel != 1) {
    fprintf(stderr, "%s: Not a b&w image.\n", argv[0]);
    return (-1);
  }
  TIFFGetField(base_fd, TIFFTAG_BITSPERSAMPLE, &bitspersample);
  if (bitspersample > 8) {
    fprintf(stderr,
        " %s: Sorry, only handle 8-bit samples. This one is (%d).\n", argv[0], bitspersample );
    return (-1);
  }

  float floatv;
  char *thing;
  uint32 longv;
  uint16 shortv;
  void *stuff;
  uint32  count;


  uint32  imagewidth;
  uint32  imagelength;

  CopyField(TIFFTAG_IMAGEWIDTH, imagewidth);
  TIFFGetField(base_fd, TIFFTAG_IMAGELENGTH, &imagelength);
  TIFFSetField(output_fd, TIFFTAG_IMAGELENGTH, imagelength);

  CopyField(TIFFTAG_BITSPERSAMPLE, shortv);
  CopyField(TIFFTAG_SAMPLESPERPIXEL, shortv);
  CopyField(TIFFTAG_PLANARCONFIG, shortv);
  CopyField(TIFFTAG_FILLORDER, shortv);
  CopyField(TIFFTAG_IMAGEDESCRIPTION, thing);
  CopyField(TIFFTAG_PHOTOMETRIC, shortv);
  CopyField(TIFFTAG_ORIENTATION, shortv);
  CopyField(TIFFTAG_XRESOLUTION, floatv);
  CopyField(TIFFTAG_YRESOLUTION, floatv);
  CopyField(TIFFTAG_RESOLUTIONUNIT, shortv);
  CopyField(TIFFTAG_ROWSPERSTRIP, longv);
  CopyField(TIFFTAG_COMPRESSION, shortv);

  CopyField(TIFFTAG_MAKE, thing);
  fprintf(stdout, "Value for Make (%s)", thing );
  fflush(stdout);
  CopyField(TIFFTAG_MODEL, thing);
  fprintf(stdout, "Value for Modle (%s)", thing );
  fflush(stdout);
  CopyField(TIFFTAG_SOFTWARE, thing);
  fprintf(stdout, "Value for Software (%s)", thing );
  fflush(stdout);
  CopyField(TIFFTAG_DATETIME, thing);
  CopyField2(TIFFTAG_PHOTOSHOP, count, stuff );
  CopyField2(34756, count,stuff);
    


register uint32 i, j;
  
  unsigned char * base_buf, *base_ptr;
  unsigned char * imprint_buf, *imprint_ptr;
  tmsize_t cc;
  uint8 *ptr;

  TIFFGetField( base_fd, TIFFTAG_IMAGELENGTH, &imagelength );
  int width = TIFFScanlineSize(base_fd);
  if ( ! width ) {
    fprintf( stderr, "zero width\n" );
    exit(1);
  } else {
    fprintf( stdout, "width is (%d)\n", width );
  }

  base_buf = _TIFFmalloc( width );
  imprint_buf = _TIFFmalloc( width );

  for ( int row = 0; row < imagelength; row++ ) {
      base_ptr = base_buf;
      imprint_ptr = imprint_buf;

      TIFFReadScanline(base_fd, base_buf, row, 0);
      TIFFReadScanline(imprint_fd, imprint_buf, row, 0);
      ptr = base_buf;
      for ( int pixel = 0; pixel < width; pixel += 1 ) {
        //fprintf(stdout, "pixel value: (%d) imprint (%d) result(%d)\n", *base_ptr, *imprint_ptr, ( *base_ptr | *imprint_ptr ) );
        *base_ptr = *base_ptr | *imprint_ptr;
        base_ptr++;
        imprint_ptr++;
      }
      TIFFWriteScanline( output_fd, base_buf, row, cc );
  }
  _TIFFfree(base_buf);
  _TIFFfree(imprint_buf);

  TIFFClose(output_fd);
  TIFFClose(imprint_fd);
  TIFFClose(base_fd);
  return 0;
}
