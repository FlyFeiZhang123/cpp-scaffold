cmake_minimum_required(VERSION 3.20)

set(PROJECT_NAME mymuduo)
set(LIB_NAME ${PROJECT_NAME}_lib)     # 库名
set(EXECUTABLE_NAME mymuduo_exe)   # 可执行文件名
set(EXECUTABLE_SRC "main.cpp" CACHE STRING "Source file for the executable (relative to example/)")

project(${PROJECT_NAME} LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# ===== 1. 选项 =====
option(ENABLE_ASAN "Enable AddressSanitizer" ON)
option(ENABLE_TSAN "Enable ThreadSanitizer" OFF)
option(ENABLE_UBSAN "Enable UndefinedBehaviorSanitizer" OFF)
option(USE_FOR_VALGRIND "Build with Valgrind-compatible debug info" OFF)
option(ENABLE_UFTRACE "Enable uftrace" OFF)
set(INSTALL_GLOBAL OFF)

if(ENABLE_ASAN AND ENABLE_TSAN)
  message(FATAL_ERROR "ASan and TSan cannot be enabled simultaneously!")
endif()

# ===== 2. 依赖 =====
# set(MY_BT_WS_ROOT "/root/my_behavior_tree")
# list(APPEND CMAKE_PREFIX_PATH "${MY_BT_WS_ROOT}/install")
# find_package(behaviortree_cpp REQUIRED)

# git submodule add xxx ./third_party/muduo    # 命令行上执行,看菜鸟，我这里把放置位置写道/third_party/muduo下，具体可以自己改
# add_subdirectory(third_party/muduo muduo_build) #这里把编译好的放入/build(这个是看你的编译目录名)/mduo_build
# add_library(Muduo::Base ALIAS muduo_base) #为了防冲突，可以做一个别名，不过一般不用
# target_link_libraries(${LIB_NAME} muduo_net muduo_base) #具体库自己选,正常第三方（非conan2集成）库就这么多步骤
# target_include_directories(${LIB_NAME} PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/third_party/muduo/include)
# muduo这个库比较老，光target_libraries不够，还需要这个，但是现在比较规范的一般不需要这个，具体看具体库的CMakeLists.txt规则

file(GLOB_RECURSE SOURCES CONFIGURE_DEPENDS "src/*.cpp") #从这里触发增量管理，不需要重新编译了，大多数时候效率更高

# ===== 3. 创建库 =====
# PRIVATE：头文件路径只对当前目标（${LIB_NAME}）的内部源文件（.cpp）生效，不会传递给链接 ${LIB_NAME} 的其他目标（如 test_exe）。
# 如果你的公共头文件（include/test.h）中包含了 muduo 头文件，那么 test_exe 在编译时（因为它包含了 test.h）仍然会找不到 muduo 头文件，导致编译错误。
# PUBLIC：头文件路径不仅对当前目标的源文件生效，还会传递给所有链接此目标的下游目标。这样 test_exe 也能自动获得 muduo 的头文件搜索路径。
# INTERFACE：仅用于传递头文件路径给下游目标，当前目标自身的源文件不包含（适用于纯头文件库）。这里不适用。
add_library(${LIB_NAME} ${SOURCES})
target_include_directories(${LIB_NAME} PUBLIC include/)   # 库的头文件公开给链接者，这里如果想要让这个传递给test,需要link_libraries的时候用PUBLIC

# ===== 4. 创建可执行文件（示例程序）=====
add_executable(${EXECUTABLE_NAME} example/${EXECUTABLE_SRC})   # 假设示例入口在 example/main.cpp
target_include_directories(${EXECUTABLE_NAME} PRIVATE include/)
target_link_libraries(${EXECUTABLE_NAME} PRIVATE ${LIB_NAME} )
# target_link_libraries(${EXECUTABLE_NAME} PRIVATE behaviortree_cpp::behaviortree_cpp)

# ===== 5. 应用编译/链接选项到库和可执行文件 =====
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
  # 调试信息
  if(USE_FOR_VALGRIND)
    target_compile_options(${LIB_NAME} PRIVATE -gdwarf-4)
    target_compile_options(${EXECUTABLE_NAME} PRIVATE -gdwarf-4)
  else()
    # 默认调试信息（普通 debug）
    target_compile_options(${LIB_NAME} PRIVATE -gdwarf-5)
    target_compile_options(${EXECUTABLE_NAME} PRIVATE -gdwarf-5)
  endif()

  # Sanitizers（同时应用到库和可执行文件）
  if(ENABLE_ASAN)
    target_compile_options(${LIB_NAME} PRIVATE -fsanitize=address -fno-omit-frame-pointer -O1)
    target_link_options(${LIB_NAME} PRIVATE -fsanitize=address)
    target_compile_options(${EXECUTABLE_NAME} PRIVATE -fsanitize=address -fno-omit-frame-pointer -O1)
    target_link_options(${EXECUTABLE_NAME} PRIVATE -fsanitize=address)
  elseif(ENABLE_TSAN)
    target_compile_options(${LIB_NAME} PRIVATE -fsanitize=thread -fno-omit-frame-pointer -O1)
    target_link_options(${LIB_NAME} PRIVATE -fsanitize=thread)
    target_compile_options(${EXECUTABLE_NAME} PRIVATE -fsanitize=thread -fno-omit-frame-pointer -O1)
    target_link_options(${EXECUTABLE_NAME} PRIVATE -fsanitize=thread)
    #setarch $(uname -m) -R ./build-debug-tsan/test_exe  通过这个操作关闭ASLR（地址随机化）
  endif()

  if(ENABLE_UBSAN)
    target_compile_options(${LIB_NAME} PRIVATE -fsanitize=undefined -fno-sanitize-recover=all)
    target_link_options(${LIB_NAME} PRIVATE -fsanitize=undefined)
    target_compile_options(${EXECUTABLE_NAME} PRIVATE -fsanitize=undefined -fno-sanitize-recover=all)
    target_link_options(${EXECUTABLE_NAME} PRIVATE -fsanitize=undefined)
  endif()
endif()

# 如果开启 INSTALL_GLOBAL，则将库和头文件安装到系统目录
if(INSTALL_GLOBAL)
  install(TARGETS ${LIB_NAME}
        LIBRARY DESTINATION /usr/lib
    )
  install(DIRECTORY include/
        DESTINATION /usr/include/${LIB_NAME}
        FILES_MATCHING PATTERN "*.h"
    )
  message(STATUS "安装已启用：库 → /usr/lib，头文件 → /usr/include/${LIB_NAME}")
endif()

# ===== 测试 =====
option(BUILD_TESTS "Build tests" ON)
if(BUILD_TESTS)
  enable_testing()
  add_subdirectory(tests)
endif()
