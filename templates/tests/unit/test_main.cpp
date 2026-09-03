#include <gtest/gtest.h>

#include "calculator.h"

TEST(CalculatorTest, Add) {
    Calculator calc;
    EXPECT_EQ(calc.add(2, 3), 5);
    EXPECT_EQ(calc.add(-1, 1), 0);
}

TEST(CalculatorTest, Sub) {
    Calculator calc;
    EXPECT_EQ(calc.sub(5, 3), 2);
    EXPECT_EQ(calc.sub(1, 1), 0);
}

TEST(CalculatorTest, Mul) {
    Calculator calc;
    EXPECT_EQ(calc.mul(2, 3), 6);
    EXPECT_EQ(calc.mul(0, 5), 0);
}

TEST(CalculatorTest, Div) {
    Calculator calc;
    EXPECT_EQ(calc.div(6, 3), 2);
    EXPECT_EQ(calc.div(5, 2), 2);
    EXPECT_THROW(calc.div(1, 0), std::invalid_argument);
}
