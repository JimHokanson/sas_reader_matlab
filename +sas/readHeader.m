function header = readHeader(file_path)
%
%   header = sas.readHeader(file_path);
%
%
%   TODO: I'd like to also return the first part of the file ...

fid = fopen(file_path,'r');
if fid == -1
    error('Unable to open the specified file:\n%s\n',file_path)
end

header = sas.header(fid);

fclose(fid);

end