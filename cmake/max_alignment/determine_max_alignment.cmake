
set(BIN "${CMAKE_BINARY_DIR}/determine_max_alignment.bin")

try_compile(ALIGNMAX_COMPILED
  ${CMAKE_BINARY_DIR}
  SOURCES ${CMAKE_CURRENT_SOURCE_DIR}/cmake/max_alignment/determine_max_alignment.cpp
  CMAKE_FLAGS ${${CMAKE_CXX_FLAGS}}
              # Ignore unused flags
              "--no-warn-unused-cli"
  COMPILE_DEFINITIONS ${COMPILE_DEFINITIONS}
  COPY_FILE "${BIN}"
  COPY_FILE_ERROR copy_error
  OUTPUT_VARIABLE OUTPUT
)

if (ALIGNMAX_COMPILED AND NOT copy_error)
   file(STRINGS "${BIN}" data REGEX "__maxalign__\\[[^]*\\]")

   if (data MATCHES "__maxalign__\\[0*([^]]*)\\]")
       set(MAX_ALIGNMENT "${CMAKE_MATCH_1}" CACHE INTERNAL "")
   endif()
endif()

if (NOT MAX_ALIGNMENT)
   message(FATAL_ERROR "Could not determine maximum alignment")
endif()
