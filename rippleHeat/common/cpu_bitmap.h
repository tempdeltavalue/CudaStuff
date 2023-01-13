/*
 * Copyright 1993-2010 NVIDIA Corporation.  All rights reserved.
 *
 * NVIDIA Corporation and its licensors retain all intellectual property and
 * proprietary rights in and to this software and related documentation.
 * Any use, reproduction, disclosure, or distribution of this software
 * and related documentation without an express license agreement from
 * NVIDIA Corporation is strictly prohibited.
 *
 * Please refer to the applicable NVIDIA end user license agreement (EULA)
 * associated with this source code for terms and conditions that govern
 * your use of this NVIDIA software.
 *
 */


#ifndef __CPU_BITMAP_H__
#define __CPU_BITMAP_H__

#include "gl_helper.h"

#include <iostream>

struct CPUBitmap {
    unsigned char* pixels;
    int     x, y;
    void* dataBlock;
    void (*bitmapExit)(void*);

    CPUBitmap(int width, int height, void* d = NULL) {
        pixels = new unsigned char[width * height * 4];
        x = width;
        y = height;
        dataBlock = d;
    }

    ~CPUBitmap() {
        delete[] pixels;
    }

    unsigned char* get_ptr(void) const { return pixels; }
    long image_size(void) const { return x * y * 4; }

    void display_and_exit(void(*e)(void*) = NULL) {
        CPUBitmap** bitmap = get_bitmap_ptr();
        *bitmap = this;
        bitmapExit = e;
        // a bug in the Windows GLUT implementation prevents us from
        // passing zero arguments to glutInit()
        int c = 1;
        char* dummy = "";
        glutInit(&c, &dummy);
        glutInitDisplayMode(GLUT_SINGLE | GLUT_RGBA);
        glutInitWindowSize(x, y);
        glutCreateWindow("bitmap");
        glutKeyboardFunc(Key);
        glutMouseFunc(mouseClick);
        glutDisplayFunc(Draw);
        glutMainLoop();
    }

    static void mouseClick(int btn, int state, int x, int y) {
        printf("MOUSE CLICK");
        //if (state == GLUT_DOWN) {
        //    switch (btn) {
        //    case GLUT_LEFT_BUTTON:
        //        std::cout << "left click at: (" << x << ", " << y << ")\n";
        //        break;
        //    case GLUT_RIGHT_BUTTON:
        //        std::cout << "right click at: (" << x << ", " << y << ")\n";
        //        break;
        //    case GLUT_MIDDLE_BUTTON:
        //        std::cout << "middle click at: (" << x << ", " << y << ")\n";
        //        break;
        //    case 3:  //mouse wheel scrolls
        //        std::cout << "mouse wheel scroll up\n";
        //        break;
        //    case 4:
        //        std::cout << "mouse wheel scroll down\n";
        //        break;
        //    default:
        //        break;
        //    }
        //}
        glutPostRedisplay();
    }

    // static method used for glut callbacks
    static CPUBitmap** get_bitmap_ptr(void) {
        static CPUBitmap* gBitmap;
        return &gBitmap;
    }

    // static method used for glut callbacks
    static void Key(unsigned char key, int x, int y) {
        //printf("KEY %f", key)
        //switch (key) {
        //case 27:
        //    CPUBitmap * bitmap = *(get_bitmap_ptr());
        //    if (bitmap->dataBlock != NULL && bitmap->bitmapExit != NULL)
        //        bitmap->bitmapExit(bitmap->dataBlock);
        //    exit(0);
        //}
    }

    // static method used for glut callbacks
    static void Draw(void) {
        CPUBitmap* bitmap = *(get_bitmap_ptr());
        glClearColor(0.0, 0.0, 0.0, 1.0);
        glClear(GL_COLOR_BUFFER_BIT);
        glDrawPixels(bitmap->x, bitmap->y, GL_RGBA, GL_UNSIGNED_BYTE, bitmap->pixels);
        glFlush();
    }
};

#endif  // __CPU_BITMAP_H__