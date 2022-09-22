###############################################################################
# Option for using system Eigen or GTSAM-bundled Eigen
# Default: Use system's Eigen if found automatically:
find_package(Eigen3 QUIET)
set(USE_SYSTEM_EIGEN_INITIAL_VALUE ${Eigen3_FOUND})
option(GTSAM_USE_SYSTEM_EIGEN "Find and use system-installed Eigen. If 'off', use the one bundled with GTSAM" ${USE_SYSTEM_EIGEN_INITIAL_VALUE})
unset(USE_SYSTEM_EIGEN_INITIAL_VALUE)

if(NOT GTSAM_USE_SYSTEM_EIGEN)
  # This option only makes sense if using the embedded copy of Eigen, it is
  # used to decide whether to *install* the "unsupported" module:
  option(GTSAM_WITH_EIGEN_UNSUPPORTED "Install Eigen's unsupported modules" OFF)
endif()

# Switch for using system Eigen or GTSAM-bundled Eigen
if(GTSAM_USE_SYSTEM_EIGEN)
    find_package(Eigen3 REQUIRED) # need to find again as REQUIRED

    # Use generic Eigen include paths e.g. <Eigen/Core>
    set(GTSAM_EIGEN_INCLUDE_FOR_INSTALL "${EIGEN3_INCLUDE_DIR}")

    # check if MKL is also enabled - can have one or the other, but not both!
    # Note: Eigen >= v3.2.5 includes our patches
    if(EIGEN_USE_MKL_ALL AND (EIGEN3_VERSION VERSION_LESS 3.2.5))
      message(FATAL_ERROR "MKL requires at least Eigen 3.2.5, and your system appears to have an older version. Disable GTSAM_USE_SYSTEM_EIGEN to use GTSAM's copy of Eigen, or disable GTSAM_WITH_EIGEN_MKL")
    endif()

    # Check for Eigen version which doesn't work with MKL
    # See http://eigen.tuxfamily.org/bz/show_bug.cgi?id=1527 for details.
    if(EIGEN_USE_MKL_ALL AND (EIGEN3_VERSION VERSION_EQUAL 3.3.4))
        message(FATAL_ERROR "MKL does not work with Eigen 3.3.4 because of a bug in Eigen. See http://eigen.tuxfamily.org/bz/show_bug.cgi?id=1527. Disable GTSAM_USE_SYSTEM_EIGEN to use GTSAM's copy of Eigen, disable GTSAM_WITH_EIGEN_MKL, or upgrade/patch your installation of Eigen.")
    endif()

    # The actual include directory (for BUILD cmake target interface):
    set(GTSAM_EIGEN_INCLUDE_FOR_BUILD "${EIGEN3_INCLUDE_DIR}")
else()
    # Use bundled Eigen include path.
    # Clear any variables set by FindEigen3
    if(EIGEN3_INCLUDE_DIR)
        set(EIGEN3_INCLUDE_DIR NOTFOUND CACHE STRING "" FORCE)
    endif()

    # set full path to be used by external projects
    # this will be added to GTSAM_INCLUDE_DIR by gtsam_extra.cmake.in
    set(GTSAM_EIGEN_INCLUDE_FOR_INSTALL "include/gtsam/3rdparty/Eigen/")

    # The actual include directory (for BUILD cmake target interface):
    set(GTSAM_EIGEN_INCLUDE_FOR_BUILD "${GTSAM_SOURCE_DIR}/gtsam/3rdparty/Eigen/")
endif()

# Detect Eigen version:
set(EIGEN_VER_H "${GTSAM_EIGEN_INCLUDE_FOR_BUILD}/Eigen/src/Core/util/Macros.h")
if (EXISTS ${EIGEN_VER_H})
    file(READ "${EIGEN_VER_H}" STR_EIGEN_VERSION)

    # Extract the Eigen version from the Macros.h file, lines "#define EIGEN_WORLD_VERSION  XX", etc...

    string(REGEX MATCH "EIGEN_WORLD_VERSION[ ]+[0-9]+" GTSAM_EIGEN_VERSION_WORLD "${STR_EIGEN_VERSION}")
    string(REGEX MATCH "[0-9]+" GTSAM_EIGEN_VERSION_WORLD "${GTSAM_EIGEN_VERSION_WORLD}")

    string(REGEX MATCH "EIGEN_MAJOR_VERSION[ ]+[0-9]+" GTSAM_EIGEN_VERSION_MAJOR "${STR_EIGEN_VERSION}")
    string(REGEX MATCH "[0-9]+" GTSAM_EIGEN_VERSION_MAJOR "${GTSAM_EIGEN_VERSION_MAJOR}")

    string(REGEX MATCH "EIGEN_MINOR_VERSION[ ]+[0-9]+" GTSAM_EIGEN_VERSION_MINOR "${STR_EIGEN_VERSION}")
    string(REGEX MATCH "[0-9]+" GTSAM_EIGEN_VERSION_MINOR "${GTSAM_EIGEN_VERSION_MINOR}")

    set(GTSAM_EIGEN_VERSION "${GTSAM_EIGEN_VERSION_WORLD}.${GTSAM_EIGEN_VERSION_MAJOR}.${GTSAM_EIGEN_VERSION_MINOR}")

    message(STATUS "Found Eigen version: ${GTSAM_EIGEN_VERSION}")
else()
    message(WARNING "Cannot determine Eigen version, missing file: `${EIGEN_VER_H}`")
endif ()

if (MSVC)
    if (BUILD_SHARED_LIBS)
        # mute eigen static assert to avoid errors in shared lib
        list_append_cache(GTSAM_COMPILE_DEFINITIONS_PUBLIC EIGEN_NO_STATIC_ASSERT)
    endif()
    list_append_cache(GTSAM_COMPILE_OPTIONS_PRIVATE "/wd4244") # Disable loss of precision which is thrown all over our Eigen
endif()


# Checking cxx standard explicitly activated in flags
string(REGEX MATCH "-std=(.*) " CXX_STANDARD_FLAG "${CMAKE_CXX_FLAGS}")
set(CXX_STANDARD_FLAG "${CMAKE_MATCH_1}" CACHE INTERNAL "")

# TODO: Check CXX standard detection, is this the proper way?
if(CXX_STANDARD_FLAG STREQUAL "c++17" OR CXX_STANDARD_FLAG STREQUAL "gnu++17" OR CXX_STANDARD EQUAL 17 OR CMAKE_CXX_STANDARD EQUAL 17)
    set(IS_CXX_STANDARD_17 TRUE)
endif ()

# Checking if c++17 is activated in flags or in the cmake CXX_STANDARD property
# Checking Eigen3 version greater or equal to 3.4
# On C++17, Eigen 3.4 and a modern compiler, new features where added to Eigen allowing auto-magic handling of alignment requirements.
if(NOT ( IS_CXX_STANDARD_17 AND (Eigen3_VERSION GREATER_EQUAL 3.4) ) )
    # If toolchain requirements are not met, Eigen cannot handle vectorization alignment automatically and there are code requirements to comply with,
    # (ex. adding EIGEN_MAKE_ALIGNED_OPERATOR_NEW on classes with Eigen members).
    # see https://eigen.tuxfamily.org/dox/group__TopicUnalignedArrayAssert.html

    # To ensure runtime safeness without code requirements, vectorization is tuned-down.
    # Static code alignment is set to the maximum reported by the platform (usually 16 bytes), while dynamic heap alignment
    # remains untouched. This effectively deactivates 32 and 64 bytes AVX over-alignment vectorization in 64bit systems.

    # Determining platform max alignment, see https://en.cppreference.com/w/cpp/types/max_align_t
    include(max_alignment/determine_max_alignment)

    # Setting maximum alignment
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -DEIGEN_MAX_STATIC_ALIGN_BYTES=${MAX_ALIGNMENT}")

    # Following line would deactivate vectorization and alignment completely, (only for debugging purposes)
    #set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -DEIGEN_DONT_VECTORIZE -DEIGEN_DONT_ALIGN -DEIGEN_UNALIGNED_VECTORIZE=0")

    message(STATUS "Setting Eigen3 maximum alignment, EIGEN_MAX_STATIC_ALIGN_BYTES=${MAX_ALIGNMENT} ")
endif ()
