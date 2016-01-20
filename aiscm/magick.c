#include <libguile.h>
#include <magick/MagickCore.h>

#include <stdio.h>

SCM magick_read_image(SCM scm_file_name)
{
  SCM retval = SCM_UNDEFINED;
  const char *file_name = scm_to_locale_string(scm_file_name);
  ExceptionInfo *exception_info = AcquireExceptionInfo();
  ImageInfo *image_info = CloneImageInfo((ImageInfo *)NULL);
  CopyMagickString(image_info->filename, file_name, MaxTextExtent);
  Image *images = ReadImage(image_info, exception_info);
  if (exception_info->severity < ErrorException) {
    CatchException(exception_info);
    Image *image = RemoveFirstImageFromList(&images);
    const char *format = "BGRA";
    int width = image->columns;
    int height = image->rows;
    int size = width * height * 4;
    void *buf = scm_gc_malloc_pointerless(size, "aiscm magick frame");
    ExportImagePixels(image, 0, 0, width, height, format, CharPixel, buf, exception_info);
    if (exception_info->severity < ErrorException)
      retval = scm_list_4(scm_from_locale_symbol(format),
                          scm_list_2(scm_from_int(width), scm_from_int(height)),
                          scm_from_pointer(buf, NULL),
                          scm_from_int(size));
    DestroyImage(image);
  };
  SCM scm_reason = exception_info->severity < ErrorException ?
    SCM_UNDEFINED : scm_from_locale_string(exception_info->reason);
  DestroyImageInfo(image_info);
  DestroyExceptionInfo(exception_info);
  if (scm_reason != SCM_UNDEFINED)
    scm_misc_error("magick_read_image", "~a", scm_list_1(scm_reason));
  return retval;
}

void init_magick(void)
{
  MagickCoreGenesis("libguile-magick", MagickTrue);
  scm_c_define_gsubr("magick-read-image", 1, 0, 0, magick_read_image);
}
