--[[--------------------------------------------------------------------

  Full speed echo test for USB HID device
  firmware: 18F14K50/004-full-speed-hid-test

  Kein-Hong Man <keinhong@gmail.com>
  2013-02-09
  The author hereby places this code into PUBLIC DOMAIN

  NOTE
  - test device is a PIC18F14K50 MCU test board used for prototyping,
    running a full speed USB connection and a custom USB HID descriptor
  - fixed report size for both IN and OUT, no multiple report IDs
  - a maximum packet size of 64 in both directions is used to test the
    limit for low speed USB connections
  
  - FULL SPEED
  - PIC18F14K50 results: approx. maximum rate = 490 echoes/sec
    (30.6KB/sec in each direction, device polling interval is 1ms)
  - timeouts sometimes occur, but only at the beginning

----------------------------------------------------------------------]]

local string = require "string"
local sfmt, sbyte, schar, srep = string.format, string.byte, string.char, string.rep
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

print("Full speed echo test for USB HID device:")
print("Lib VERSION = ", hid.VERSION)

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
local USB_DEVICE_PID = 0x8AC2

local USB_REPORT_SIZE = 64

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
  tx = srep(tx, USB_REPORT_SIZE / 8)

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
    print("RX data size is "..#rx.." bytes")
    return
  else
    sec_count = sec_count + 1
    local time_now = otime()
    if time_now >= time_sec then
      print("Echoed "..USB_REPORT_SIZE.." byte packets in 1 second: "..sec_count)
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
