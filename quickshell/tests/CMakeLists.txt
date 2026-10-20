cmake_minimum_required(VERSION 3.20)
project(quickshell_clock_check LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_AUTOMOC ON)
find_package(Qt6 REQUIRED COMPONENTS Qml)

set(QUICKSHELL_SOURCE_DIR "$ENV{HOME}/github/quickshell" CACHE PATH "Patched Quickshell checkout")
add_executable(clock-check
    clock-native.cpp
    "${QUICKSHELL_SOURCE_DIR}/src/core/clock.cpp"
    "${QUICKSHELL_SOURCE_DIR}/src/core/clock.hpp"
)
target_include_directories(clock-check PRIVATE "${QUICKSHELL_SOURCE_DIR}/src/core")
target_link_libraries(clock-check PRIVATE Qt6::Qml)
target_link_options(clock-check PRIVATE -Wl,--wrap=read)
