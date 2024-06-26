function file_paths = getExampleFilePaths(varargin)
%
%   file_paths = sas.utils.getExampleFilePaths()

in.include_big_endian = true;
in.include_corrupt_files = false;
in = sas.sl.in.processVarargin(in,varargin);

root = sas.utils.getExampleRoot();

d = dir(fullfile(root,'**','*.sas7bdat'));

names = {d.name};
%TODO: 

delete_mask = false(1,length(names));
if ~in.include_corrupt_files
    %TODO: Verify each of these
corrupt_files = [...
    "corrupt.sas7bdat",...
    "invalid_lengths.sas7bdat",...
    "issue_pandas.sas7bdat",...
    "issue1_pandas.sas7bdat",...
    "sas_infinite_loop.sas7bdat"];
delete_mask(ismember(names,corrupt_files)) = true;
end

if ~in.include_big_endian
big_endian_files = {...
    '10rec.sas7bdat'...
    'depress.sas7bdat'...
    'drugprob.sas7bdat'...
    'drugtest.sas7bdat'...
    'environ.sas7bdat'...
    'event1.sas7bdat'...
    'event2.sas7bdat'...
    'event3.sas7bdat'...
    'event4.sas7bdat'...
    'firstsex.sas7bdat'...
    'gpa.sas7bdat'...
    'gss96.sas7bdat'...
    'osteo_analysis_data.sas7bdat'...
    'religion.sas7bdat'...
    'stress.sas7bdat'...
    'test10.sas7bdat'...
    'test11.sas7bdat'...
    'test12.sas7bdat'...
    'test13.sas7bdat'...
    'test14.sas7bdat'...
    'test15.sas7bdat'...
    'yrbscol.sas7bdat'...
    '54-class.sas7bdat'...
    'extend_yes.sas7bdat'};
delete_mask(ismember(names,big_endian_files)) = true;
end

d(delete_mask) = [];

file_paths = arrayfun(@(x) fullfile(x.folder,x.name),d,'un',0);

end