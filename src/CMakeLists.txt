# vim: set ts=8 noet:

find_package(Lua51 REQUIRED)

set(lib_SRCS luahidapi.c)
if(WIN32)
	configure_file(luahidapi.rc.cmake luahidapi.rc)
	list(APPEND lib_SRCS luahidapi.rc)
endif()

if(CMAKE_COMPILER_IS_GNUCC OR CMAKE_COMPILER_IS_GNUCXX)
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wall -Werror")
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wall -Werror")
endif()

if(USE_LOCAL_HIDAPI)
	list(APPEND lib_SRCS ${HIDAPI_SOURCES})
else()
	find_package(HIDAPI REQUIRED)
endif()

if(UNIX)
	execute_process(COMMAND lua -e "print(package.cpath:match(\".*;(.*)/%?.so;.*\"))"
			OUTPUT_VARIABLE LUA_PACKAGE_CPATH
			OUTPUT_STRIP_TRAILING_WHITESPACE)
endif()

if(NOT LUA_PACKAGE_CPATH)
	set(LUA_PACKAGE_CPATH lua)
endif()

add_library(luahidapi MODULE ${lib_SRCS})
set_target_properties(luahidapi PROPERTIES PREFIX "")
target_link_libraries(luahidapi ${LUA_LIBRARY} ${HIDAPI_LIBRARIES})
include_directories(${LUA_INCLUDE_DIR} ${HIDAPI_INCLUDE_DIRS})

install(
	TARGETS
		luahidapi
	DESTINATION
		${LUA_PACKAGE_CPATH}
	COMPONENT
		lua
)

install(
	FILES
		${CMAKE_SOURCE_DIR}/doc/example.lua
	DESTINATION
		lua
	COMPONENT
		lua
)
