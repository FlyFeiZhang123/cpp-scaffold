#define DOCTEST_CONFIG_IMPLEMENT_WITH_MAIN
#include <doctest/doctest.h>

#include "calculator.h"

TEST_CASE("Calculator::add") {
    Calculator calc;
    CHECK(calc.add(2, 3) == 5);
    CHECK(calc.add(-1, 1) == 0);
}

TEST_CASE("Calculator::sub") {
    Calculator calc;
    CHECK(calc.sub(5, 3) == 2);
    CHECK(calc.sub(1, 1) == 0);
}

TEST_CASE("Calculator::mul") {
    Calculator calc;
    CHECK(calc.mul(2, 3) == 6);
    CHECK(calc.mul(0, 5) == 0);
}

TEST_CASE("Calculator::div") {
    Calculator calc;
    CHECK(calc.div(6, 3) == 2);
    CHECK(calc.div(5, 2) == 2);
    CHECK_THROWS_AS(calc.div(1, 0), std::invalid_argument);
}
