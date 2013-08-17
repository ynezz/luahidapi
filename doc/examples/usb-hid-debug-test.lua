--[[--------------------------------------------------------------------

  Debug tool for USB HID device
  firmware: 18F14K50/005-usb-test9-debug-record

  Kein-Hong Man <keinhong@gmail.com>
  2013-02-10
  The author hereby places this code into PUBLIC DOMAIN

  NOTE
  - test device is a PIC18F14K50 MCU test board used for prototyping,
    running a full speed USB connection and a custom USB HID descriptor
  - fixed report size for both IN and OUT, no multiple report IDs
  - returns debug data recorded in EEPROM at button press

  SAMPLE RESULT (see firmware code)

E0 E1 A0 A0 A2 A0 A5 A2
A3 A3 A2 A3 A3 A6 A8 A1
E2 C0 C1 C0 C1 C0 C1 C0
00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 00
00 00 00 00 00 00 00 18

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

local TIMEOUT_SEC = 2           -- time before we retry write

while true do
  -- prepare report; report 0 is implied
  -- (doesn't matter what data is for this firmware)
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
  elseif #rx ~= USB_REPORT_SIZE then
    print("Error: RX data is not "..USB_REPORT_SIZE.." bytes")
    print("RX data size is "..#rx.." bytes")
    return
  else
    -- got some kind of valid return data
    break
  end
end

local rx2 = ""
for i = 1, USB_REPORT_SIZE do
  rx2 = rx2..sfmt("%02X ", sbyte(rx, i))
  if i % 8 == 0 then
    print(rx2)
    rx2 = ""
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
