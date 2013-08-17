/*----------------------------------------------------------------------
 * luahidapi: Lua binding for the hidapi library
 *
 * Copyright (c) 2012 Kein-Hong Man <keinhong@gmail.com>
 * The COPYRIGHT file describes the conditions under which this
 * software may be distributed.
 *
 * Library header file
 *----------------------------------------------------------------------
 */

#ifndef HIDAPI_LIB_H
#define HIDAPI_LIB_H

/* paranoia */
#if !defined(LUA_NUMBER_DOUBLE)
#error "please check sources first whether a non-double will work..."
#endif

/*----------------------------------------------------------------------
 * generic library handling code
 *----------------------------------------------------------------------
 */

#ifdef __cplusplus
extern "C" {
#endif

#if (defined(WIN32) || defined(UNDER_CE)) && !defined(HIDAPI_LIB_STATIC)
        #ifdef 
                #define HIDAPI_API __declspec(dllexport)
        #else
                #define HIDAPI_API __declspec(dllimport)
        #endif
#else
        #define HIDAPI_API
#endif

/* ELF optimization of externs when compiling as a shared library */
#if defined(HIDAPI_BIG_STATIC)
#   define INT_FUNC     static
#   define INT_DATA     /* empty */
#elif defined(__GNUC__) && defined(__ELF__) && \
      (__GNUC__ >= 3) && (__GNUC_MINOR__ >= 2)
#   define INT_FUNC     __attribute__((visibility("hidden"))) extern
#   define INT_DATA     INT_FUNC
#else
#   define INT_FUNC     extern
#   define INT_DATA     extern
#endif

/*
 * start of library declarations
 */
HIDAPI_API int luaopen_luahidapi(lua_State *L);

#ifdef __cplusplus
}
#endif

#endif /* HIDAPI_LIB_H */
