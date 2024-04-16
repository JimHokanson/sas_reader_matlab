function f002_startStopRowTesting

final_path = sas.utils.getExampleFilePath('numeric_1000000_2.sas7bdat');
    
f = sas.file(final_path);

t1 = f.readData();
t2 = f.readData('start_stop_rows',[1000 2000]);


end