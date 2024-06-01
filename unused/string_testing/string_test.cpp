#include "mex.hpp"
#include "mexAdapter.hpp"
#include "MatlabDataArray.hpp"


//https://www.mathworks.com/help/matlab/matlab_external/structure-of-c-mex-function.html

using matlab::mex::ArgumentList;
using namespace matlab::data;

class MexFunction : public matlab::mex::Function {
    // Factory to create MATLAB data arrays
    ArrayFactory factory;
    std::shared_ptr<matlab::engine::MATLABEngine> matlabPtr = getEngine();

public:
    void operator()(ArgumentList outputs, ArgumentList inputs) {
        checkArguments(outputs, inputs);

        // outputs[0] = factory.createArray<MATLABString>({1,3}, 
	    //       {matlab::data::MATLABString(u""), 
        //        matlab::data::MATLABString(u"Gemini"), 
        //        matlab::data::MATLABString()});


        //matlab::data::String - represents uint16 string
        //
        //  using String = std::basic_string<char16_t>;


        //matlab::data::MATLABString
        
        //matlab::data::StringArray


        //Algorithm
        //---------
        //For each column
        //
        //  - initialize a new 

        //  How do I place a string in the string array?


        TypedArray<double> inputMatrix = std::move(inputs[0]);
        size_t numRows = inputMatrix.getDimensions()[0];
        size_t numCols = inputMatrix.getDimensions()[1];

        TypedArray<double> outputArray = factory.createArray<double>({numRows,1},{0});

        for (size_t i = 0; i < numRows; ++i) {
            double sum = 0.0;
            for (size_t j = 0; j < numCols; ++j) {
                sum += inputMatrix[i][j];
            }
            outputArray[i] = sum;
        }

        matlab::data::TypedArray<uint16_t>::iterator subsetData = data.begin() + static_cast<size_t>(startIndex) - 1;
        // Convert subset to character array using memcpy
        //std::string charArray(subsetLength, '\0');
        //memcpy(&charArray[0], subsetData, subsetLength * sizeof(uint16_t));
        //outputs[0] = factory.createCharArray(charArray);



        outputs[0] = outputArray;

        //u"" is UTF-16 encoded
        matlab::data::StringArray wtf = factory.createArray<MATLABString>({1,3});
        wtf[0] = MATLABString(u"test");
        wtf[1] = MATLABString(u"test1");
        wtf[2] = MATLABString(u"test2");

        outputs[1] = wtf;
    }

private:
    void checkArguments(ArgumentList outputs, ArgumentList inputs) {

        //https://www.mathworks.com/help/matlab/matlab_external/handling-inputs-and-outputs.html
        //size()
        //empty()
        //getType()
        //getDimensions()
        //getNumberOfElements()
        //isEmpty()

        if (inputs.size() != 1) {
            mexErrMsgIdAndTxt(factory.createCharArray("Input must be double array"));
        }
        // if (inputs[0].getType() != ArrayType::DOUBLE) {
        //     mexErrMsgIdAndTxt("MATLAB:sumrows:invalidInput", "Input must be a numeric matrix.");
        // }
        // if (inputs[0].getDimensions().size() != 2) {
        //     mexErrMsgIdAndTxt("MATLAB:sumrows:invalidInput", "Input must be a 2D matrix.");
        // }
    }

    void mexErrMsgIdAndTxt(matlab::data::CharArray error_string){
        matlabPtr->feval(u"error", 0, 
                std::vector<Array>({factory.createScalar("MATLAB:sumrows:invalidInput"),
                                    error_string}));
                    //factory.createScalar("One input argument is required.")}));
    }

       

    // void displayOnMATLAB(std::ostringstream& stream) {
    //     // Pass stream content to MATLAB fprintf function
    //     matlabPtr->feval(u"fprintf", 0,
    //         std::vector<Array>({ factory.createScalar(stream.str()) }));
    //     // Clear stream buffer
    //     stream.str("");
    // }
};