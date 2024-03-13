classdef fid < handle
    %
    %   Class:
    %   sas.fid
    %
    %   This simulates the fid calls but loads everything into memory. I'm
    %   not sure that it is all that useful .... Most of the speed
    %   execution time seems to be spent on string conversions.

    properties
        bytes
        I = 0
    end

    methods
        function obj = fid(file_path)

            % open the file
            fid = fopen(file_path,'r');
            %TODO: Check fid status
            
            try
                % read file
                obj.bytes = fread(fid,'*uint8')';
            catch exception
                % close file
                fclose(fid);
                throw(exception);
            end
            
            % close file
            fclose(fid);
        end
        function out = ftell(obj)
            out = obj.I;
        end
        function status = fseek(obj,offset,origin)
            status = 0;
            %TODO: Error checking
            switch origin
                case 'bof'
                    obj.I = offset;
                case 'cof'
                    obj.I = offset + obj.I;
                otherwise
                    error('unhandled case')
            end            
        end
        function bytes = fread(obj,size,precision)
            if ~strcmp(precision,'*uint8')
                error('unhandled case')
            end
            I2 = obj.I+size;
            I1 = obj.I;
            bytes = obj.bytes(I1+1:I2);
            obj.I = I2;
        end
    end
end