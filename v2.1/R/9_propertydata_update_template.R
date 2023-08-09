# This script extracts data required for DirtSat's Bubble app from 
# https://data.cityofnewyork.us/Environment/Energy-and-Water-Data-Disclosure-for-Local-Law-84-/usc3-8zwd

library(stringr)
library(readr)
library(tidyverse)

address_uniqueid = read_csv('/Volumes/NDB_HDD/final/final_geospatial/address_uniqueid.csv')
latest_data = read_csv('/Volumes/NDB_HDD/final/final_geospatial/final_NYC_results_withaddress.csv')

address_uniqueid$combinedidentifier = paste0(address_uniqueid$address_short,"-",address_uniqueid$FAID)

latest_data$combinedidentifier = paste0(latest_data$address_short,"-",latest_data$FAID)

# we checked addresses common to the ones already in bubble with viable green roofs
latest_data_withuniqueid = merge(x = latest_data, y = address_uniqueid, by = "combinedidentifier",all.x = TRUE,all.y = TRUE)

latest_data_withuniqueid = latest_data_withuniqueid %>% filter(!is.na(`unique id`))

write_csv(latest_data_withuniqueid,'/Volumes/NDB_HDD/final/final_geospatial/latest_data_withuniqueid.csv')

write_csv(latest_data_withuniqueid[1:20000,],'/Volumes/NDB_HDD/final/final_geospatial/latest_data_withuniqueid_1_to_20000.csv')

write_csv(latest_data_withuniqueid[20001:40000,],'/Volumes/NDB_HDD/final/final_geospatial/latest_data_withuniqueid_20001_to_40000.csv')

write_csv(latest_data_withuniqueid[40001:60000,],'/Volumes/NDB_HDD/final/final_geospatial/latest_data_withuniqueid_40001_to_60000.csv')

write_csv(latest_data_withuniqueid[60001:80000,],'/Volumes/NDB_HDD/final/final_geospatial/latest_data_withuniqueid_600001_to_80000.csv')

write_csv(latest_data_withuniqueid[80001:100000,],'/Volumes/NDB_HDD/final/final_geospatial/latest_data_withuniqueid_80001_to_100000.csv')

write_csv(latest_data_withuniqueid[100001:nrow(latest_data),],'/Volumes/NDB_HDD/final/final_geospatial/latest_data_withuniqueid_100001_to_end.csv')