--[[--------------------------------------------------------------------

  luahidapi test program 2
  tests custom USB HID IN and OUT

  Kein-Hong Man <keinhong@gmail.com>
  2012-05-18
  The author hereby places this code into PUBLIC DOMAIN

  NOTE
  - Connection to the custom HID device needs a USB-capable MCU
    properly connected to the PC using USB and proper firmware.

----------------------------------------------------------------------]]

local string = require "string"
local sfmt, sbyte = string.format, string.byte

local hid = require "luahidapi"

local function print(...)
  io.stdout:write(...)
  io.stdout:write("\n")
  io.stdout:flush()
end

------------------------------------------------------------------------
-- initialize
------------------------------------------------------------------------

print("A simple luahidapi test:")
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
local USB_DEVICE_PID = 0x8ABD

-- (1) test device is a PIC18F2450 MCU used for prototyping, running
--     a low-speed USB connection and a custom USB HID descriptor
-- (2) fixed report size for both IN and OUT, no multiple report IDs
-- (3) read 'A' at index 0 - button is pressed
-- (4) write 'Bx' to set LED, ASCII of 'x' is 0=on, 1=off

local USB_REPORT_SIZE = 4

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
-- test portion: press test board's button 6 times
------------------------------------------------------------------------

local led_state = 0     -- LED toggle state
local rx
for i = 1, 6 do
  while true do
    repeat                              -- handle button press
      hid.msleep(100)
      rx = dev:read(USB_REPORT_SIZE)
      if not rx then
        print("Unable to read()")
        print("Error: "..dev:error())
        return
      end
    until rx ~= ""
    print("Button press #"..i)

    if string.sub(rx, 1, 1) == 'A' then -- handle LED state set
      led_state = (led_state == 0) and 1 or 0
      local tx = 'B'..string.char(led_state)..'  '
      local res = dev:write(tx)
      if not res then
        print("Unable to write()")
        print("Error: "..dev:error())
        return
      end
      print("LED state set -> "..led_state)
      break
    end
  end--while
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
