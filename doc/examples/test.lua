--[[--------------------------------------------------------------------

  luahidapi test program

  Kein-Hong Man <keinhong@gmail.com>
  2012-05-09
  The author hereby places this code into PUBLIC DOMAIN

  NOTE
  - Connection to the custom HID device needs a USB-capable MCU
    properly connected to the PC using USB and proper firmware.

----------------------------------------------------------------------]]

local string = require "string"
local sfmt, sbyte = string.format, string.byte

local hid = require "luahidapi"

------------------------------------------------------------------------
-- initialize
------------------------------------------------------------------------

print("A simple luahidapi test:")
print("Lib VERSION = ", hid.VERSION)

if hid.init() then
  print("hid library: init")
else
  print("hid library: init error")
  return
end
print()

------------------------------------------------------------------------
-- test device enumeration
-- * there is no proper Unicode string handling for now
--   note that Unicode chars >127 will be converted to '?'
------------------------------------------------------------------------

local enum = hid.enumerate()
if not enum then
  print("Enumeration: no device found or enumeration failed!")
  return
else
  while true do
    local dev = enum:next()
    if not dev then break end

    print("Device found:")
    print(sfmt("path = '%s'", dev.path))
    print(sfmt("vid = 0x%04X", dev.vid))
    print(sfmt("pid = 0x%04X", dev.pid))

    print(sfmt("serial_number = '%s'", dev.serial_number))
    print(sfmt("release = 0x%04X", dev.release))

    print(sfmt("manufacturer_string = '%s'", dev.manufacturer_string))
    print(sfmt("product_string = '%s'", dev.product_string))

    -- usage_page/usage follows a byte-width hex format
    -- commonly used in the HID Usage Tables specifications
    if (dev.usage_page <= 0xFF) then
      print(sfmt("usage_page = 0x%02X", dev.usage_page))
    else
      print(sfmt("usage_page = 0x%04X", dev.usage_page))
    end
    if (dev.usage <= 0xFF) then
      print(sfmt("usage = 0x%02X", dev.usage))
    else
      print(sfmt("usage = 0x%04X", dev.usage))
    end
    print(sfmt("interface = %d", dev.interface))
    print()
  end
end

------------------------------------------------------------------------
-- open test device
------------------------------------------------------------------------

--====================================================================--
--** WARNING: Test uses Microchip's VID and a PID from MPLAB tools'  **
--** PID range. DO NOT use outside of a laboratory/personal setting. **
--====================================================================--

USB_DEVICE_VID = 0x04D8
USB_DEVICE_PID = 0x8ABC

-- (1) test device is a PIC18F2450 MCU used for prototyping, running
--     a low-speed USB connection and a custom USB HID descriptor
-- (2) fixed report size for both IN and OUT, no multiple report IDs
-- (3) a simple buffer is implemented: bytes written to using the OUT
--     pipe are echoed by the MCU and read back via the IN pipe
-- (4) buffer holds only one report's worth of data
-- (5) set/get feature report not implemented

USB_REPORT_SIZE = 4

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
-- non-blocking read test
------------------------------------------------------------------------

-- set non-blocking reads
if not dev:set("noblock") then
  print("Failed to set non-blocking option")
  return
end

-- Try to read from the device. There shoud be no
-- data here, but execution should not block.

local rx = dev:read(USB_REPORT_SIZE)
if rx then
  print("Done non-blocking read test")
  print("Size of report read = "..#rx)
else
  print("Read error during non-blocking read test")
  return
end
print()

------------------------------------------------------------------------
-- write to the device
------------------------------------------------------------------------

-- prepare report; report 0 is implied
local tx = string.char(0x12, 0x34, 0x56, 0x78)
print(sfmt("Writing 0x%02X%02X%02X%02X to device",
      sbyte(tx, 1), sbyte(tx, 2), sbyte(tx, 3), sbyte(tx, 4)))

local res = dev:write(tx)
if not res then
  print("Unable to write()")
  print("Error: "..dev:error())
  return
end

------------------------------------------------------------------------
-- read from the device
------------------------------------------------------------------------

local rx
for i = 1, 10 do
  -- a non-infinite read loop
  -- since we read immediately right after writing, the device buffer
  -- will be empty, it will NAK, and an empty string is returned
  rx = dev:read(USB_REPORT_SIZE)
  if not rx then
    print("Unable to read()")
    print("Error: "..dev:error())
    return
  elseif rx == "" then
    print("Waiting...")
  else
    break
  end
  for j = 1,200000 do end -- short delay
end
if #rx > 0 then
  print(sfmt("Read 0x%02X%02X%02X%02X from device",
        sbyte(rx, 1), sbyte(rx, 2), sbyte(rx, 3), sbyte(rx, 4)))
end
print()

------------------------------------------------------------------------
-- write to the device (try 2)
------------------------------------------------------------------------

-- prepare report; report 0 is implied
local tx = string.char(0xDE, 0xAD, 0xBE, 0xEF)
print(sfmt("Writing 0x%02X%02X%02X%02X to device",
      sbyte(tx, 1), sbyte(tx, 2), sbyte(tx, 3), sbyte(tx, 4)))

local res = dev:write(tx)
if not res then
  print("Unable to write()")
  print("Error: "..dev:error())
  return
end

------------------------------------------------------------------------
-- read from the device (try 2)
------------------------------------------------------------------------

local rx
for i = 1, 10 do
  -- a non-infinite read loop
  -- since we read immediately right after writing, the device buffer
  -- will be empty, it will NAK, and an empty string is returned
  rx = dev:read(USB_REPORT_SIZE)
  if not rx then
    print("Unable to read()")
    print("Error: "..dev:error())
    return
  elseif rx == "" then
    print("Waiting...")
  else
    break
  end
  for j = 1,200000 do end -- short delay
end
if #rx > 0 then
  print(sfmt("Read 0x%02X%02X%02X%02X from device",
        sbyte(rx, 1), sbyte(rx, 2), sbyte(rx, 3), sbyte(rx, 4)))
end
print()

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
