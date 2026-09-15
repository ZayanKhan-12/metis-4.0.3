/*
 * Copyright 1997, Regents of the University of Minnesota
 *
 * metis.h
 *
 * This file includes all necessary header files
 *
 * Started 8/27/94
 * George
 *
 * $Id: metis.h,v 1.1 1998/11/27 17:59:21 karypis Exp $
 */


/* RandomInRange() in macros.h calls drand48(), and util.c calls srand48().
   Both are POSIX XSI, not ISO C, so glibc and musl only declare them when a
   feature test macro asks for POSIX.  Building with a strict -std=c99 instead
   of the compiler's default -std=gnu* therefore left them implicitly declared,
   which GCC 14 and Clang 16 reject outright.  This has to come before the first
   system header, and every METIS source includes metis.h first.

   Apple's headers expose these unconditionally and treat _XOPEN_SOURCE as a
   request to *hide* their BSD extensions, so only _DEFAULT_SOURCE is set there. */
#if !defined(_DEFAULT_SOURCE)
#define _DEFAULT_SOURCE 1
#endif
#if !defined(__APPLE__) && !defined(_XOPEN_SOURCE) && !defined(_GNU_SOURCE)
#define _XOPEN_SOURCE 600
#endif

#include <stdio.h>
#ifdef __STDC__
#include <stdlib.h>
#else
#include <malloc.h>
#endif
#include <string.h>
#include <ctype.h>
#include <math.h>
#include <stdarg.h>
#include <time.h>

#ifdef DMALLOC
#include <dmalloc.h>
#endif

#include <defs.h>
#include <struct.h>
#include <macros.h>
#include <rename.h>
#include <proto.h>

