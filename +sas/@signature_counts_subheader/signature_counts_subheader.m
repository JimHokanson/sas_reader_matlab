classdef signature_counts_subheader < handle
    %
    %   Class:
    %   sas.signature_counts_subheader
    %
    %   ???? How many of these?
    %   - just 1?

    properties
        signatures
        subheader_names
        %1b
        page_first_appear
        %
        %TODO: 0 or 1b index into 
        page_first_pointer
        %
        %  -1 if missing
        %  
        page_last_appear
        page_last_pointer
        is_multi_page
        last_meta_page
    end

    methods
        function obj = signature_counts_subheader(bytes,is_u64)
            %
            %   bytes(57) => 12 - 12 things - TODO: Update document
            %
            
            %

            %65 - start of subheader count vectors


            % - Not handled by Python code
            % - TODO: Check readstat
            % - what about Pandas version

            %1:4   1:8    - signature
            %5:8   9:16   - length?
            %9:12  17:24  - int, usually 4
            %13:14 25:26  - int, usually 7 (number of nonzero SCVs?)
            %15:64 27:120 - ????
            %65:x  121:X





            N_SUBS = 12;

            sigs = zeros(N_SUBS,1);
            names = cell(N_SUBS,1);
            p_first_appear = zeros(N_SUBS,1);
            p_first_pointer = zeros(N_SUBS,1);
            n_pages = zeros(N_SUBS,1);
            p_last_pointer = zeros(N_SUBS,1);


            %1:4  - signature
            %5:8  - first appear
            %9:10 - pointer
            %13:16 - last appear
            %17:18 - pointer

            if is_u64
                I = 120;
                step_I = 40;
                off1 = 9:16;
                off2 = 17:18;
                off3 = 25:32;
                off4 = 33:34;
                var_type = 'uint64';
            else
                I = 64;
                step_I = 20;
                off1 = 5:8;
                off2 = 9:10;
                off3 = 13:16;
                off4 = 17:18;
                var_type = 'uint32';
            end
            for i = 1:N_SUBS
                sigs(i) = typecast(bytes(I+1:I+4),'uint32');
                switch sigs(i)
                    case 4143380214 %column-size subheader
                        names{i} = 'column-size subheader';
                    case 4160223223 %row-size subheader
                        names{i} = 'row-size subheader';
                    case 4294966270
                        names{i} = 'column-format subheader';
                    case 4294966272
                        names{i} = 'signature subheader';
                    case 4294967289
                        names{i} = 'column WTF3';
                    case 4294967290
                        names{i} = 'column WTF2';
                    case 4294967291
                        names{i} = 'column WTF';
                    case 4294967292
                        names{i} = 'column-attributes subheader';
                    case 4294967293
                        names{i} = 'column-text subheader';
                    case 4294967294
                        names{i} = 'column-list subheader';
                    case 4294967295
                        names{i} = 'column-name subheader';
                    case 0
                        names{i} = 'null';
                    otherwise
                        error('Unrecognized header')
                end

                p_first_appear(i) = double(typecast(bytes(I+off1),var_type));
                p_first_pointer(i) = double(typecast(bytes(I+off2),'uint16'));

                %FORM_DOC: I think this is n_pages because it is NOT last
                %page
                n_pages(i) = double(typecast(bytes(I+off3),var_type));
                p_last_pointer(i) = double(typecast(bytes(I+off4),'uint16'));
                I = I + step_I;
            end


            obj.signatures = sigs;
            obj.subheader_names = names;
            obj.page_first_appear = p_first_appear;
            obj.page_first_pointer = p_first_pointer;
            %ASSUMPTION ...
            obj.page_last_appear = p_first_appear + n_pages-1;
            obj.page_last_pointer = p_last_pointer;
            obj.is_multi_page = p_first_appear ~= n_pages;

            obj.last_meta_page = max(obj.page_last_appear);
        end
    end
end