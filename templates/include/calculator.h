#pragma once

#include <stdexcept>

class Calculator {
public:
    int add(int a, int b) const { return a + b; }
    int sub(int a, int b) const { return a - b; }
    int mul(int a, int b) const { return a * b; }

    int div(int a, int b) const {
        if (b == 0) throw std::invalid_argument("division by zero");
        return a / b;
    }
};
