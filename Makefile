# ----------------------------------------------------------------------
# luahidapi: Lua binding for the hidapi library
# A crippled backup library for a crippled operating system.
#
# Authored by 2012 Kein-Hong Man <keinhong@gmail.com>
# This file is hereby placed into PUBLIC DOMAIN.
#
# Notes:
# * for MinGW on MSYS, link to lua51.dll, mingw-compiled Lua
# * lua51.dll should be in /usr/local/lib for -llua51 library parameter
# * static lib (.a) output is untested, please use the DLL
#
# ----------------------------------------------------------------------

CC = gcc
LUA_DLL = -llua51
LIB_NAME = luahidapi
LIBS = -lhidapi

INC_PATH = -I/usr/local/include
LIB_PATH = -L/usr/local/lib -L.

OPT_FLAGS = -O2
MYCFLAGS = -DHIDAPI_LIB_DLL -Wall -Wundef $(OPT_FLAGS)
CFLAGS = $(INC_PATH) $(MYCFLAGS)
LDFLAGS = $(LIB_PATH) $(LIBS)

LIB_DLL = $(LIB_NAME).dll
LIB_A = $(LIB_NAME).a
OBJS = $(LIB_NAME).o

all: $(LIB_DLL)

$(LIB_NAME).c: $(LIB_NAME).h

$(LIB_DLL): $(OBJS)
	$(CC) -shared $(LDFLAGS) -o $@ $(OBJS) $(LUA_DLL) -Wl,--out-implib,$(LIB_A)

clean:
	rm -f $(OBJS) $(LIB_DLL) $(LIB_A)

.PHONY: all clean
