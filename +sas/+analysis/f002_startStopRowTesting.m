function f002_startStopRowTesting

final_path = sas.utils.getExampleFilePath('numeric_1000000_2.sas7bdat');

f = sas.file(final_path);

t1 = f.readData();

rng(1)
for i = 1:1e4
    if mod(i,100) == 0
        fprintf('%d\n',i)
    end
    r = sort(randi(1e6,1,2));
    
    t2 = f.readData('start_stop_rows',r);

    v1 = t1.x(r(1):r(2));
    v2 = t2.x;
    if ~isequal(v1,v2)
        error('mismatch')
    end
end

end