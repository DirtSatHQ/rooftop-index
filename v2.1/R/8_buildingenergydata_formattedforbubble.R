# This script extracts data required for DirtSat's Bubble app from 
# https://data.cityofnewyork.us/Environment/Energy-and-Water-Data-Disclosure-for-Local-Law-84-/usc3-8zwd

library(stringr)
library(readr)
library(tidyverse)

bubble_database = read_csv('/Volumes/NDB_HDD/final/final_geospatial/export_All-Properties-modified--_2023-07-27_16-00-52.csv')
energy_data = read_csv('/Volumes/NDB_HDD/final/final_geospatial/Energy_and_Water_Data_Disclosure_for_Local_Law_84_2021__Data_for_Calendar_Year_2020_.csv')

# reformatting address to Google Maps addresses format:

energy_data$newaddress=paste0(energy_data$`Address 1`,', ',str_to_title(tolower(energy_data$Borough)),', NY ',energy_data$Postcode,', USA')

#extract information required for Bubble upload
energy_bubble= energy_data %>% dplyr::select(newaddress,`ENERGY STAR Score`,`Fuel Oil #1 Use (kBtu)`,`Fuel Oil #2 Use (kBtu)`,
                                             `Fuel Oil #4 Use (kBtu)`,`Fuel Oil #5 & 6 Use (kBtu)`,`Diesel #2 Use (kBtu)`,
                                             `Propane Use (kBtu)`,`Natural Gas Use (therms)`,`Electricity Use - Grid Purchase (kWh)`,
                                             `Net Emissions (Metric Tons CO2e)`) %>%dplyr::mutate(address_text=str_replace_all(newaddress,"Street","St"))



# we checked addresses common to the ones already in bubble with viable green roofs
energy_data_withmatchingbubbleaddresses = merge(x = bubble_database, y = energy_bubble, by = "address_text",all.x = TRUE)

energy_data_withmatchingbubbleaddresses = energy_data_withmatchingbubbleaddresses %>% dplyr::filter(!is.na(`Net Emissions (Metric Tons CO2e)`))

# As there are duplicate records in the energy data, we only keep the highest emissions data for a given address
energy_data_noduplicateuniqueid = aggregate(`Net Emissions (Metric Tons CO2e)` ~ `unique id`,energy_data_withmatchingbubbleaddresses,max)

write_csv(energy_data_noduplicateuniqueid,'/Volumes/NDB_HDD/final/final_geospatial/energy_data_withmatchingbubbleaddresses.csv')
