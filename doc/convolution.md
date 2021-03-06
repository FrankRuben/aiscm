# Array convolutions
## One-dimensional convolutions

One dimensional signals such as audio samples can be filtered using a 1D convolution.
Convolution can also be performed using composite values such as complex numbers.

```Scheme
@../tests/integration/convolution_1d.scm@
```

## Two-dimensional convolutions

Convolution can also be performed on 2D data.

```Scheme
@../tests/integration/convolution_2d.scm@
```

## Image processing

Here is the test input image for comparison.

![star-ferry.jpg](star-ferry.jpg "Test input image")

### Box filter

A simple filter for blurring an image is the box filter. Note that convolution is performed on a colour image.

```Scheme
@../tests/integration/box_filter.scm@
```

![box-filter.jpg](box-filter.jpg "Box blur filter")

### Sharpen

Image sharpening increases the difference between neighbouring pixels.

```Scheme
@../tests/integration/sharpen.scm@
```

![sharpen.jpg](sharpen.jpg "Sharpen")

### Gaussian blur

A Gaussian filter can be used to blur an image.

```Scheme
@../tests/integration/gauss_blur.scm@
```

![gauss-blur.jpg](gauss-blur.jpg "Gauss blur")

### Edge detection

Convolutions can be used for edge detection.

Here is an implementation of the Roberts cross edge detector.

```Scheme
@../tests/integration/roberts_cross.scm@
```

![roberts-cross.jpg](roberts-cross.jpg "Roberts cross edge detector")

Another popular edge detector is the Sobel operator.

```Scheme
@../tests/integration/sobel.scm@
```

![sobel.jpg](sobel.jpg "Sobel edges")

It is also possible to use a Gauss gradient filter to detect edges.

```Scheme
@../tests/integration/gauss_gradient.scm@
```

![gauss-gradient.jpg](gauss-gradient.jpg "Gauss gradient")

### Corner detection

The following example shows the Harris-Stephens corner and edge detector.

```Scheme
@../tests/integration/harris_stephens.scm@
```

![harris-stephens.jpg](harris-stephens.jpg "Harris-Stephens corners")

## Conway's Game of Life

Finally here is an implementation of Conway's Game of Life.

```Scheme
@../tests/integration/conway.scm@
```

## Erosion/Dilation

### Erosion

Erosion is a local operator taking the local minimum of an image:

```Scheme
@../tests/integration/erode.scm@
```

![eroded.jpg](eroded.jpg)

### Dilation

In a similar fashion dilation is the local maximum of an image:

```Scheme
@../tests/integration/dilate.scm@
```

![dilated.jpg](dilated.jpg)
