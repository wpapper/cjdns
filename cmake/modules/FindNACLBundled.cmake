# You may redistribute this program and/or modify it under the terms of
# the GNU General Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
cmake_minimum_required(VERSION 2.8.2)

if(NOT NACL_FOUND)
    message("bundled version of cnacl compiled and used")
    include(ExternalProject)

    # Without this, the build doesn't happen until link time.
    include_directories(${NACL_USE_FILES})

    # the name of the tag
    set(tag "cnacl-exp-1380755260.tar.gz")

    # this is useless but it suppresses a warning
    set(md5 "5902402deb7756253ea27f1a53a26c42")

    # Configure cnacl
    set(cNaClConfig "
        add_definitions(\"-fPIC -O2 -fomit-frame-pointer\")
        set(MY_CMAKE_ASM_FLAGS \"-fPIC\")
        set(CMAKE_ASM_COMPILER \"\${CMAKE_C_COMPILER}\")
    ")

    if (NEON)
        set(cNaClConfig "${cNaClConfig}
            set(CMAKE_REQUIRED_FLAGS \"\${CMAKE_REQUIRED_FLAGS} -mfpu=neon\")
        ")
    endif ()

    file(WRITE ${CMAKE_BINARY_DIR}/cNaClConfig.cmake "${cNaClConfig}")
    set(cmakeArgs "-DCNACL_CONFIG_SCRIPT=${CMAKE_BINARY_DIR}/cNaClConfig.cmake")

    if (CMAKE_TOOLCHAIN_FILE)
        get_filename_component(toolchainFilePath "${CMAKE_TOOLCHAIN_FILE}" REALPATH)
        list(APPEND cmakeArgs "-DCMAKE_TOOLCHAIN_FILE=${toolchainFilePath}")
    endif()

    set(file ${CMAKE_BINARY_DIR}/nacl_ep-prefix/src/${tag})
    set(AssertSHA256 ${CMAKE_SOURCE_DIR}/cmake/modules/AssertSHA256.cmake)
    set(check ${CMAKE_COMMAND} -DFILE=${file} -DEXPECTED=${hash} -P ${AssertSHA256})

    set(url "${CMAKE_SOURCE_DIR}/cmake/externals/${tag}")
    if(NOT EXISTS "${url}")
        set(url ${CMAKE_BINARY_DIR}/nacl_ep-prefix/src/${tag})
    endif()
    file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/nacl_build")
    ExternalProject_Add(nacl_ep
        URL ${url}
        URL_MD5 ${md5}
        SOURCE_DIR "${CMAKE_BINARY_DIR}/nacl"
        BINARY_DIR "${CMAKE_BINARY_DIR}/nacl_build"
        CMAKE_ARGS ${cmakeArgs}
        INSTALL_COMMAND ""
        UPDATE_COMMAND ""
        PATCH_COMMAND ""
    )

    add_custom_command(
        OUTPUT ${CMAKE_BINARY_DIR}/nacl/build/nacl_test.out
        COMMAND ${CMAKE_COMMAND} -P ${CMAKE_SOURCE_DIR}/cmake/modules/TestNACL.cmake
    )
    add_custom_target(nacl_test DEPENDS ${CMAKE_BINARY_DIR}/nacl/build/nacl_test.out)
    add_dependencies(nacl_test nacl_ep)

    # The source of this uglyness is a limit on adding dependencies to imported libraries.
    # see: http://www.cmake.org/Bug/print_bug_page.php?bug_id=10395
    # It's fixed in cmake 2.8.4 but it would be nice to continue supporting 2.8.2 and 2.8.3
    if(NOT EXISTS ${CMAKE_BINARY_DIR}/DoNothing.c)
        file(WRITE ${CMAKE_BINARY_DIR}/DoNothing.c "int DoNothing() { return 0; }\n")
    endif()
    add_library(nacl_test_dependency ${CMAKE_BINARY_DIR}/DoNothing.c)
    add_dependencies(nacl_test_dependency nacl_test)


    add_library(nacl STATIC IMPORTED)
    set_property(TARGET nacl
        PROPERTY IMPORTED_LOCATION ${CMAKE_BINARY_DIR}/nacl_build/libnacl.a)

    set(NACL_INCLUDE_DIRS "${CMAKE_BINARY_DIR}/nacl_build/include/")
    set(NACL_LIBRARIES nacl nacl_test_dependency)
    set(NACL_FOUND TRUE)

endif()
