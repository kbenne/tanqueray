CMAKE_MINIMUM_REQUIRED( VERSION 2.8 )
##############################################################################
# OpenStudio CTest script for build and test automation
# This is the main CTest script for the Openstudio Nightly and Continuous
# builds (and a few others). This script includes many variables that need to
# be configured using Ruby and erb. The Ruby scripts in the repository are
# used to control when and how this script runs, especially in the case of
# continuous builds.
##############################################################################

SET( build_csharp false )
SET( build_with_dakota false )
SET( clean_build true )
SET( submit_to_dash true )
SET( run_tests true )
SET( model "Nightly" )

SET( OPENSTUDIOCORE_DIR "${CTEST_BINARY_DIRECTORY}OpenStudioCore-prefix/src/OpenStudioCore-build" )

###############################################################################
# Configure for CDash
SET( JOB_BUILDTYPE "${model}" )
SET( CTEST_PROJECT_NAME "OpenStudio" )
SET( CTEST_NIGHTLY_START_TIME "00:00:00 <%=tz%>" )
SET( CTEST_DROP_SITE_CDASH TRUE )

###############################################################################
# Set the package type
# Can only have one package type
SET( UNIX_PACKAGE_NAME "all" )
SET( MSVC_PACKAGE_NAME "ALL_BUILD" )
IF( ${model} STREQUAL "Nightly" OR ${model} STREQUAL "Continuous" )
  SET( UNIX_PACKAGE_NAME "package" )
  SET( MSVC_PACKAGE_NAME "PACKAGE" )
ENDIF()

#### Linux and Mac
IF( ${generator} STREQUAL "Unix Makefiles" )
  SET( CTEST_CMAKE_GENERATOR "Unix Makefiles" )
  SET( CTEST_BUILD_COMMAND "make ${UNIX_PACKAGE_NAME} -j${jobs}" )
#### Windows - ${win_version} needs to be set if building on windows 7
# Visual Studio 2008
ELSEIF( ${generator} STREQUAL "Visual Studio 9 2008" )
  SET( CTEST_CMAKE_GENERATOR "Visual Studio 9 2008" )
  SET( MSVC_IS_EXPRESS "OFF" )
  IF( ${win_version} STREQUAL "7" )
    SET( CTEST_BUILD_COMMAND "\"C:\\Program Files (x86)\\Microsoft Visual Studio 9.0\\Common7\\IDE\\devenv.com\" ${sln} /build Release /project ${MSVC_PACKAGE_NAME}" ) 
  ELSE()
    SET( CTEST_BUILD_COMMAND "\"C:\\Program Files\\Microsoft Visual Studio 9.0\\Common7\\IDE\\devenv.com\" ${sln} /build Release /project ${MSVC_PACKAGE_NAME}" ) 
  ENDIF()
# Visual Studio 2008 Express
ELSEIF( ${generator} STREQUAL "Visual Studio 9 2008 Express" )
  SET( CTEST_CMAKE_GENERATOR "Visual Studio 9 2008" )
  SET( MSVC_IS_EXPRESS "ON" )
  IF( ${win_version} STREQUAL "7" )
    SET( CTEST_BUILD_COMMAND "\"C:\\Program Files (x86)\\Microsoft Visual Studio 9.0\\Common7\\IDE\\vcexpress.exe\" ${sln} /build Release /project ${MSVC_PACKAGE_NAME}" ) 
  ELSE()
    SET( CTEST_BUILD_COMMAND "\"C:\\Program Files\\Microsoft Visual Studio 9.0\\Common7\\IDE\\vcexpress.exe\" ${sln} /build Release /project ${MSVC_PACKAGE_NAME}" ) 
  ENDIF()
# Visual Studio 2010
ELSEIF( ${generator} STREQUAL "Visual Studio 10" )
  SET( CTEST_CMAKE_GENERATOR "Visual Studio 10" )
  SET( MSVC_IS_EXPRESS "OFF" )
  SET( CTEST_BUILD_COMMAND "\"C:\\Program Files\\Microsoft Visual Studio 10.0\\Common7\\IDE\\devenv.com\" ${sln} /build Release /project ${MSVC_PACKAGE_NAME}" )
# Visual Studio 2010 Express
ELSEIF( ${generator} STREQUAL "Visual Studio 10 Express" )
  SET( CTEST_CMAKE_GENERATOR "Visual Studio 10" )
  SET( MSVC_IS_EXPRESS "ON" )
  SET( CTEST_BUILD_COMMAND "\"C:\\Program Files\\Microsoft Visual Studio 10.0\\Common7\\IDE\\vcexpress.exe\" ${sln} /build Release /project ${MSVC_PACKAGE_NAME}" )  
ENDIF()

###############################################################################
# Start with a completely empty binary directory?
IF( ${clean_build} )
  CTEST_EMPTY_BINARY_DIRECTORY( "${CTEST_BINARY_DIRECTORY}" )
ENDIF()


###############################################################################
# SVN Commands
IF(NOT EXISTS "${CTEST_SOURCE_DIRECTORY}")
  message("SVN: Initial checkout (No source directory)")
  SET( CTEST_CHECKOUT_COMMAND "svn co ${svn_url} --username ${username} --non-interactive ${CTEST_SOURCE_DIRECTORY}" )
ENDIF()
SET( CTEST_UPDATE_COMMAND "svn" )


###############################################################################
# Start
message("CTest: Starting ${model} in ${CTEST_BINARY_DIRECTORY}")
ctest_start( "${model}" TRACK ${model} )

###############################################################################
# Update
IF( ${model} STREQUAL "Nightly" )
  message("CTest: Reverting Nightly repository to previous day")
ELSE()
  message("CTest: Updating respository for ${model}")
ENDIF()
ctest_update( RETURN_VALUE res )
IF( res EQUAL -1 )
  # Attempt updates.  On failure, do not submit a new package
  message("CTest: Update failed.. Retrying 1")
  ctest_update( RETURN_VALUE res )
  IF( res EQUAL -1 )
    message("CTest: Update failed.. Retrying 2")
    ctest_update( RETURN_VALUE res )
    IF( res EQUAL -1 )
      message("CTest: Final update failed..")
    ENDIF()
  ENDIF()
ENDIF()


###############################################################################
# Find the svn revision
find_program( SVNVERSION svnversion )
execute_process(COMMAND ${SVNVERSION} ${CTEST_SOURCE_DIRECTORY} OUTPUT_VARIABLE REPO_VERSION)
message("CTest: Repository at r${REPO_VERSION}")

###############################################################################

# Set the initial cache and other model-specific variables
IF( ${model} STREQUAL "Nightly" OR ${model} STREQUAL "Continuous" )
  SET( INITIAL_CACHE "
    BUILD_CSHARP_BINDINGS:BOOL=${build_csharp}
    BUILD_DOCUMENTATION:BOOL=OFF
    BUILD_PACKAGE:BOOL=ON
    BUILD_RUBY_GEM:BOOL=OFF
    BUILD_SIMXML:BOOL=OFF
    BUILD_TESTING:BOOL=ON
    BUILD_WITH_DAKOTA:BOOL=${build_with_dakota}
    CMAKE_VERSION_BUILD:STRING=${REPO_VERSION}
    MSVC_IS_EXPRESS:BOOL=${MSVC_IS_EXPRESS}
    USE_PCH:BOOL=OFF
    SITE:STRING=${site}
  ")

ELSEIF( ${model} STREQUAL "Coverage" )
  SET( INITIAL_CACHE "
    BUILD_PACKAGE:BOOL=OFF
    BUILD_TESTING:BOOL=ON
    MSVC_IS_EXPRESS:BOOL=${MSVC_IS_EXPRESS}
    CMAKE_VERSION_BUILD:STRING=${REPO_VERSION}
    CMAKE_CXX_FLAGS:STRING=-g -O0 -Wall -W -Wshadow -Wunused-variable -Wunused-parameter -Wunused-function -Wunused -Wno-system-headers -Wno-deprecated -Woverloaded-virtual -Wwrite-strings -fprofile-arcs -ftest-coverage
    CMAKE_C_FLAGS:STRING=-g -O0 -Wall -W -fprofile-arcs -ftest-coverage
    CMAKE_EXE_LINKER_FLAGS:STRING=-fprofile-arcs -ftest-coverage
    SITE:STRING=${site}
  ")

  # use gcov
  find_program( GCOV_COMMAND "gcov" )
  IF ( GCOV_COMMAND )
    SET ( CTEST_COVERAGE_COMMAND "${GCOV_COMMAND}" )
  ELSE()
    MESSAGE( FATAL_ERROR "Coverage: gcov not found" )
  ENDIF()

ELSEIF( ${model} STREQUAL "MemoryCheck" )
  SET( INITIAL_CACHE "
    BUILD_TESTING:BOOL=ON
    BUILD_PACKAGE:BOOL=OFF
    CMAKE_VERSION_BUILD:STRING=${REPO_VERSION}
    MSVC_IS_EXPRESS:BOOL=${MSVC_IS_EXPRESS}
    SITE:STRING=${site}
  ")

  # use valgrind
  find_program( VALGRIND_COMMAND "valgrind" )
  IF ( VALGRIND_COMMAND )
    SET ( CTEST_MEMORYCHECK_COMMAND "${VALGRIND_COMMAND}" )
  ELSE()
    MESSAGE( FATAL_ERROR "MemoryCheck: valgrind not found" )
  ENDIF()

  # http://valgrind.org/docs/manual/faq.html#faq.deflost
  SET (CTEST_MEMORYCHECK_COMMAND_OPTIONS   "--num-callers=25 --show-reachable=no")

  # setting environment variables for stl strings in valgrind
  # http://valgrind.org/docs/manual/faq.html#faq.reports
  SET( EVN{GLIBCPP_FORCE_NEW} 1) # GCC 3.2.2 and later
  SET( EVN{GLIBCXX_FORCE_NEW} 1) # GCC 3.4 and later

ELSE()
  message( FATAL_ERROR "Unknown model: ${model}")
ENDIF()

# Mac specific cache stuff
IF( APPLE )
  SET( INITIAL_CACHE "
     ${INITIAL_CACHE}
     CMAKE_OSX_DEPLOYMENT_TARGET:STRING=10.6
     CMAKE_OSX_SYSROOT:STRING=/Developer/SDKs/MacOSX10.6.sdk
     CMAKE_OSX_ARCHITECTURES:STRING=i386;x86_64
  ")
ENDIF()

###############################################################################
# If binary directory does not exist, we create it and add the initial cache
# If it does exist we just update the svn version
IF( NOT EXISTS "${CTEST_BINARY_DIRECTORY}/CMakeCache.txt")
  # Write initial cache.
  file(WRITE "${CTEST_BINARY_DIRECTORY}/CMakeCache.txt" "${INITIAL_CACHE}")
ELSE()
  file(READ "${CTEST_BINARY_DIRECTORY}/CMakeCache.txt" CACHE_TEXT)
  string(REGEX REPLACE "CMAKE_VERSION_BUILD:STRING=[A-Za-z0-9]*"
        "CMAKE_VERSION_BUILD:STRING=${REPO_VERSION}"
        NEW_CACHE_TEXT "${CACHE_TEXT}" )
  file(WRITE "${CTEST_BINARY_DIRECTORY}/CMakeCache.txt" "${NEW_CACHE_TEXT}")
ENDIF()

###############################################################################
# If this is a continuous build and there were no files updated then we return
IF( ${model} STREQUAL "Continuous" )
  IF( res LESS 1 AND NOT clean_build )
    message("CTest: No new files to build")
    return()
  ENDIF()
ENDIF()

###############################################################################
# Configure
message("CTest: Configuring ${model}")
ctest_configure( BUILD "${CTEST_BINARY_DIRECTORY}" SOURCE "${CTEST_SOURCE_DIRECTORY}" RETURN_VALUE res )
IF( NOT res EQUAL 0 )
  # Configure failed, do not submit a new package
  message("CTest: Configure failed")
ENDIF()

###############################################################################
# Build
message("CTest: Building ${model}")
ctest_build( BUILD "${CTEST_BINARY_DIRECTORY}" NUMBER_ERRORS res )
IF( NOT res EQUAL 0 )
  # Build failed, do not submit a new package
ELSE()
  message("CTest: Build succeeded")
ENDIF()

###############################################################################
# Test
IF( ${run_tests} )
  message("CTest: Testing ${model} on ${OPENSTUDIOCORE_DIR}")
  ctest_test( BUILD "${OPENSTUDIOCORE_DIR}" RETURN_VALUE res )
ENDIF()

###############################################################################
# Coverage
IF( ${model} STREQUAL "Coverage" )
  message("CTest: Starting ${model}")
  ctest_coverage( BUILD "${CTEST_BINARY_DIRECTORY}" RETURN_VALUE res )
  IF( NOT res EQUAL 0 )
    message("CTest: Coverage failed")
  ELSE()
    message("CTest: Coverage succeeded")
  ENDIF()
ENDIF()

###############################################################################
# MemoryCheck
IF( ${model} STREQUAL "MemoryCheck" )
  message("CTest: Starting ${model}")
  ctest_memcheck( BUILD "${CTEST_BINARY_DIRECTORY}" RETURN_VALUE res )
  IF( NOT res EQUAL 0 )
    message("CTest: MemoryCheck failed")
  ELSE()
    message("CTest: MemoryCheck succeeded")
  ENDIF()
ENDIF()

###############################################################################
# Submit
IF( ${submit_to_dash} )
  message("CTest: Submitting results to CDash")
  ctest_submit( RETURN_VALUE res )
  IF( NOT res EQUAL 0 )
    message("CTest: Submission failed")
  ELSE()
    message("CTest: Submission succeeded")
  ENDIF()
ENDIF()

## TODO Need to clean out directory
