/*======================================================================
 * luahidapi: Lua binding for the hidapi library
 *
 * Copyright (c) 2012 Kein-Hong Man <keinhong@gmail.com>
 * The COPYRIGHT file describes the conditions under which this
 * software may be distributed.
 *
 * Library main file
 *
 * NOTES
 * - The hidapi library and the associated hidtest.c example code was
 *   written by Alan Ott, Signal 11 Software.
 *======================================================================
 */

#include <lua.h>
#include <lauxlib.h>

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <wchar.h>

#ifdef _WIN32
#include <windows.h>
#endif

#include "hidapi.h"

#include "luahidapi.h"

/*----------------------------------------------------------------------
 * constants and config
 *----------------------------------------------------------------------
 */

#define HIDAPI_VERSION  "0.1"
#define HIDAPI_LIB_NAME "hid"

#define USB_STR_MAXLEN 255      /* max USB string length */

/*----------------------------------------------------------------------
 * definitions for HID Device object
 *----------------------------------------------------------------------
 */

#define HIDAPI_LIB_HIDDEVICE    "HIDAPI_HIDDEVICE"

typedef struct HidDevice_Obj {
    hid_device *device;
} HidDevice_Obj;

#define to_HidDevice_Obj(L) ((HidDevice_Obj*)luaL_checkudata(L, 1, HIDAPI_LIB_HIDDEVICE))

/* validate object type and existence
 */
static HidDevice_Obj *check_HidDevice_Obj(lua_State *L)
{
    HidDevice_Obj *o = to_HidDevice_Obj(L);
    if (o->device == NULL)
        luaL_error(L, "attempt to use an invalid or closed object");
    return o;
}

/*----------------------------------------------------------------------
 * hid.init()
 * Initializes hidapi library.
 * Returns true if successful, nil on failure.
 *----------------------------------------------------------------------
 */

static int hidapi_init(lua_State *L)
{
    if (hid_init() == 0) {
        lua_pushboolean(L, TRUE);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/*----------------------------------------------------------------------
 * hid.exit()
 * Cleans up and terminates hidapi library.
 * Returns true if successful, nil on failure.
 *----------------------------------------------------------------------
 */

static int hidapi_exit(lua_State *L)
{
    if (hid_exit() == 0) {
        lua_pushboolean(L, TRUE);
    } else {
        lua_pushnil(L);
    }
    return 1;
}

/*----------------------------------------------------------------------
 * definitions for HID Device Enumeration object
 *----------------------------------------------------------------------
 */

#define HIDAPI_LIB_HIDENUM      "HIDAPI_HIDENUM"

enum {
    HIDENUM_CLOSE = 0,
    HIDENUM_OPEN,
    HIDENUM_DONE,
    /* error state is unused, since the enumeration is done once
     * and the returned linked list will not cause errors
     */
    HIDENUM_ERROR,
};

typedef struct HidEnum_Obj {
    int state;
    struct hid_device_info *dev_info;
} HidEnum_Obj;

#define to_HidEnum_Obj(L) ((HidEnum_Obj *)luaL_checkudata(L, 1, HIDAPI_LIB_HIDENUM))

/* validate object type+existence
 */
static HidEnum_Obj *check_HidEnum_Obj(lua_State *L)
{
    HidEnum_Obj *o = to_HidEnum_Obj(L);
    if (o->state == HIDENUM_CLOSE)
        luaL_error(L, "attempt to use a closed object");
    return o;
}

/*----------------------------------------------------------------------
 * e = hid.enumerate(vid, pid)
 * e = hid.enumerate()
 * Returns a HID device enumeration object for HID devices that matches
 * given vid, pid pair. Enumerates all HID devices if no arguments
 * provided or (0,0) used.
 * IMPORTANT: Mouse and keyboard devices are not visible on Windows
 * Returns nil if failed.
 *----------------------------------------------------------------------
 */

static int hidapi_enumerate(lua_State *L)
{
    int n = lua_gettop(L);  /* number of arguments */
    unsigned short vendor_id = 0;
    unsigned short product_id = 0;

    if (n == 2) {
        lua_Integer id;

        /* validate range of vid, pid */
        id = luaL_checkinteger(L, 1);
        if (id < 0 || id > 0xFFFF)
            goto error_handler;
        vendor_id = (unsigned short)id;

        id = luaL_checkinteger(L, 2);
        if (id < 0 || id > 0xFFFF)
            goto error_handler;
        product_id = (unsigned short)id;

    } else if (n != 0) {
        goto error_handler;
    }

    /* prepare object, state */
    HidEnum_Obj *o = (HidEnum_Obj *)lua_newuserdata(L, sizeof(HidEnum_Obj));
    o->state = HIDENUM_CLOSE;
    luaL_getmetatable(L, HIDAPI_LIB_HIDENUM);
    lua_setmetatable(L, -2);

    /* set up HID device enumeration */
    o->dev_info = hid_enumerate(vendor_id, product_id);
    if (o->dev_info == NULL) {
        goto error_handler;
    }
    o->state = HIDENUM_OPEN;
    return 1;

error_handler:
    lua_pushnil(L);
    return 1;
}

/*----------------------------------------------------------------------
 * simple wchar_t[] to char[] conversion, returns a string
 * - exposing wchar_t[] to Lua is messy, must consider cross-platform
 *   sizes of wchar_t, so here is a quickie but crippled solution...
 *----------------------------------------------------------------------
 */

void push_forced_ascii(lua_State *L, const wchar_t *s)
{
    int i;
    char d[USB_STR_MAXLEN + 1];

    if (!s) {                   /* check for NULL case */
        d[0] = '\0';
        lua_pushstring(L, d);
        return;
    }
    size_t n = wcslen(s);
    if (n > USB_STR_MAXLEN) n = USB_STR_MAXLEN;

    for (i = 0; i < n; i++) {
        wchar_t wc = s[i];
        char c = wc & 0x7F;     /* zap all de funny chars */
        if (wc > 127 || (wc > 0 && wc < 32)) {
            c = '?';
        }
        d[i] = c;
    }
    d[i] = '\0';
    lua_pushstring(L, d);
}

/*----------------------------------------------------------------------
 * e:next()
 * Returns next HID device found, nil if no more.
 *----------------------------------------------------------------------
 */

static int hidapi_enum_next(lua_State *L)
{
    /* validate object */
    HidEnum_Obj *o = check_HidEnum_Obj(L);
    if (o->state == HIDENUM_DONE) {
        lua_pushnil(L);
        return 1;
    }

    /* create device info table */
    struct hid_device_info *dinfo = o->dev_info;
    lua_createtable(L, 0, 10);  /* 10 = number of fields */

    lua_pushstring(L, dinfo->path);
    lua_setfield(L, -2, "path");
    lua_pushinteger(L, dinfo->vendor_id);
    lua_setfield(L, -2, "vid");
    lua_pushinteger(L, dinfo->product_id);
    lua_setfield(L, -2, "pid");

    push_forced_ascii(L, dinfo->serial_number);
    lua_setfield(L, -2, "serial_number");

    lua_pushinteger(L, dinfo->release_number);
    lua_setfield(L, -2, "release");

    push_forced_ascii(L, dinfo->manufacturer_string);
    lua_setfield(L, -2, "manufacturer_string");
    push_forced_ascii(L, dinfo->product_string);
    lua_setfield(L, -2, "product_string");

    lua_pushinteger(L, dinfo->usage_page);
    lua_setfield(L, -2, "usage_page");
    lua_pushinteger(L, dinfo->usage);
    lua_setfield(L, -2, "usage");
    lua_pushinteger(L, dinfo->interface_number);
    lua_setfield(L, -2, "interface");

    /* next HID device entry */
    o->dev_info = dinfo->next;
    if (o->dev_info == NULL) {
        o->state = HIDENUM_DONE;
    }
    return 1;
}

/*----------------------------------------------------------------------
 * e:close()
 * Close enumeration object. Always succeeds.
 *----------------------------------------------------------------------
 */

static int hidapi_enum_close(lua_State *L)
{
    HidEnum_Obj *o = check_HidEnum_Obj(L);
    if (o->state != HIDENUM_CLOSE) {
        hid_free_enumeration(o->dev_info);
    }
    o->state = HIDENUM_CLOSE;
    return 0;
}

/*----------------------------------------------------------------------
 * GC method for HidEnum_Obj
 *----------------------------------------------------------------------
 */

static int hidapi_enum_meta_gc(lua_State *L)
{
    HidEnum_Obj *o = to_HidEnum_Obj(L);
    if (o->state != HIDENUM_CLOSE) {
        hid_free_enumeration(o->dev_info);
    }
    o->state = HIDENUM_CLOSE;
    return 0;
}

/*----------------------------------------------------------------------
 * register and create metatable for HIDENUM object
 *----------------------------------------------------------------------
 */

static const struct luaL_reg hidenum_meta_reg[] = {
    {"next",  hidapi_enum_next},
    {"close", hidapi_enum_close},
    {"__gc",  hidapi_enum_meta_gc},
    {NULL, NULL},
};

static void hidapi_create_hidenum_obj(lua_State *L) {
    luaL_newmetatable(L, HIDAPI_LIB_HIDENUM);
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    luaL_register(L, NULL, hidenum_meta_reg);
}

/*----------------------------------------------------------------------
 * dev = hid.open(path)
 * dev = hid.open(vid, pid)
 * Opens a HID device using a path name or a vid, pid pair. Returns
 * a HID device object if successful. Specification of a serial number
 * is currently unimplemented (it uses wchar_t).
 * IMPORTANT: Mouse and keyboard devices are not visible on Windows
 * Returns nil if failed.
 *----------------------------------------------------------------------
 */

static int hidapi_open(lua_State *L)
{
    hid_device *dev;
    int n = lua_gettop(L);  /* number of arguments */

    if (n == 2 && lua_isnumber(L, 1) && lua_isnumber(L, 2)) {
        /* validate, then attempt to open using pid, vid pair */
        lua_Integer id;

        id = luaL_checkinteger(L, 1);
        if (id < 0 || id > 0xFFFF)
            goto error_handler;
        unsigned short vendor_id = (unsigned short)id;

        id = luaL_checkinteger(L, 2);
        if (id < 0 || id > 0xFFFF)
            goto error_handler;
        unsigned short product_id = (unsigned short)id;

        dev = hid_open(vendor_id, product_id, NULL);

    } else if (n == 2 && lua_isstring(L, 1)) {
        /* attempt to open using a given path */
        const char *dpath = lua_tostring(L, 1);

        dev = hid_open_path(dpath);
    } else
        goto error_handler;
    if (!dev)
        goto error_handler;

    /* handle is valid, prepare object */
    HidDevice_Obj *o = (HidDevice_Obj *)lua_newuserdata(L, sizeof(HidDevice_Obj));
    o->device = dev;
    luaL_getmetatable(L, HIDAPI_LIB_HIDDEVICE);
    lua_setmetatable(L, -2);
    return 1;

error_handler:
    lua_pushnil(L);
    return 1;
}

/*----------------------------------------------------------------------
 * hid.write(dev, report_id, report)
 * dev:write(report_id, report)
 *      report_id       - report ID of this write
 *      report          - report data as a string
 * hid.write(dev, report)
 * dev:write(report)
 *      a report ID of 0 is implied if it is left out
 *      report          - report data as a string
 * Returns bytes sent if successful, nil on failure.
 *----------------------------------------------------------------------
 */

static int hidapi_write(lua_State *L)
{
    int i;
    HidDevice_Obj *o = check_HidDevice_Obj(L);
    int n = lua_gettop(L);  /* number of arguments */
    int rid = 0;
    int rsrc = 3;

    if (n == 2 && lua_isstring(L, 2)) {
        /* no report ID, report only */
        rsrc = 2;
    } else {
        /* report ID and report */
        rid = luaL_checkinteger(L, 2);
    }
    size_t rsize;
    const char *rdata = luaL_checklstring(L, rsrc, &rsize);

    /* report ID range check */
    if (rid < 0 || rid > 0xFF)
        goto error_handler;

    /* prepare buffer for report transmit */
    size_t txsize = rsize + 1;
    unsigned char *txdata = (unsigned char *)lua_newuserdata(L, txsize);
    txdata[0] = rid;
    for (i = 0; i < rsize; i++)
        txdata[i + 1] = rdata[i];

    /* send */
    int res = hid_write(o->device, txdata, txsize);
    if (res < 0)
        goto error_handler;
    lua_pushinteger(L, res);
    return 1;

error_handler:
    lua_pushnil(L);
    return 1;
}

/*----------------------------------------------------------------------
 * hid.read(dev, report_size[, timeout_msec])
 * dev:read(report_size[, timeout_msec])
 *      report_size     - size of the read report buffer
 *      timeout_msec    - optional timeout in milliseconds
 * If device has multiple reports, the first byte returned will be the
 * report ID and one extra byte need to be allocated via report_size.
 * For a normal call, timeout_msec can be omitted and blocking will
 * depend on the selected option setting.
 * Specifying a timeout_msec of -1 selects a blocking wait.
 * Returns report as a string if successful, nil on failure.
 *----------------------------------------------------------------------
 */

static int hidapi_read(lua_State *L)
{
    HidDevice_Obj *o = check_HidDevice_Obj(L);
    int n = lua_gettop(L);  /* number of arguments */

    int rxsize = luaL_checkinteger(L, 2);
    if (rxsize < 0)
        goto error_handler;

    int using_timeout = 0;
    int timeout = 0;
    if (n == 3) {               /* get optional timeout */
        using_timeout = 1;
        timeout = luaL_checkinteger(L, 3);
    }

    /* prepare buffer for report receive */
    unsigned char *rxdata = (unsigned char *)lua_newuserdata(L, rxsize);

    /* receive */
    int res;
    if (using_timeout) {
        res = hid_read_timeout(o->device, rxdata, rxsize, timeout);
    } else {
        res = hid_read(o->device, rxdata, rxsize);
    }
    if (res < 0)
        goto error_handler;
    lua_pushlstring(L, (char *)rxdata, res);
    return 1;

error_handler:
    lua_pushnil(L);
    return 1;
}

/*----------------------------------------------------------------------
 * hid.set(dev, option)
 * dev:set(option)
 * Set device options:
 *      "block"   - reads will block
 *      "noblock" - reads will return immediately even if no data
 * Returns true if successful, nil on failure.
 *----------------------------------------------------------------------
 */

enum {
    DEV_SET_BLOCK = 0,
    DEV_SET_NOBLOCK
};

static int hidapi_set(lua_State *L)
{
    HidDevice_Obj *o = check_HidDevice_Obj(L);

    static const char *const settings[] = {
        "block", "noblock", NULL
    };
    int op = luaL_checkoption(L, 2, NULL, settings);

    /* prepare parameter for blocking setting */
    int nonblock = 0;
    if (op == DEV_SET_NOBLOCK)
        nonblock = 1;

    /* perform blocking setting */
    if (hid_set_nonblocking(o->device, nonblock) < 0) {
        lua_pushnil(L);
    } else {
        lua_pushboolean(L, TRUE);
    }
    return 1;
}

/*----------------------------------------------------------------------
 * hid.getstring(dev, option)
 * dev:getstring(option)
 * Get device string options:
 *      "manufacturer"  - manufacturer string
 *      "product"       - product string
 *      "serial"        - serial string
 *      or an integer signifying a string index
 * Returns the string if successful, nil on failure.
 * String are forcibly converted to ASCII.
 *----------------------------------------------------------------------
 */

enum {
    DEV_GETSTR_MANUFACTURER = 0,
    DEV_GETSTR_PRODUCT,
    DEV_GETSTR_SERIAL_NUMBER
};

static int hidapi_getstring(lua_State *L)
{
    wchar_t ws[USB_STR_MAXLEN];
    ws[0] = 0;

    HidDevice_Obj *o = check_HidDevice_Obj(L);

    static const char *const settings[] = {
        "manufacturer", "product", "serial_number", NULL
    };

    if (lua_isnumber(L, 2)) {
        /* indexed USB strings */
        int strid = luaL_checkinteger(L, 2);
        if (hid_get_indexed_string(o->device, strid, ws, USB_STR_MAXLEN) < 0) {
            goto error_handler;
        }
    } else {
        /* named (standard) USB strings */
        int op = luaL_checkoption(L, 2, NULL, settings);
        if (op == DEV_GETSTR_MANUFACTURER) {
            if (hid_get_manufacturer_string(o->device, ws, USB_STR_MAXLEN) < 0) {
                goto error_handler;
            }
        } else if (op == DEV_GETSTR_PRODUCT) {
            if (hid_get_product_string(o->device, ws, USB_STR_MAXLEN) < 0) {
                goto error_handler;
            }
        } else { /* (op == DEV_GETSTR_SERIAL_NUMBER) */
            if (hid_get_serial_number_string(o->device, ws, USB_STR_MAXLEN) < 0) {
                goto error_handler;
            }
        }
    }
    push_forced_ascii(L, ws);
    return 1;

error_handler:
    lua_pushnil(L);
    return 1;
}

/*----------------------------------------------------------------------
 * hid.setfeature(dev, feature_id, feature_data)
 * dev:setfeature(feature_id, feature_data)
 *      feature_id      - feature report ID, 1-byte range
 *      feature_data    - string containing feature report data
 * Set (send) a feature report. A 0 is used for a single report ID.
 * Returns bytes sent if successful, nil on failure.
 *----------------------------------------------------------------------
 */

static int hidapi_setfeature(lua_State *L)
{
    int i;
    HidDevice_Obj *o = check_HidDevice_Obj(L);

    /* feature report ID check */
    int fid = luaL_checkinteger(L, 2);
    if (fid < 0 || fid > 0xFF)
        goto error_handler;

    size_t fsize;
    const char *fdata = luaL_checklstring(L, 3, &fsize);

    /* prepare buffer for report transmit */
    size_t txsize = fsize + 1;
    unsigned char *txdata = (unsigned char *)lua_newuserdata(L, txsize);
    txdata[0] = fid;
    for (i = 0; i < fsize; i++)
        txdata[i + 1] = fdata[i];

    /* send */
    int res = hid_send_feature_report(o->device, txdata, txsize);
    if (res < 0)
        goto error_handler;
    lua_pushinteger(L, res);
    return 1;

error_handler:
    lua_pushnil(L);
    return 1;
}

/*----------------------------------------------------------------------
 * hid.getfeature(dev, feature_id, feature_size)
 * dev:getfeature(feature_id, feature_size)
 *      feature_id      - feature report ID, 1-byte range
 *      feature_size    - size of read buffer, may be larger than the
 *                        actual feature report
 * Get a feature report. A 0 is used for a single report ID.
 * Returns feature report as a string if successful, nil on failure.
 *----------------------------------------------------------------------
 */

static int hidapi_getfeature(lua_State *L)
{
    HidDevice_Obj *o = check_HidDevice_Obj(L);

    /* feature report ID check */
    int fid = luaL_checkinteger(L, 2);
    if (fid < 0 || fid > 0xFF)
        goto error_handler;

    int fsize = luaL_checkinteger(L, 3);
    if (fsize < 0)
        goto error_handler;

    /* prepare buffer for report receive */
    size_t rxsize = fsize + 1;
    unsigned char *rxdata = (unsigned char *)lua_newuserdata(L, rxsize);
    rxdata[0] = fid;

    /* receive */
    int res = hid_get_feature_report(o->device, rxdata, rxsize);
    if (res < 0)
        goto error_handler;
    lua_pushlstring(L, (char *)rxdata, res);
    return 1;

error_handler:
    lua_pushnil(L);
    return 1;
}

/*----------------------------------------------------------------------
 * hid.error(dev)
 * dev:error()
 * Returns a string describing the last error, or nil if there was no
 * error. Error string is forcibly converted to ASCII.
 *----------------------------------------------------------------------
 */

static int hidapi_error(lua_State *L)
{
    HidDevice_Obj *o = check_HidDevice_Obj(L);
    if (o->device) {
        const wchar_t *err = hid_error(o->device);
        if (err) {
            push_forced_ascii(L, err);
            return 1;
        }
    }
    lua_pushnil(L);
    return 1;
}

/*----------------------------------------------------------------------
 * hid.close(dev)
 * dev:close()
 * Close HID device object. Always succeeds.
 *----------------------------------------------------------------------
 */

static int hidapi_close(lua_State *L)
{
    HidDevice_Obj *o = check_HidDevice_Obj(L);
    if (o->device) {
        hid_close(o->device);
    }
    o->device = NULL;
    return 0;
}

/*----------------------------------------------------------------------
 * GC method for HidDevice_Obj
 *----------------------------------------------------------------------
 */

static int hidapi_hiddevice_meta_gc(lua_State *L)
{
    HidDevice_Obj *o = to_HidDevice_Obj(L);
    if (o->device) {
        hid_close(o->device);
    }
    o->device = NULL;
    return 0;
}

/*----------------------------------------------------------------------
 * hid.msleep(milliseconds)
 * A convenience sleep function. Time is specified in milliseconds.
 *----------------------------------------------------------------------
 */

static int hidapi_msleep(lua_State *L)
{
    int msec = luaL_checkinteger(L, 1);

#ifdef WIN32
    Sleep(msec);
#else
    usleep(msec * 1000);
#endif
    return 0;
}

/*----------------------------------------------------------------------
 * register and create metatable for HIDDEVICE object
 *----------------------------------------------------------------------
 */

static const struct luaL_reg hiddevice_meta_reg[] = {
    {"write", hidapi_write},
    {"read", hidapi_read},
    {"set", hidapi_set},
    {"getstring", hidapi_getstring},
    {"setfeature", hidapi_setfeature},
    {"getfeature", hidapi_getfeature},
    {"error", hidapi_error},
    {"close", hidapi_close},
    {"__gc",  hidapi_hiddevice_meta_gc},
    {NULL, NULL},
};

static void hidapi_create_hiddevice_obj(lua_State *L) {
    luaL_newmetatable(L, HIDAPI_LIB_HIDDEVICE);
    lua_pushvalue(L, -1);
    lua_setfield(L, -2, "__index");
    luaL_register(L, NULL, hiddevice_meta_reg);
}

/*----------------------------------------------------------------------
 * list of functions in module "hid"
 *----------------------------------------------------------------------
 */

static const struct luaL_reg hidapi_func_list[] = {
    {"init", hidapi_init},
    {"exit", hidapi_exit},
    {"enumerate", hidapi_enumerate},
    {"open", hidapi_open},
    {"write", hidapi_write},
    {"read", hidapi_read},
    {"set", hidapi_set},
    {"getstring", hidapi_getstring},
    {"setfeature", hidapi_setfeature},
    {"getfeature", hidapi_getfeature},
    {"error", hidapi_error},
    {"close", hidapi_close},
    {"msleep", hidapi_msleep},
    {NULL, NULL},
};

/*----------------------------------------------------------------------
 * main entry function; library registration
 *----------------------------------------------------------------------
 */

HIDAPI_API int luaopen_luahidapi(lua_State *L)
{
    /* enum metatable */
    hidapi_create_hidenum_obj(L);
    /* device handle metatable */
    hidapi_create_hiddevice_obj(L);
    /* library */
    luaL_register(L, HIDAPI_LIB_NAME, hidapi_func_list);
    lua_pushliteral(L, "VERSION");
    lua_pushliteral(L, HIDAPI_VERSION);
    lua_settable(L, -3);
    return 1;
}
