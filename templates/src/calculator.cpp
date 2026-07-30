#include "calculator.h"
#include <stdexcept>

namespace __PROJECT_NAME__ {

int Calculator::add(int a, int b) const { return a + b; }

int Calculator::sub(int a, int b) const { return a - b; }

int Calculator::mul(int a, int b) const { return a * b; }

int Calculator::div(int a, int b) const {
    if (b == 0) throw std::invalid_argument("division by zero");
    return a / b;
}

}  // namespace __PROJECT_NAME__
