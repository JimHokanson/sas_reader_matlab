

//https://www.mathworks.com/help/matlab/apiref/matlab.data.arrayfactory.html
//

//
// factory.createBuffer

//https://www.mathworks.com/help/matlab/matlab_external/matlab-data-cpp-api-types.html

//https://www.mathworks.com/help/matlab/apiref/matlab.data.typedarray.html

//matlab::mex — MEX interface
//matlab::data — MATLAB Data API - https://www.mathworks.com/help/matlab/matlab-data-array.html
//              https://www.mathworks.com/help/matlab/matlab_external/matlab-data-cpp-api-types.html
//matlab::engine — Engine API for C++
//
//matlab::data::Array
//
//matlab::data::ArrayFactory - creates arrays
//
//   createArray
//   createScalar
//   createCellArray
//   createCharArray
//   createStructArray
//   createEnumArray
//   createSparseArray
//   createEmptyArray
//   createBuffer - unitialized buffer, passed to createArrayFromBuffer
//       - returns: buffer_ptr_t<T>
//
//   createArrayFromBuffer
//       - returns: TypedArray<T>


#include "mex.hpp"
#include "mexAdapter.hpp"
#include <cstring>

namespace md = matlab::data;
namespace mx = matlab::mex;


class MexFunction : public mx::Function {
public:
    void operator()(mx::ArgumentList outputs, mx::ArgumentList inputs) {

        // Create a MATLAB array sharing the C++ memory
        md::ArrayFactory factory;
        // Allocate memory in C++


        //
        //TypedArray<double> array = factory.createArrayFromBuffer<double>({3, 3}, std::move(buffer));
        //buffer_ptr_t<double> array_buffer = array.release();

        unsigned long numElements = 100;
        double *data = (double *)std::malloc(numElements * sizeof(double));

        for (int i = 0; i < numElements; ++i) {
            data[i] = i * 2.5;
        }

        md::buffer_ptr_t<double> data2 = factory.createBuffer<double>(numElements);

        std::memcpy(data2.get(), data, numElements*8);

        std::free(data);

        md::TypedArray<double> outputArray = factory.createArrayFromBuffer<double>({1, numElements}, std::move(data2));

        // Return the MATLAB array
        outputs[0] = std::move(outputArray);
    }
};
