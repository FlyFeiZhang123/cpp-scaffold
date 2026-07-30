#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include <doctest/doctest.h>

// 一个待测函数示例
int add(int a, int b) { return a + b; }

TEST_CASE("addition works") {
    CHECK(add(2, 3) == 5);
}