# Armv7
## libjpeg-turbo
1. 创建build文件夹 `mkdir build`
2. 进入文件夹 `cd build`
3. CMake
    a. 使用命令`SET(CMAKE_SYSTEM_PROCESSOR aarch64)`，在CMakeLists.txt的project之后设置CMAKE_SYSTEM_PROCESSOR
    b. 执行CMake命令
```SHELL
cmake -DCMAKE_INSTALL_PREFIX=/home/fmsh/libjpeg/lib/turbo-2.1.91 -ENABLE_SHARED=TRUE -DCMAKE_C_COMPILER=arm-linux-gnueabihf-gcc -DCMAKE_C_FLAGS="-fPIC -lm -lrt -mfloat-abi=hard -mfpu=neon-vfpv4 -funsafe-math-optimizations -O3" ..
```
*注意：不要在CMAKE_C_FLAGS里面加 **-mcpu=cortex-a7** 选项，-mcpu选项会和CMAKE_SYSTEM_PROCESSOR冲突，只设置CFLAGS中的mcpu但不设置CMake中的PROCESSOR会导致 `Illegal instruction` 错误*
1. make -j8
2. make install -j8
3. 应用程序Makefile

```SHELL
arm-linux-gnueabihf-gcc app.c -I/home/fmsh/libjpeg/lib/turbo-2.1.91/include -L/home/fmsh/libjpeg/lib/turbo-2.1.91/lib/ -lturbojpeg -o app
```

7. 需要把对应的动态库文件（.so）复制到目标板子的/lib/目录下

## libjpeg
libjpeg和libjpeg-turbo的区别在于：应用程序makefile中将引用的库从`-lturbojpeg`改为`-ljpeg`，需要复制的动态库也需要对应更换。

# Arm64/Windows
除了Armv7这类特殊架构，其他系统下编译不需要修改CMakeLists.txt，只需要指定`CMAKE_C_COMPILER`即可，至于`CMAKE_C_FLAGS`按需设置即可，在Armv7的CMake案例中除了-O3可以在其他平台一样使用外，其他flag均为Arm平台的特殊flag。

# 在内存中完成解压缩

## libjpeg

```C
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <syslog.h>
#include <sys/stat.h>
#include <string.h>

#include "jpeglib.h"
#include "time.h"

int width = 640;
int height = 512;
unsigned long jSize = 0;
unsigned char *jBuf = NULL;
unsigned char *image = NULL;
//
// Encodes a 256 Greyscale image to JPEG directly to a memory buffer
// libJEPG will malloc() the buffer so the caller must free() it when
// they are finished with it.
//
// image    - the input greyscale image, 1 byte is 1 pixel.
// width    - the width of the input image
// height   - the height of the input image
// quality  - target JPEG 'quality' factor (max 100)
// comment  - optional JPEG NULL-termoinated comment, pass NULL for no comment.
// jpegSize - output, the number of bytes in the output JPEG buffer
// jpegBuf  - output, a pointer to the output JPEG buffer, must call free() when finished with it.
//
double encode_jpeg_to_memory(unsigned char *image, int width, int height, int quality,
                             unsigned long *jpegSize, unsigned char **jpegBuf)
{
    // const char *comment;
    struct jpeg_compress_struct cinfo;
    struct jpeg_error_mgr jerr;
    JSAMPROW row_pointer[1];
    clock_t start, stop;
    int row_stride;
    cinfo.err = jpeg_std_error(&jerr);
    jpeg_create_compress(&cinfo);
    cinfo.image_width = width;
    cinfo.image_height = height;
    // Input is greyscale, 1 byte per pixel
    cinfo.input_components = 1;
    cinfo.in_color_space = JCS_GRAYSCALE;
    // cinfo.optimize_coding = TRUE;
    jpeg_set_defaults(&cinfo);
    jpeg_set_quality(&cinfo, quality, TRUE);
    // jpeg_set_linear_quality(&cinfo, scale, TRUE);
    // Tell libJpeg to encode to memory, this is the bit that's different!
    // Lib will alloc buffer.
    jpeg_mem_dest(&cinfo, jpegBuf, jpegSize);
    start = clock();
    jpeg_start_compress(&cinfo, TRUE);
    // 1 BPP
    row_stride = width;
    // Encode
    while (cinfo.next_scanline < cinfo.image_height)
    {
        row_pointer[0] = &image[cinfo.next_scanline * row_stride];
        jpeg_write_scanlines(&cinfo, row_pointer, 1);
    }
    jpeg_finish_compress(&cinfo);
    jpeg_destroy_compress(&cinfo);
    stop = clock();
    double duration = ((double)(stop - start)) / CLOCKS_PER_SEC;
    return duration;
}

void decode_jpeg_to_memory(int argc, char **argv)
{
    int rc, i, j;

    char *syslog_prefix = (char *)malloc(1024);
    sprintf(syslog_prefix, "%s", argv[0]);
    openlog(syslog_prefix, LOG_PERROR | LOG_PID, LOG_USER);

    //   SSS    EEEEEEE  TTTTTTT  U     U  PPPP
    // SS   SS  E           T     U     U  P   PP
    // S        E           T     U     U  P    PP
    // SS       E           T     U     U  P   PP
    //   SSS    EEEE        T     U     U  PPPP
    //      SS  E           T     U     U  P
    //       S  E           T     U     U  P
    // SS   SS  E           T      U   U   P
    //   SSS    EEEEEEE     T       UUU    P

    // Variables for the source jpg
    struct stat file_info;
    unsigned long jpg_size;
    unsigned char *jpg_buffer;

    // Variables for the decompressor itself
    struct jpeg_decompress_struct cinfo;
    struct jpeg_error_mgr jerr;

    // Variables for the output buffer, and how long each row is
    unsigned long bmp_size;
    unsigned char *bmp_buffer;
    int row_stride, width, height, pixel_size;

    // Load the jpeg data from a file into a memory buffer for
    // the purpose of this demonstration.
    // Normally, if it's a file, you'd use jpeg_stdio_src, but just
    // imagine that this was instead being downloaded from the Internet
    // or otherwise not coming from disk
    jpg_size = jSize;
    jpg_buffer = jBuf;

    //   SSS    TTTTTTT     A     RRRR     TTTTTTT
    // SS   SS     T       A A    R   RR      T
    // S           T      A   A   R    RR     T
    // SS          T     A     A  R   RR      T
    //   SSS       T     AAAAAAA  RRRR        T
    //      SS     T     A     A  R RR        T
    //       S     T     A     A  R   R       T
    // SS   SS     T     A     A  R    R      T
    //   SSS       T     A     A  R     R     T

    syslog(LOG_INFO, "Proc: Create Decompress struct");
    // Allocate a new decompress struct, with the default error handler.
    // The default error handler will exit() on pretty much any issue,
    // so it's likely you'll want to replace it or supplement it with
    // your own.
    cinfo.err = jpeg_std_error(&jerr);
    jpeg_create_decompress(&cinfo);

    syslog(LOG_INFO, "Proc: Set memory buffer as source");
    // Configure this decompressor to read its data from a memory
    // buffer starting at unsigned char *jpg_buffer, which is jpg_size
    // long, and which must contain a complete jpg already.
    //
    // If you need something fancier than this, you must write your
    // own data source manager, which shouldn't be too hard if you know
    // what it is you need it to do. See jpeg-8d/jdatasrc.c for the
    // implementation of the standard jpeg_mem_src and jpeg_stdio_src
    // managers as examples to work from.
    jpeg_mem_src(&cinfo, jpg_buffer, jpg_size);

    syslog(LOG_INFO, "Proc: Read the JPEG header");
    // Have the decompressor scan the jpeg header. This won't populate
    // the cinfo struct output fields, but will indicate if the
    // jpeg is valid.
    rc = jpeg_read_header(&cinfo, TRUE);

    if (rc != 1)
    {
        syslog(LOG_ERR, "File does not seem to be a normal JPEG");
        exit(EXIT_FAILURE);
    }

    syslog(LOG_INFO, "Proc: Initiate JPEG decompression");
    // By calling jpeg_start_decompress, you populate cinfo
    // and can then allocate your output bitmap buffers for
    // each scanline.
    jpeg_start_decompress(&cinfo);

    width = cinfo.output_width;
    height = cinfo.output_height;
    pixel_size = cinfo.output_components;

    syslog(LOG_INFO, "Proc: Image is %d by %d with %d components",
           width, height, pixel_size);

    bmp_size = width * height * pixel_size;
    bmp_buffer = (unsigned char *)malloc(bmp_size);

    // The row_stride is the total number of bytes it takes to store an
    // entire scanline (row).
    row_stride = width * pixel_size;

    syslog(LOG_INFO, "Proc: Start reading scanlines");
    //
    // Now that you have the decompressor entirely configured, it's time
    // to read out all of the scanlines of the jpeg.
    //
    // By default, scanlines will come out in RGBRGBRGB...  order,
    // but this can be changed by setting cinfo.out_color_space
    //
    // jpeg_read_scanlines takes an array of buffers, one for each scanline.
    // Even if you give it a complete set of buffers for the whole image,
    // it will only ever decompress a few lines at a time. For best
    // performance, you should pass it an array with cinfo.rec_outbuf_height
    // scanline buffers. rec_outbuf_height is typically 1, 2, or 4, and
    // at the default high quality decompression setting is always 1.
    while (cinfo.output_scanline < cinfo.output_height)
    {
        unsigned char *buffer_array[1];
        buffer_array[0] = bmp_buffer +
                          (cinfo.output_scanline) * row_stride;

        jpeg_read_scanlines(&cinfo, buffer_array, 1);
    }
    syslog(LOG_INFO, "Proc: Done reading scanlines");

    // Once done reading *all* scanlines, release all internal buffers,
    // etc by calling jpeg_finish_decompress. This lets you go back and
    // reuse the same cinfo object with the same settings, if you
    // want to decompress several jpegs in a row.
    //
    // If you didn't read all the scanlines, but want to stop early,
    // you instead need to call jpeg_abort_decompress(&cinfo)
    jpeg_finish_decompress(&cinfo);

    // At this point, optionally go back and either load a new jpg into
    // the jpg_buffer, or define a new jpeg_mem_src, and then start
    // another decompress operation.

    // Once you're really really done, destroy the object to free everything
    jpeg_destroy_decompress(&cinfo);
    // And free the input buffer
    // free(jpg_buffer);

    // DDDD       OOO    N     N  EEEEEEE
    // D  DDD    O   O   NN    N  E
    // D    DD  O     O  N N   N  E
    // D     D  O     O  N N   N  E
    // D     D  O     O  N  N  N  EEEE
    // D     D  O     O  N   N N  E
    // D    DD  O     O  N   N N  E
    // D  DDD    O   O   N    NN  E
    // DDDD       OOO    N     N  EEEEEEE

    // Write the decompressed bitmap out to a ppm file, just to make sure
    // it worked.
    // int fd = open("output.ppm", O_CREAT | O_WRONLY, 0666);
    // char buf[1024];

    // rc = sprintf(buf, "P6 %d %d 255\n", width, height);
    // write(fd, buf, rc);              // Write the PPM image header before data
    // write(fd, bmp_buffer, bmp_size); // Write out all RGB pixel data

    // validate data
    boolean valid = TRUE;
    for (int i = 0; i < bmp_size; i++)
    {

        if (abs(bmp_buffer[i] - image[i]) > 256 * 0.06)
        {
            valid = FALSE;
            printf("bmp_buffer[%d] = %d, image[%d] = %d\n", i, bmp_buffer[i], i, image[i]);
            // break;
        }
    }
    if (!valid)
    {
        syslog(LOG_ERR, "Data validate fail.");
    }
    else
    {
        syslog(LOG_INFO, "Data validate success.");
    }
    free(bmp_buffer);

    syslog(LOG_INFO, "End of decompression");
}

double test_encode_jpeg_to_memory()
{
    time_t t;
    srand((unsigned)time(&t));
    // With a pattern
    for (int j = 0; j != height; j++)
    {
        for (int i = 0; i != width; i++)
            image[i + j * width] = rand();
    }
    // Will hold encoded size
    // Will point to JPEG buffer
    // Encode image
    jBuf = (char *)malloc(width * height);
    double timeUsage = encode_jpeg_to_memory(image, width, height, 5, &jSize, &jBuf);
    printf("JPEG size (bytes): %ld, compression rate = %.2f%%\n", jSize, 100.0 * jSize / (width * height));
    return timeUsage;
}

int main(int argc, char **argv)
{
    double avgTime = 0;
    size_t testCount = 10;
    // Create an 8bit greyscale image
    image = (unsigned char *)malloc(width * height);
    for (int i = 0; i < testCount; i++)
    {
        printf("Test %d ...\r", i);
        avgTime += test_encode_jpeg_to_memory();
    }
    avgTime /= testCount;
    printf("Total test %ld times, average time usage = %.2f ms\n", testCount, avgTime * 1000);
    // decode_jpeg_to_memory(argc, argv);

    free(jBuf);
    free(image);
}
```

## libjpeg-turbo

```C
#include "turbojpeg.h"
#include <stdio.h>
#include <stdlib.h>
#include "time.h"

int main(int argc, char **argv)
{
    const int JPEG_QUALITY = 5;
    const int COLOR_COMPONENTS = 1;
    int _width = 640;
    int _height = 512;
    long unsigned int _jpegSize = 0;
    unsigned char *_compressedImage = NULL;                    //!< Memory is allocated by tjCompress2 if _jpegSize == 0
    unsigned char buffer[_width * _height * COLOR_COMPONENTS]; //!< Contains the uncompressed image

    tjSaveImage("before.bmp", buffer, _width, 0, _height, TJPF_GRAY, 0);
    clock_t start, stop;
    tjhandle _jpegCompressor = tjInitCompress();
    unsigned long long duration = .0;
    for (int i = 0; i < 10; i++)
    {
        time_t t;
        srand((unsigned)time(&t));
        // With a pattern
        for (int j = 0; j != _height; j++)
            for (int i = 0; i != _width; i++)
                buffer[i + j * _width] = rand();
        start = clock();

        tjCompress2(_jpegCompressor, buffer, _width, 0, _height, TJPF_GRAY,
                    &_compressedImage, &_jpegSize, TJSAMP_GRAY, JPEG_QUALITY,
                    TJFLAG_FASTDCT);
        stop = clock();
        // printf("[%d] JPEG size (bytes): %ld, compression rate = %.2f%%, time usage = %.5f ms\n", i, _jpegSize, 100.0 * _jpegSize / (_width * _height), (stop - start) / CLOCKS_PER_SEC * 1e3);
        duration += (stop - start);
        // usleep(1 * 1000);
    }

    tjDestroy(_jpegCompressor);

    int afterFd = fopen("after.jpeg", "wb");
    fwrite(_compressedImage, _jpegSize, 1, afterFd);
    fclose(afterFd);
    // to free the memory allocated by TurboJPEG (either by tjAlloc(),
    // or by the Compress/Decompress) after you are done working on it:
    // tjFree(&_compressedImage);
    printf("JPEG size (bytes): %ld, compression rate = %.2f%%, time usage = %.2f ms\n", _jpegSize, 100.0 * _jpegSize / (_width * _height), duration * 1.0 / 10 / CLOCKS_PER_SEC * 1e3);
    return 0;
}
```