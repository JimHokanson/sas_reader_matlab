

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

/*

temp = uint16(1:200);
temp2 = copy_test2(temp);

*/


class MexFunction : public mx::Function {
public:
    void operator()(mx::ArgumentList outputs, mx::ArgumentList inputs) {

        // Create a MATLAB array sharing the C++ memory
        md::ArrayFactory factory;

        md::TypedArray<uint16_t> input_matrix = std::move(inputs[0]);

        md::buffer_ptr_t<uint16_t> input_buffer = input_matrix.release();

        md::buffer_ptr_t<uint16_t> temp_buffer = factory.createBuffer<uint16_t>(10);

        std::memcpy(temp_buffer.get(), input_buffer.get()+4, 10*2);

        //md::TypedArray<uint16_t> outputArray = factory.createArrayFromBuffer<uint16_t>({1, 10}, std::move(temp_buffer));

        // Return the MATLAB array
        //outputs[0] = std::move(outputArray);
        outputs[0] = factory.createArrayFromBuffer<uint16_t>({1, 10}, std::move(temp_buffer));

    }
};
