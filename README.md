# sas_reader_matlab

MATLAB code for reading SAS files of the format .sas7bdat

Advantages:
1. Doesn't require installing MySQL, unlike [this FEX submission](https://www.mathworks.com/matlabcentral/fileexchange/13069-the-twain-shall-meet-facilitating-data-exchange-between-sas-and-matlab)
2. Supports reading large files
3. Relatively fast (see blog post below)

This code relies on reverse engineering of the ".sas7bdat" file format. More information on these efforts, as well as the limitations of this code can be found here:
https://jimhokanson.com/blog/2024/2024_05__sas_reader_matlab/

This code works on a large set of files, but as a reverse engineering effort, it may not work on *your* file.

**Verify that it seems to be working properly on YOUR file**

The biggest issue is respect to column formats. Some formats are dates or datetimes and may be returned as numerics instead of being properly converted. This is a quick fix, I just need to know what column format is not being supported properly. In rare instances I may need an example file to work with.

# Usage

```matlab
%Load file into table
t = sas.readFile(file_path)

%Same, but prompts for file path
t = sas.readFile

%The second output here gives you access to the details of the parsed file
[t,file] = sas.readFile(file_path)

%If you want meta data only you can do this
s = sas.readFileMeta(file_path);

%Again, you can ask it to prompt for the file path
s = sas.readFileMeta()

```

# Advanced Usage - Large Files

I work with some large files (many GB files). The file itself consists of pages, where each page has somewhere on the order of 0 to 50000 rows. Unlike rows, pages are pretty easy to "jump" to in the file. I have built in support for reading specific pages and returning those pages. 

Here's an example of reading only specific pages, and then taking those results and saving to .mat files based on the subject ID.

```matlab
fp = fullfile(root,'intraday_hr.sas7bdat');

%Figure out how many pages are in the file
s =  sas.readFileMeta(fp);

options = sas.file_reading_options();

h_tic = tic;
%The 1000 here is somewhat arbitary. Note this limits how much
%memory we use. 10000 or even 100000 may be fine.
start_pages = 1:1000:s.n_pages;
stop_pages = [start_pages(2:end)-1 s.n_pages];
for i = 1:length(start_pages)
    fprintf('%d:%d %g\n',i,length(start_pages),toc(h_tic))
    
    I1 = start_pages(i);
    I2 = stop_pages(i);
    options.pages_to_read = I1:I2;
    %Note passing in the options to the file loader
    f = sas.file(fp,options);
    t1 = f.readData();

    %For each unique subject ID, save to a mat file
    usids = unique(t1.subjectid);
    for j = 1:length(usids)
        sid = usids(j);
        mask = sid == t1.subjectid;
        t = t1(mask,:);
        name = sprintf('%d.mat',sid);
        %root is a predefind save folder
        save_path = fullfile(root,'heart',name);
        if exist(save_path,'file')
            %Append if the file already exists
            h = load(save_path);
            %Here we add our new rows to the existing rows
            t = [h.t; t];
        end
        save(save_path,"t");
    end
end
```

# Potential Improvements

- The RLE decompression is MATLAB based. C code would be better given the style of the decompression (loops and if statements)
- More support of standard SAS column formats