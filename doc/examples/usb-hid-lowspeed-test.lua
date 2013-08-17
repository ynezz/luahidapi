--[[--------------------------------------------------------------------

  Low speed echo test for USB HID device
  firmware: 18F2450/022-usb-custom-hid-test3
  firmware: 18F14K50/003-usb-custom-hid-test

  Kein-Hong Man <keinhong@gmail.com>
  2013-02-09
  The author hereby places this code into PUBLIC DOMAIN

  NOTE
  - test device is a PIC18 MCU test board used for prototyping, running
    a low speed USB connection and a custom USB HID descriptor
  - fixed report size for both IN and OUT, no multiple report IDs
  - a maximum packet size of 8 in both directions is used to test the
    limit for low speed USB connections
  
  - LOW SPEED
  - PIC18F2450 results:  common maximum rate = 125 echoes/sec
    (1000B/sec in each direction, device polling interval is 10ms)
  - PIC18F14K50 results: common maximum rate = 125 echoes/sec
    (1000B/sec in each direction, device polling interval is 10ms)
  - timeouts sometimes occur, but only at the beginning
  - low speed USB polling is 10msec minimum, Windows runs it at 8msec
  - therefore peak low speed HID rate is 125*8 = 1000 bytes

----------------------------------------------------------------------]]

local string = require "string"
local sfmt, sbyte, schar = string.format, string.byte, string.char
local mrnd = math.random
local otime = os.time

local hid = require "luahidapi"

local function print(...)
  io.stdout:write(...)
  io.stdout:write("\n")
  io.stdout:flush()
end

------------------------------------------------------------------------
-- initialize
------------------------------------------------------------------------

print("Low speed echo test for USB HID device:")
print(string.format("Lib VERSION %s build on %s", hid._VERSION, hid._TIMESTAMP))

if hid.init() then
  print("hid library: init")
else
  print("hid library: init error")
  return
end
print()

------------------------------------------------------------------------
-- open test device
------------------------------------------------------------------------

--====================================================================--
--** WARNING: Test uses Microchip's VID and a PID from MPLAB tools'  **
--** PID range. DO NOT use outside of a laboratory/personal setting. **
--====================================================================--

local USB_DEVICE_VID = 0x04D8
local USB_DEVICE_PID = 0x8AC1

local USB_REPORT_SIZE = 8

local dev = hid.open(USB_DEVICE_VID, USB_DEVICE_PID)
if not dev then
  print("Open: unable to open test device")
  return
end
print("Open: opened test device")
print()

------------------------------------------------------------------------
-- read the manufacturer string
------------------------------------------------------------------------

local mstr = dev:getstring("manufacturer")
if mstr then
  print("Manufacturer String: "..mstr)
else
  print("Unable to read manufacturer string")
  return
end

------------------------------------------------------------------------
-- read the product string
------------------------------------------------------------------------

local pstr = dev:getstring("product")
if pstr then
  print("Product String: "..pstr)
else
  print("Unable to read product string")
  return
end
print()

------------------------------------------------------------------------
-- set non-blocking
------------------------------------------------------------------------

-- set non-blocking reads
if not dev:set("noblock") then
  print("Failed to set non-blocking option")
  return
end

------------------------------------------------------------------------
-- test portion
------------------------------------------------------------------------

local SAMPLE_BLOCKS = 10        -- number of 1 sec sample blocks
local TIMEOUT_SEC = 2           -- time before we retry write

local time_begin = otime()
local time_end = time_begin + SAMPLE_BLOCKS + 0.5
local time_sec = time_begin + 1
local sec_count = 0             -- number of echoes completed

while otime() < time_end do
  -- prepare report; report 0 is implied
  local tx =
    schar(mrnd(0,255), mrnd(0,255), mrnd(0,255), mrnd(0,255), 
          mrnd(0,255), mrnd(0,255), mrnd(0,255), mrnd(0,255))

  local res = dev:write(tx)
  if not res then
    print("Unable to write()")
    print("Error: "..dev:error())
    return
  end

  local timeout = otime() + TIMEOUT_SEC
  while otime() < timeout do
    rx = dev:read(USB_REPORT_SIZE)
    if not rx then
      print("Unable to read()")
      print("Error: "..dev:error())
      return
    elseif rx == "" then
      --do nothing print("Waiting...")
    else
      break
    end
  end

  if otime() >= timeout then
    print("Timeout, no response from device in 2 seconds")
    time_sec = time_sec + TIMEOUT_SEC
    time_end = time_end + TIMEOUT_SEC
  elseif rx ~= tx then
    print("Error: RX data is different from TX data")
    print(sfmt("TX: 0x%02X%02X%02X%02X%02X%02X%02X%02X",
          sbyte(tx, 1), sbyte(tx, 2), sbyte(tx, 3), sbyte(tx, 4),
          sbyte(tx, 5), sbyte(tx, 6), sbyte(tx, 7), sbyte(tx, 8)))
    if #rx < 8 then
      print("RX data size is "..#rx.." bytes")
      while #rx < 8 do rx = rx..schar(0) end
    end
    print(sfmt("RX: 0x%02X%02X%02X%02X%02X%02X%02X%02X",
          sbyte(rx, 1), sbyte(rx, 2), sbyte(rx, 3), sbyte(rx, 4),
          sbyte(rx, 5), sbyte(rx, 6), sbyte(rx, 7), sbyte(rx, 8)))
    return
  else
    sec_count = sec_count + 1
    local time_now = otime()
    if time_now >= time_sec then
      print("Echoed 8 byte packets in 1 second: "..sec_count)
      time_sec = time_sec + 1
      sec_count = 0
    end
  end
end

------------------------------------------------------------------------
-- close test device
------------------------------------------------------------------------

dev:close()
print("Close: closed test device")

------------------------------------------------------------------------
-- close hidapi library
------------------------------------------------------------------------

if hid.exit() then
  print("hid library: exit")
else
  print("hid library: exit error")
  return
end
