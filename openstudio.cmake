CMAKE_MINIMUM_REQUIRED( VERSION 2.8 )
##############################################################################
# OpenStudio CTest script for build and test automation
# This is the main CTest script for the Openstudio Nightly and Continuous
# builds (and a few others). This script includes many variables that need to
# be configured using Ruby and erb. The Ruby scripts in the repository are
# used to control when and how this script runs, especially in the case of
# continuous builds.
##############################################################################
# Configuration variables to be set by the managing ruby script
#
# Path configuration for build and source directories
SET( CTEST_SOURCE_DIRECTORY "<%=source_directory%>" )
SET( CTEST_BINARY_DIRECTORY "<%=binary_directory%>" )
SET( CTEST_RUBY_SCRIPT_DIRECTORY "<%=ruby_directory%>" )
SET( OPENSTUDIOCORE_DIR "${CTEST_BINARY_DIRECTORY}OpenStudioCore-prefix/src/OpenStudioCore-build" )

SET( CTEST_ENVIRONMENT "DISPLAY=<%=display%>" )
SET( generator "<%=generator%>" )
SET( model "<%=model%>" )
SET( svn_url "<%=svn_url%>" )
SET( username "<%=username%>" )
SET( win_version "<%=win_version%>" )

SET( build_csharp <%=build_csharp%> )
SET( build_with_dakota <%=build_with_dakota%> )
SET( clean_build <%=clean_build%> )
SET( submit_package <%=submit_package%> )
SET( submit_to_dash <%=submit_to_dash%> )
SET( run_tests <%=runTests%> )

SET( jobs "<%=jobs%>" )
SET( site "<%=site%>" )
SET( build_name_modifier "<%=build_name_modifier%>" )
SET( openstudio_build_dir "<%=openstudio_build_dir%>" )

SET( major_version "<%=major_version%>" )
SET( minor_version "<%=minor_version%>" )
SET( patch_version "<%=patch_version%>" )



##############################################################################
# Project, Site, and Build name configuration
SET( CTEST_SITE "${site}" )
SET( CTEST_BUILD_NAME "${CMAKE_SYSTEM_NAME}${build_name_modifier}" )

IF( ${build_csharp} )
  SET( CTEST_BUILD_NAME "${CTEST_BUILD_NAME}-csharp" )
ENDIF()

###############################################################################
# Configure for CDash
SET( JOB_BUILDTYPE "${model}" )
SET( CTEST_PROJECT_NAME "OpenStudio" )
SET( CTEST_NIGHTLY_START_TIME "00:00:00 <%=tz%>" )
SET( CTEST_DROP_METHOD "http" )
SET( CTEST_DROP_SITE "my.cdash.org" )
SET( CTEST_DROP_LOCATION "/submit.php?project=OpenStudio" )
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

###############################################################################
# Build type
# Configures CTest to use the correct build command depending on platform

SET( sln "OpenStudio.sln" )
IF( ${model} STREQUAL "Regression" )
  SET( sln "OpenStudioRegression.sln" )
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
      SET(submit_package FALSE)
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
    CPACK_PACKAGE_INSTALL_DIRECTORY:STRING=OpenStudio ${major_version}.${minor_version}.${patch_version}.${REPO_VERSION}
    CPACK_PACKAGE_INSTALL_REGISTRY_KEY:STRING=OpenStudio ${major_version}.${minor_version}.${patch_version}.${REPO_VERSION}
    CPACK_NSIS_DISPLAY_NAME:STRING=OpenStudio ${major_version}.${minor_version}.${patch_version}.${REPO_VERSION}
    CPACK_NSIS_PACKAGE_NAME:STRING=OpenStudio ${major_version}.${minor_version}.${patch_version}.${REPO_VERSION}
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

ELSEIF( ${model} STREQUAL "Regression" )
  SET( INITIAL_CACHE "
    BUILD_TESTING:BOOL=ON
    BUILD_PACKAGE:BOOL=OFF
    CMAKE_VERSION_BUILD:STRING=${REPO_VERSION}
    OPENSTUDIO_BUILD_DIR:STRING=${openstudio_build_dir}
    BUILD_ENERGYPLUS_TESTS:BOOL=<%=run_energyplus_tests%>
    BUILD_MODEL_TESTS:BOOL=<%=run_model_tests%>
    BUILD_PROJECT_TESTS:BOOL=<%=run_project_tests%>
    BUILD_RUBY_TESTS:BOOL=<%=run_ruby_tests%>
    BUILD_RUNMANAGER_TESTS:BOOL=<%=run_runmanager_tests%>
    BUILD_RULESENGINE_TESTS:BOOL=<%=run_rulesengine_tests%>
    BUILD_SQUISH_SKETCHUP_TESTS:BOOL=<%=run_squish_sketchup_tests%>
    BUILD_SQUISH_QT_TESTS:BOOL=<%=run_squish_qt_tests%>
    MSVC_IS_EXPRESS:BOOL=${MSVC_IS_EXPRESS}
    CTEST_TESTING_TIMEOUT:STRING=3600
    DART_TESTING_TIMEOUT:STRING=3600
    SITE:STRING=${site}
  ")
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
  SET(submit_package FALSE)
ENDIF()

###############################################################################
# Build
message("CTest: Building ${model}")
ctest_build( BUILD "${CTEST_BINARY_DIRECTORY}" NUMBER_ERRORS res )
IF( NOT res EQUAL 0 )
  # Build failed, do not submit a new package
  SET(submit_package FALSE)
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

###############################################################################
# Use scp to copy the installer to the download location
IF( ${submit_package} )
  message("Uploading package..")
  IF( APPLE )
    FILE(GLOB PKG "${CTEST_BINARY_DIRECTORY}/OpenStudio-*-Darwin.dmg")
    # EXECUTE_PROCESS(COMMAND scp ${PKG} ${username}@cbr.nrel.gov:/srv/cbr/htdocs/openstudio/private/packages/)
  ELSEIF( WIN32 )
    # Only submit the version from the windows 7 build
    IF ( ${site} STREQUAL "w028t-001" )  
      FILE(GLOB PKG "${CTEST_BINARY_DIRECTORY}/OpenStudio-*-Windows.exe")
      EXECUTE_PROCESS(COMMAND ruby ${CTEST_RUBY_SCRIPT_DIRECTORY}/submit_to_svn.rb ${PKG})
    ENDIF()
  ELSEIF( UNIX )
    FILE(GLOB PKG "${CTEST_BINARY_DIRECTORY}/OpenStudio-*-Linux.sh")
    # EXECUTE_PROCESS(COMMAND scp ${PKG} ${username}@cbr.nrel.gov:/srv/cbr/htdocs/openstudio/private/packages/)
  ENDIF()
ENDIF()

## TODO Need to clean out directory
