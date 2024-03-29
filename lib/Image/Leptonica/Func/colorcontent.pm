package Image::Leptonica::Func::colorcontent;
$Image::Leptonica::Func::colorcontent::VERSION = '0.04';

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Image::Leptonica::Func::colorcontent

=head1 VERSION

version 0.04

=head1 C<colorcontent.c>

  colorcontent.c

      Builds an image of the color content, on a per-pixel basis,
      as a measure of the amount of divergence of each color
      component (R,G,B) from gray.
         l_int32    pixColorContent()

      Finds the 'amount' of color in an image, on a per-pixel basis,
      as a measure of the difference of the pixel color from gray.
         PIX       *pixColorMagnitude()

      Generates a mask over pixels that have sufficient color and
      are not too close to gray pixels.
         PIX       *pixMaskOverColorPixels()

      Finds the fraction of pixels with "color" that are not close to black
         l_int32    pixColorFraction()

      Finds the number of perceptually significant gray intensities
      in a grayscale image.
         l_int32    pixNumSignificantGrayColors()

      Identifies images where color quantization will cause posterization
      due to the existence of many colors in low-gradient regions.
         l_int32    pixColorsForQuantization()

      Finds the number of unique colors in an image
         l_int32    pixNumColors()

      Find the most "populated" colors in the image (and quantize)
         l_int32    pixGetMostPopulatedColors()
         PIX       *pixSimpleColorQuantize()

      Constructs a color histogram based on rgb indices
         NUMA      *pixGetRGBHistogram()
         l_int32    makeRGBIndexTables()
         l_int32    getRGBFromIndex()

  Color is tricky.  If we consider gray (r = g = b) to have no color
  content, how should we define the color content in each component
  of an arbitrary pixel, as well as the overall color magnitude?

  I can think of three ways to define the color content in each component:

  (1) Linear.  For each component, take the difference from the average
      of all three.
  (2) Linear.  For each component, take the difference from the average
      of the other two.
  (3) Nonlinear.  For each component, take the minimum of the differences
      from the other two.

  How might one choose from among these?  Consider two different situations:
  (a) r = g = 0, b = 255            {255}   /255/
  (b) r = 0, g = 127, b = 255       {191}   /128/
  How much g is in each of these?  The three methods above give:
  (a)  1: 85   2: 127   3: 0        [85]
  (b)  1: 0    2: 0     3: 127      [0]
  How much b is in each of these?
  (a)  1: 170  2: 255   3: 255      [255]
  (b)  1: 127  2: 191   3: 127      [191]
  The number I'd "like" to give is in [].  (Please don't ask why, it's
  just a feeling.

  So my preferences seem to be somewhere between (1) and (2).
  (3) is just too "decisive!"  Let's pick (2).

  We also allow compensation for white imbalance.  For each
  component, we do a linear TRC (gamma = 1.0), where the black
  point remains at 0 and the white point is given by the input
  parameter.  This is equivalent to doing a global remapping,
  as with pixGlobalNormRGB(), followed by color content (or magnitude)
  computation, but without the overhead of first creating the
  white point normalized image.

  Another useful property is the overall color magnitude in the pixel.
  For this there are again several choices, such as:
      (a) rms deviation from the mean
      (b) the average L1 deviation from the mean
      (c) the maximum (over components) of one of the color
          content measures given above.

  For now, we will choose two of the methods in (c):
     L_MAX_DIFF_FROM_AVERAGE_2
        Define the color magnitude as the maximum over components
        of the difference between the component value and the
        average of the other two.  It is easy to show that
        this is equivalent to selecting the two component values
        that are closest to each other, averaging them, and
        using the distance from that average to the third component.
        For (a) and (b) above, this value is in {..}.
    L_MAX_MIN_DIFF_FROM_2
        Define the color magnitude as the maximum over components
        of the minimum difference between the component value and the
        other two values.  It is easy to show that this is equivalent
        to selecting the intermediate value of the three differences
        between the three components.  For (a) and (b) above,
        this value is in /../.

=head1 FUNCTIONS

=head2 getRGBFromIndex

l_int32 getRGBFromIndex ( l_uint32 index, l_int32 sigbits, l_int32 *prval, l_int32 *pgval, l_int32 *pbval )

  getRGBFromIndex()

      Input:  index (rgbindex)
              sigbits (2-6, significant bits retained in the quantizer
                       for each component of the input image)
              &rval, &gval, &bval (<return> rgb values)
      Return: 0 if OK, 1 on error

  Notes:
      (1) The @index is expressed in bits, based on the the
          @sigbits of the r, g and b components, as
             r7 r6 ... g7 g6 ... b7 b6 ...
      (2) The computed rgb values are in the center of the quantized cube.
          The extra bit that is OR'd accomplishes this.

=head2 makeRGBIndexTables

l_int32 makeRGBIndexTables ( l_uint32 **prtab, l_uint32 **pgtab, l_uint32 **pbtab, l_int32 sigbits )

  makeRGBIndexTables()

      Input:  &rtab, &gtab, &btab (<return> 256-entry index tables)
              sigbits (2-6, significant bits retained in the quantizer
                       for each component of the input image)
      Return: 0 if OK, 1 on error

  Notes:
      (1) These tables are used to map from rgb sample values to
          an rgb index, using
             rgbindex = rtab[rval] | gtab[gval] | btab[bval]
          where, e.g., if sigbits = 3, the index is a 9 bit integer:
             r7 r6 r5 g7 g6 g5 b7 b6 b5

=head2 pixColorContent

l_int32 pixColorContent ( PIX *pixs, l_int32 rwhite, l_int32 gwhite, l_int32 bwhite, l_int32 mingray, PIX **ppixr, PIX **ppixg, PIX **ppixb )

  pixColorContent()

      Input:  pixs  (32 bpp rgb or 8 bpp colormapped)
              rwhite, gwhite, bwhite (color value associated with white point)
              mingray (min gray value for which color is measured)
              &pixr (<optional return> 8 bpp red 'content')
              &pixg (<optional return> 8 bpp green 'content')
              &pixb (<optional return> 8 bpp blue 'content')
      Return: 0 if OK, 1 on error

  Notes:
      (1) This returns the color content in each component, which is
          a measure of the deviation from gray, and is defined
          as the difference between the component and the average of
          the other two components.  See the discussion at the
          top of this file.
      (2) The three numbers (rwhite, gwhite and bwhite) can be thought
          of as the values in the image corresponding to white.
          They are used to compensate for an unbalanced color white point.
          They must either be all 0 or all non-zero.  To turn this
          off, set them all to 0.
      (3) If the maximum component after white point correction,
          max(r,g,b), is less than mingray, all color components
          for that pixel are set to zero.
          Use mingray = 0 to turn off this filtering of dark pixels.
      (4) Therefore, use 0 for all four input parameters if the color
          magnitude is to be calculated without either white balance
          correction or dark filtering.

=head2 pixColorFraction

l_int32 pixColorFraction ( PIX *pixs, l_int32 darkthresh, l_int32 lightthresh, l_int32 diffthresh, l_int32 factor, l_float32 *ppixfract, l_float32 *pcolorfract )

  pixColorFraction()

      Input:  pixs  (32 bpp rgb)
              darkthresh (threshold near black; if the lightest component
                          is below this, the pixel is not considered in
                          the statistics; typ. 20)
              lightthresh (threshold near white; if the darkest component
                           is above this, the pixel is not considered in
                           the statistics; typ. 244)
              diffthresh (thresh for the maximum difference between
                          component value; below this the pixel is not
                          considered to have sufficient color)
              factor (subsampling factor)
              &pixfract (<return> fraction of pixels in intermediate
                         brightness range that were considered
                         for color content)
              &colorfract (<return> fraction of pixels that meet the
                           criterion for sufficient color; 0.0 on error)
      Return: 0 if OK, 1 on error

  Notes:
      (1) This function is asking the question: to what extent does the
          image appear to have color?   The amount of color a pixel
          appears to have depends on both the deviation of the
          individual components from their average and on the average
          intensity itself.  For example, the color will be much more
          obvious with a small deviation from white than the same
          deviation from black.
      (2) Any pixel that meets these three tests is considered a
          colorful pixel:
            (a) the lightest component must equal or exceed @darkthresh
            (b) the darkest component must not exceed @lightthresh
            (c) the max difference between components must equal or
                exceed @diffthresh.
      (3) The dark pixels are removed from consideration because
          they don't appear to have color.
      (4) The very lightest pixels are removed because if an image
          has a lot of "white", the color fraction will be artificially
          low, even if all the other pixels are colorful.
      (5) If pixfract is very small, there are few pixels that are neither
          black nor white.  If colorfract is very small, the pixels
          that are neither black nor white have very little color
          content.  The product 'pixfract * colorfract' gives the
          fraction of pixels with significant color content.
      (6) One use of this function is as a preprocessing step for median
          cut quantization (colorquant2.c), which does a very poor job
          splitting the color space into rectangular volume elements when
          all the pixels are near the diagonal of the color cube.  For
          octree quantization of an image with only gray values, the
          2^(level) octcubes on the diagonal are the only ones
          that can be occupied.

=head2 pixColorMagnitude

PIX * pixColorMagnitude ( PIX *pixs, l_int32 rwhite, l_int32 gwhite, l_int32 bwhite, l_int32 type )

  pixColorMagnitude()

      Input:  pixs  (32 bpp rgb or 8 bpp colormapped)
              rwhite, gwhite, bwhite (color value associated with white point)
              type (chooses the method for calculating the color magnitude:
                    L_MAX_DIFF_FROM_AVERAGE_2, L_MAX_MIN_DIFF_FROM_2,
                    L_MAX_DIFF)
      Return: pixd (8 bpp, amount of color in each source pixel),
                    or NULL on error

  Notes:
      (1) For an RGB image, a gray pixel is one where all three components
          are equal.  We define the amount of color in an RGB pixel by
          considering the absolute value of the differences between the
          three color components.  Consider the two largest
          of these differences.  The pixel component in common to these
          two differences is the color farthest from the other two.
          The color magnitude in an RGB pixel can be taken as:
              * the average of these two differences; i.e., the
                average distance from the two components that are
                nearest to each other to the third component, or
              * the minimum value of these two differences; i.e., the
                maximum over all components of the minimum distance
                from that component to the other two components.
          Even more simply, the color magnitude can be taken as
              * the maximum difference between component values
      (2) As an example, suppose that R and G are the closest in
          magnitude.  Then the color is determined as:
              * the average distance of B from these two; namely,
                (|B - R| + |B - G|) / 2, which can also be found
                from |B - (R + G) / 2|, or
              * the minimum distance of B from these two; namely,
                min(|B - R|, |B - G|).
              * the max(|B - R|, |B - G|)
      (3) The three numbers (rwhite, gwhite and bwhite) can be thought
          of as the values in the image corresponding to white.
          They are used to compensate for an unbalanced color white point.
          They must either be all 0 or all non-zero.  To turn this
          off, set them all to 0.
      (4) We allow the following methods for choosing the color
          magnitude from the three components:
              * L_MAX_DIFF_FROM_AVERAGE_2
              * L_MAX_MIN_DIFF_FROM_2
              * L_MAX_DIFF
          These are described above in (1) and (2), as well as at
          the top of this file.

=head2 pixColorsForQuantization

l_int32 pixColorsForQuantization ( PIX *pixs, l_int32 thresh, l_int32 *pncolors, l_int32 *piscolor, l_int32 debug )

  pixColorsForQuantization()
      Input:  pixs (8 bpp gray or 32 bpp rgb; with or without colormap)
              thresh (binary threshold on edge gradient; 0 for default)
              &ncolors (<return> the number of colors found)
              &iscolor (<optional return> 1 if significant color is found;
                        0 otherwise.  If pixs is 8 bpp, and does not have
                        a colormap with color entries, this is 0)
              debug (1 to output masked image that is tested for colors;
                     0 otherwise)
      Return: 0 if OK, 1 on error.

  Notes:
      (1) This function finds a measure of the number of colors that are
          found in low-gradient regions of an image.  By its
          magnitude relative to some threshold (not specified in
          this function), it gives a good indication of whether
          quantization will generate posterization.   This number
          is larger for images with regions of slowly varying
          intensity (if 8 bpp) or color (if rgb). Such images, if
          quantized, may require dithering to avoid posterization,
          and lossless compression is then expected to be poor.
      (2) If pixs has a colormap, the number of colors returned is
          the number in the colormap.
      (3) It is recommended that document images be reduced to a width
          of 800 pixels before applying this function.  Then it can
          be expected that color detection will be fairly accurate
          and the number of colors will reflect both the content and
          the type of compression to be used.  For less than 15 colors,
          there is unlikely to be a halftone image, and lossless
          quantization should give both a good visual result and
          better compression.
      (4) When using the default threshold on the gradient (15),
          images (both gray and rgb) where ncolors is greater than
          about 15 will compress poorly with either lossless
          compression or dithered quantization, and they may be
          posterized with non-dithered quantization.
      (5) For grayscale images, or images without significant color,
          this returns the number of significant gray levels in
          the low-gradient regions.  The actual number of gray levels
          can be large due to jpeg compression noise in the background.
      (6) Similarly, for color images, the actual number of different
          (r,g,b) colors in the low-gradient regions (rather than the
          number of occupied level 4 octcubes) can be quite large, e.g.,
          due to jpeg compression noise, even for regions that appear
          to be of a single color.  By quantizing to level 4 octcubes,
          most of these superfluous colors are removed from the counting.
      (7) The image is tested for color.  If there is very little color,
          it is thresholded to gray and the number of gray levels in
          the low gradient regions is found.  If the image has color,
          the number of occupied level 4 octcubes is found.
      (8) The number of colors in the low-gradient regions increases
          monotonically with the threshold @thresh on the edge gradient.
      (9) Background: grayscale and color quantization is often useful
          to achieve highly compressed images with little visible
          distortion.  However, gray or color washes (regions of
          low gradient) can defeat this approach to high compression.
          How can one determine if an image is expected to compress
          well using gray or color quantization?  We use the fact that
            * gray washes, when quantized with less than 50 intensities,
              have posterization (visible boundaries between regions
              of uniform 'color') and poor lossless compression
            * color washes, when quantized with level 4 octcubes,
              typically result in both posterization and the occupancy
              of many level 4 octcubes.
          Images can have colors either intrinsically or as jpeg
          compression artifacts.  This function reduces but does not
          completely eliminate measurement of jpeg quantization noise
          in the white background of grayscale or color images.

=head2 pixGetMostPopulatedColors

l_int32 pixGetMostPopulatedColors ( PIX *pixs, l_int32 sigbits, l_int32 factor, l_int32 ncolors, l_uint32 **parray, PIXCMAP **pcmap )

  pixGetMostPopulatedColors()
      Input:  pixs (32 bpp rgb)
              sigbits (2-6, significant bits retained in the quantizer
                       for each component of the input image)
              factor (subsampling factor; use 1 for no subsampling)
              ncolors (the number of most populated colors to select)
              &array (<optional return> array of colors, each as 0xrrggbb00)
              &cmap (<optional return> colormap of the colors)
      Return: 0 if OK, 1 on error

  Notes:
      (1) This finds the @ncolors most populated cubes in rgb colorspace,
          where the cube size depends on @sigbits as
               cube side = (256 >> sigbits)
      (2) The rgb color components are found at the center of the cube.
      (3) The output array of colors can be displayed using
               pixDisplayColorArray(array, ncolors, ...);

=head2 pixGetRGBHistogram

NUMA * pixGetRGBHistogram ( PIX *pixs, l_int32 sigbits, l_int32 factor )

  pixGetRGBHistogram()
      Input:  pixs (32 bpp rgb)
              sigbits (2-6, significant bits retained in the quantizer
                       for each component of the input image)
              factor (subsampling factor; use 1 for no subsampling)
      Return: numa (histogram of colors, indexed by RGB
                    components), or null on error

  Notes:
      (1) This uses a simple, fast method of indexing into an rgb image.
      (2) The output is a 1D histogram of count vs. rgb-index, which
          uses red sigbits as the most significant and blue as the least.
      (3) This function produces the same result as pixMedianCutHisto().

=head2 pixMaskOverColorPixels

PIX * pixMaskOverColorPixels ( PIX *pixs, l_int32 threshdiff, l_int32 mindist )

  pixMaskOverColorPixels()

      Input:  pixs  (32 bpp rgb or 8 bpp colormapped)
              threshdiff (threshold for minimum of the max difference
                          between components)
              mindist (minimum allowed distance from nearest non-color pixel)
      Return: pixd (1 bpp, mask over color pixels), or null on error

  Notes:
      (1) The generated mask identifies each pixel as either color or
          non-color.  For a pixel to be color, it must satisfy two
          constraints:
            (a) The max difference between the r,g and b components must
                equal or exceed a threshold @threshdiff.
            (b) It must be at least @mindist (in an 8-connected way)
                from the nearest non-color pixel.
      (2) The distance constraint (b) is only applied if @mindist > 1.
          For example, if @mindist == 2, the color pixels identified
          by (a) are eroded by a 3x3 Sel.  In general, the Sel size
          for erosion is 2 * (@mindist - 1) + 1.
          Why have this constraint?  In scanned images that are
          essentially gray, color artifacts are typically introduced
          in transition regions near sharp edges that go from dark
          to light, so this allows these transition regions to be removed.

=head2 pixNumColors

l_int32 pixNumColors ( PIX *pixs, l_int32 factor, l_int32 *pncolors )

  pixNumColors()
      Input:  pixs (2, 4, 8, 32 bpp)
              factor (subsampling factor; integer)
              &ncolors (<return> the number of colors found, or 0 if
                        there are more than 256)
      Return: 0 if OK, 1 on error.

  Notes:
      (1) This returns the actual number of colors found in the image,
          even if there is a colormap.  If @factor == 1 and the
          number of colors differs from the number of entries
          in the colormap, a warning is issued.
      (2) Use @factor == 1 to find the actual number of colors.
          Use @factor > 1 to quickly find the approximate number of colors.
      (3) For d = 2, 4 or 8 bpp grayscale, this returns the number
          of colors found in the image in 'ncolors'.
      (4) For d = 32 bpp (rgb), if the number of colors is
          greater than 256, this returns 0 in 'ncolors'.

=head2 pixNumSignificantGrayColors

l_int32 pixNumSignificantGrayColors ( PIX *pixs, l_int32 darkthresh, l_int32 lightthresh, l_float32 minfract, l_int32 factor, l_int32 *pncolors )

  pixNumSignificantGrayColors()

      Input:  pixs  (8 bpp gray)
              darkthresh (dark threshold for minimum intensity to be
                          considered; typ. 20)
              lightthresh (threshold near white, for maximum intensity
                           to be considered; typ. 236)
              minfract (minimum fraction of all pixels to include a level
                        as significant; typ. 0.0001; should be < 0.001)
              factor (subsample factor; integer >= 1)
              &ncolors (<return> number of significant colors; 0 on error)
      Return: 0 if OK, 1 on error

  Notes:
      (1) This function is asking the question: how many perceptually
          significant gray color levels is in this pix?
          A color level must meet 3 criteria to be significant:
            - it can't be too close to black
            - it can't be too close to white
            - it must have at least some minimum fractional population
      (2) Use -1 for default values for darkthresh, lightthresh and minfract.
      (3) Choose default of darkthresh = 20, because variations in very
          dark pixels are not visually significant.
      (4) Choose default of lightthresh = 236, because document images
          that have been jpeg'd typically have near-white pixels in the
          8x8 jpeg blocks, and these should not be counted.  It is desirable
          to obtain a clean image by quantizing this noise away.

=head2 pixSimpleColorQuantize

PIX * pixSimpleColorQuantize ( PIX *pixs, l_int32 sigbits, l_int32 factor, l_int32 ncolors )

  pixSimpleColorQuantize()
      Input:  pixs (32 bpp rgb)
              sigbits (2-4, significant bits retained in the quantizer
                       for each component of the input image)
              factor (subsampling factor; use 1 for no subsampling)
              ncolors (the number of most populated colors to select)
      Return: pixd (8 bpp cmapped) or NULL on error

  Notes:
      (1) If you want to do color quantization for real, use octcube
          or modified median cut.  This function shows that it is
          easy to make a simple quantizer based solely on the population
          in cells of a given size in rgb color space.
      (2) The @ncolors most populated cells at the @sigbits level form
          the colormap for quantizing, and this uses octcube indexing
          under the covers to assign each pixel to the nearest color.
      (3) @sigbits is restricted to 2, 3 and 4.  At the low end, the
          color discrimination is very crude; at the upper end, a set of
          similar colors can dominate the result.  Interesting results
          are generally found for @sigbits = 3 and ncolors ~ 20.
      (4) See also pixColorSegment() for a method of quantizing the
          colors to generate regions of similar color.

=head1 AUTHOR

Zakariyya Mughal <zmughal@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Zakariyya Mughal.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
