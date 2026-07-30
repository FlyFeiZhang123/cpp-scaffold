#pragma once

namespace __PROJECT_NAME__ {

class Calculator {
public:
    int add(int a, int b) const;
    int sub(int a, int b) const;
    int mul(int a, int b) const;
    int div(int a, int b) const;   // b != 0
};

}  // namespace __PROJECT_NAME__
