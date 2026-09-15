# Declare a compatibility range rather than a bare minimum: the lower bound
# keeps older consumers working, while the upper bound tells CMake 3.31+/4.x
# that this project has been checked against current policies.  A bare
# "VERSION 2.8" is rejected outright by CMake 4.0 and newer.
cmake_minimum_required(VERSION 3.10...3.31)
project(METIS C)

set(METIS_PATH "${CMAKE_CURRENT_SOURCE_DIR}" CACHE PATH "path to METIS")
SET (METIS_LIBRARY "metis" CACHE INTERNAL STRING)

option(METIS_BUILD_PROGRAMS
       "Build the standalone METIS command line programs (pmetis, kmetis, ...)" OFF)

include_directories(${CMAKE_CURRENT_SOURCE_DIR}/Lib)

file(GLOB METIS_SOURCES Lib/*.c)

file(GLOB METIS_HEADERS Lib/*.h)

add_library(${METIS_LIBRARY} STATIC ${METIS_SOURCES} ${METIS_HEADERS})

# Propagate the header location to anything that links against metis, so
# consumers using add_subdirectory()/target_link_libraries() no longer have to
# reach into the source tree themselves.
target_include_directories(${METIS_LIBRARY} PUBLIC
  $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/Lib>)

if(UNIX)
  target_link_libraries(${METIS_LIBRARY} PUBLIC m)
endif()

# Off by default so that existing consumers who add_subdirectory() this project
# keep getting exactly one target.  CI turns it on to smoke test the library
# end to end against the sample graphs in Graphs/.
if(METIS_BUILD_PROGRAMS)
  # Programs/io.c is a stale duplicate of Lib/io.c (which additionally provides
  # partnmesh()), so the programs link the library copy instead of recompiling it.
  foreach(prog pmetis kmetis mesh2dual mesh2nodal partdmesh partnmesh graphchk)
    add_executable(${prog} Programs/${prog}.c)
    target_link_libraries(${prog} PRIVATE ${METIS_LIBRARY})
  endforeach()
  foreach(prog oemetis onmetis)
    add_executable(${prog} Programs/${prog}.c Programs/smbfactor.c)
    target_link_libraries(${prog} PRIVATE ${METIS_LIBRARY})
  endforeach()
endif()
