
// This version works, simplifying in 4

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



/*

temp = reshape(uint16(41:1040),10,100);
temp = repmat(temp,1,10000);
N = 10;
tic
for i = 1:N
temp2 = copy_test4(temp);
end
toc/N

tic
for i = 1:N
temp3 = strip(string(char(temp')),'right');
end
toc/N

tic
for i = 1:N
temp3 = strtrim(string(char(temp')));
end
toc/N


*/

//matlab::data::String
//
//Type representing strings as std::basic_string<char16_t>
//
//The String class defines the element type of a StringArray


//matlab::data::MATLABString
//
//Element type for MATLAB string arrays
//
//Use MATLABString to represent MATLAB® string arrays in C++

//matlab::data::Reference<MATLABString>
//
//



#include "mex.hpp"
#include "mexAdapter.hpp"
#include <cstring>

namespace md = matlab::data;
namespace mx = matlab::mex;

class MexFunction : public mx::Function {
    md::ArrayFactory factory;
    std::shared_ptr<matlab::engine::MATLABEngine> matlabPtr = getEngine();

public:
    void operator()(mx::ArgumentList outputs, mx::ArgumentList inputs) {

        checkArguments(outputs, inputs);

        //Prep of the input
        //--------------------------------
        md::TypedArray<uint16_t> input_matrix = std::move(inputs[0]);
        size_t n_rows = input_matrix.getDimensions()[0];
        size_t n_cols = input_matrix.getDimensions()[1];
        md::buffer_ptr_t<uint16_t> input_buffer = input_matrix.release();
        uint16_t *input_pointer = (uint16_t *)input_buffer.get();
        uint16_t *input_pointer2 = input_pointer;

        //Prep of the output
        //---------------------------------------------------
        md::StringArray myArray = factory.createArray<md::MATLABString>({n_cols,1});

        for (size_t i = 0; i < n_cols; ++i){
            md::buffer_ptr_t<char16_t> temp_buffer = factory.createBuffer<char16_t>(n_rows);
            std::memcpy(temp_buffer.get(), input_pointer2, n_rows*2);
            
            myArray[i] = temp_buffer.get();

            input_pointer2 += n_rows;
        }

        outputs[0] = myArray;


        /*

        //std::u16string
        //std::char16_t;

        md::buffer_ptr_t<char16_t> temp_buffer = factory.createBuffer<char16_t>(10);
        //md::buffer_ptr_t<std::u16string> temp_buffer = factory.createBuffer<std::u16string>(10);

        //md::buffer_ptr_t<uint16_t> temp_buffer = factory.createBuffer<uint16_t>(10);
        std::memcpy(temp_buffer.get(), input_buffer.get()+40, 10*2);

        //md::TypedArray<md::MATLABString> temp_string = factory.createArrayFromBuffer<md::MATLABString>({1, 10}, std::move(temp_buffer));

        //std::u16string test = u"testing";

        //myArray[0] = temp_string; 
        myArray[0] = temp_buffer.get();
        //myArray[0] = test;
        //myArray[0] = md::MATLABString(u"east");
        myArray[1] = md::MATLABString(u"west");
        outputs[0] = myArray;

        */
              
        /*
		f.createCharArray("MATLAB Cell Array"),
		f.createArray<double>({ 2,2 }, { 1.2, 2.2, 3.2, 4.2 });

        for (size_t i = 0; i < n_cols; ++i){

            double sum = 0.0;
            for (size_t j = 0; j < numCols; ++j) {
                sum += inputMatrix[i][j];
            }
            outputArray[i] = sum;
        }
        

        

        md::buffer_ptr_t<uint16_t> temp_buffer = factory.createBuffer<uint16_t>(10);

        std::memcpy(temp_buffer.get(), input_buffer.get()+4, 10*2);

        //md::TypedArray<uint16_t> outputArray = factory.createArrayFromBuffer<uint16_t>({1, 10}, std::move(temp_buffer));

        // Return the MATLAB array
        //outputs[0] = std::move(outputArray);
        outputs[0] = factory.createArrayFromBuffer<uint16_t>({1, 10}, std::move(temp_buffer));
        */

    }
private:
    void checkArguments(mx::ArgumentList outputs, mx::ArgumentList inputs) {

        //https://www.mathworks.com/help/matlab/matlab_external/handling-inputs-and-outputs.html

        if (inputs.size() != 1) {
            mexErrMsgIdAndTxt(u"copy_test:invalid_input:one_input_check",u"there must be 1 input to copy_test4");
        }
        if (inputs[0].getType() != md::ArrayType::UINT16) {
            mexErrMsgIdAndTxt(u"copy_test:invalid_input:uint16_check", u"Input must be a matrix of type uint16");
        }
        if (inputs[0].getDimensions().size() != 2) {
            mexErrMsgIdAndTxt(u"copy_test:invalid_input:2d_check", u"Input must be a 2D matrix.");
        }
        if (outputs.size() != 1) {
            mexErrMsgIdAndTxt(u"copy_test:invalid_input:one_output_check",u"there must be 1 output to copy_test4");
        }
    }

    void mexErrMsgIdAndTxt(md::String id, md::String error_string){
        matlabPtr->feval(u"error", 0, std::vector<md::Array>({factory.createScalar(id),factory.createScalar(error_string)}));
    }
};
