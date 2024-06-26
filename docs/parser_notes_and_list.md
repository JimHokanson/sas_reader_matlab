# Parsers #


Shoutout to this link for a nice resource summary page:

https://github.com/xiaodaigh/sas7bdat-resources

- C/C++
  - ReadStat, https://github.com/WizardMac/ReadStat
    - This code is used by wrappers in other languages
- Java
  - Parso, https://github.com/epam/parso/
    - Best (?) parser I've seen
- Julia
  - SASLib.jl, https://github.com/tk3369/SASLib.jl
    - seems to be well designed, many options for reading
  - ReadStat.jl, https://github.com/queryverse/ReadStat.jl
- Python
  - Pandas, https://pandas.pydata.org/pandas-docs/stable/reference/api/pandas.read_sas.html)
  - Pyreadstat, https://pypi.org/project/pyreadstat/
  - sas7bdat (Haag), https://github.com/jonashaag/sas7bdat
    - Marketed as fastest SAS parser
    - Uses custom C/C++ (i.e., non-readstat) under the hood
  - sas7bdat (Hobbs), https://bitbucket.org/jaredhobbs/sas7bdat/src/master/
    - Nice simple Python parser
    - ported from Matt's R code (but with more updates)
- R
  - sas7bdat, https://github.com/BioStatMatt/sas7bdat
  - Haven, https://github.com/tidyverse/haven
    - relies on ReadStat


  

  C/C++
  -----
  https://github.com/jonashaag/sas7bdat

  https://bitbucket.org/jaredhobbs/sas7bdat/src/master/
  This bitbucket code can also be found at:
  https://github.com/openpharma/sas7bdat

  https://github.com/olivia76/cpp-sas7bdat


  Go
  --
  https://github.com/kshedden/datareader