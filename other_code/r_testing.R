#library(haven)
#library(tictoc)
tic()
wtf = read_sas(fp)
#sas <- read.sas7bdat(file = fp, debug = TRUE)
#env = attributes(sas)$debug
toc()

#download.sas7bdat.sources