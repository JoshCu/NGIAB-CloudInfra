#!/bin/sh

# Define your list of modules here, separated by spaces.
# Example:
# MODULES="module1 module2 module3"
MODULES="iso_c_fortran_bmi cfe evapotranspiration/evapotranspiration topmodel sloth"

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
