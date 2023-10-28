#!/bin/sh

# Define your list of modules here, separated by spaces.
# Example:
# MODULES="module1 module2 module3"
MODULES="test_bmi_cpp test_bmi_c test_bmi_fortran"

for MODULE in $MODULES; do
    cmake -B extern/$MODULE/cmake_build -DCMAKE_BUILD_TYPE=release -S extern/$MODULE \
    && cmake --build extern/$MODULE/cmake_build -j $(nproc)
    
    # Check if the commands succeeded.
    if [ $? -ne 0 ]; then
        echo "Error building $MODULE"
        exit 1
    fi
done

echo "All modules built successfully!"
