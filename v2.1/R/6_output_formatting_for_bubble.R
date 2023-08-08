# This script reformats the output of TOPSIS so it can match the format of the 
# Property database in DirtSat's Bubble app and outpus a csv file that can be directly
# uploaded to Bubble
# Script outputs also a second file similar to the first one but included the TOPSIS
# results which can't be matched to an address from NYC Open Data so it can be investigated
# further

library(tidyverse)
library(sf)
library(readr)

nyc_buildings_file='/Volumes/NDB_HDD/final/final_geospatial/final_NYC_results_withaddress_st_is_within_distance_3_allpolys.geojson'
nyc_buildings=read_sf(nyc_buildings_file)

#Assumptions related to current building emissions
emissionsfrom_electricy=0.982
emissionsfrom_naturalgas=0.498
emissionsfrom_fuel=0.173
emissionsfrom_steam=0 # update when number is known

#Assumptions related to energy savings:
energy_savings_kwh_persqft = 2.6
energy_cost_dollar_perkwh = 0.2
energy_savings_therms_persqft = 0.00216
energy_cost_dollar_pertherm = 1.5
rooftop_lifetime_years = 25

#Assumptions related to installation and maintenance
greenroof_installation_cost_persqft = 25 
greenroof_maintenance_costs_persqft = 0.75 

#Assumptions on solar production
average_daily_sunlight_hours=3.5
number_of_kwpower_persqft=0.014 #This comes from Project Sunroof
solar_usable_area=0.75

#Assumptions related to emissions
net_electricity_emission_reduction_fromgreen_persqft = 0.00184
net_heating_emission_reduction_fromgreen_persqft = 0.0000125
net_electricity_emission_reduction_fromsolar_factor = 0.000709

#BELOW WILL NEED TO BE UPDATED WITH ACTUAL CALCS ONCE AGREED
roi_dummy = '110-125%' # TO BE DISCUSSED FURTHER

#Assumptions related to stormwater capture:
nyc_average_yearly_rainfall_ft = 3.88
GSA_report_retained_percent = 50
conversion_fromcft_togallon = 7.48
GSA_national_cost_savings_persft = 5


nyc_buildings_nona = nyc_buildings %>% dplyr::filter(!is.na(nyc_buildings$address_id)) 

topsis_percentile=quantile(nyc_buildings$`TOPSIS score`, probs = c(0.15,0.30,0.45,0.60,0.75,0.90))

nyc_buildings_csv = nyc_buildings_nona %>% dplyr::select(h_no,hno_suffix,full_stree,zipcode,`TOPSIS MCDA Rank (1 = Best)`,`TOPSIS score`,`Flat, Usable Area (ft2)`,FAID, `building_total_area_ft2`) 

nyc_buildings_csv = nyc_buildings_csv %>%  dplyr::mutate(address_short = str_squish(paste0(nyc_buildings_nona$h_no," ",replace_na(nyc_buildings_nona$hno_suffix,"")," ",str_to_title(tolower(nyc_buildings_nona$full_stree)))),
                address_geo = str_squish(paste0(nyc_buildings_nona$h_no," ",replace_na(nyc_buildings_nona$hno_suffix,"")," ",str_replace_all(str_to_title(tolower(nyc_buildings_nona$full_stree)),
                                                                                                                                             c("1 St"="1st St","2 St"="2nd St","3 St"="3rd St","4 St"="4th St","5 St"="5th St","6 St"="6th St","7 St"="7th St","8 St"="8th St","9 St"="9th St","0 St"="0th St",
                                                                                                                                               "1 Ave"="1st Ave","2 Ave"="2nd Ave","3 Ave"="3rd Ave","4 Ave"="4th Ave","5 Ave"="5th Ave","6 Ave"="6th Ave","7 Ave"="7th Ave","8 Ave"="8th Ave","9 Ave"="9th Ave","0 Ave"="0th Ave"))
                                                ,", NY ",nyc_buildings_nona$zipcode, ", USA")),
                address_text = str_squish(paste0(nyc_buildings_nona$h_no," ",replace_na(nyc_buildings_nona$hno_suffix,"")," ",str_replace_all(str_to_title(tolower(nyc_buildings_nona$full_stree)),
                                                                                                                                              c("1 St"="1st St","2 St"="2nd St","3 St"="3rd St","4 St"="4th St","5 St"="5th St","6 St"="6th St","7 St"="7th St","8 St"="8th St","9 St"="9th St","0 St"="0th St",
                                                                                                                                                "1 Ave"="1st Ave","2 Ave"="2nd Ave","3 Ave"="3rd Ave","4 Ave"="4th Ave","5 Ave"="5th Ave","6 Ave"="6th Ave","7 Ave"="7th Ave","8 Ave"="8th Ave","9 Ave"="9th Ave","0 Ave"="0th Ave"))
                                                 ,", NY ",nyc_buildings_nona$zipcode, ", USA")),
                application = "",bids = "",company= "",cre_report = "",
                net_emissions_current_peryear = `building_total_area_ft2`*(emissionsfrom_electricy+emissionsfrom_naturalgas+emissionsfrom_fuel+emissionsfrom_steam),
                net_emissions_reduction_green_peryear = (net_electricity_emission_reduction_fromgreen_persqft+net_heating_emission_reduction_fromgreen_persqft)*nyc_buildings_nona$`Flat, Usable Area (ft2)` ,
                energy_reduction_electricity_green_peryear = (energy_savings_kwh_persqft * nyc_buildings_nona$`Flat, Usable Area (ft2)`),
                energy_reduction_heating_green_peryear = (energy_savings_therms_persqft * nyc_buildings_nona$`Flat, Usable Area (ft2)`),   
                energy_savings_green_rooftoplifetime = ((energy_savings_kwh_persqft * energy_cost_dollar_perkwh + energy_savings_therms_persqft * energy_cost_dollar_pertherm) * nyc_buildings_nona$`Flat, Usable Area (ft2)` * rooftop_lifetime_years),
                energy_savings_green_peryear =  ((energy_savings_kwh_persqft * energy_cost_dollar_perkwh + energy_savings_therms_persqft * energy_cost_dollar_pertherm) * nyc_buildings_nona$`Flat, Usable Area (ft2)` ), 
                energy_production_fromsolar_peryear = average_daily_sunlight_hours*number_of_kwpower_persqft*nyc_buildings_nona$`Flat, Usable Area (ft2)`*solar_usable_area*365,
                financing = "",
                greenroof_installation_cost = (greenroof_installation_cost_persqft * nyc_buildings_nona$`Flat, Usable Area (ft2)`),
                greenroof_maintenance_costs = greenroof_maintenance_costs_persqft * nyc_buildings_nona$`Flat, Usable Area (ft2)`,
                img_map = "",members = "",name = "",notified="",
                IRR_green = roi_dummy,
                score = case_when(`TOPSIS score`>= topsis_percentile[6] ~ 'A',(`TOPSIS score`< topsis_percentile[6])&(`TOPSIS score`>= topsis_percentile[5]) ~ 'B',
                                  (`TOPSIS score`< topsis_percentile[5])&(`TOPSIS score`>= topsis_percentile[4]) ~ 'C',(`TOPSIS score`< topsis_percentile[4])&(`TOPSIS score`>= topsis_percentile[3]) ~ 'D',
                                  (`TOPSIS score`< topsis_percentile[3])&(`TOPSIS score`>= topsis_percentile[2]) ~ 'E',`TOPSIS score`< topsis_percentile[2] ~ 'F'),
                score_verbal = case_when(`TOPSIS score`>= topsis_percentile[5]  ~ 'High potential',
                                         (`TOPSIS score`< topsis_percentile[5])&(`TOPSIS score`>= topsis_percentile[3]) ~ 'Average potential',
                                         (`TOPSIS score`< topsis_percentile[3]) ~ 'Low potential'),
                start_date = "", status = "", 
                stormwater_capture = nyc_average_yearly_rainfall_ft * GSA_report_retained_percent/100 * conversion_fromcft_togallon * nyc_buildings_nona$`Flat, Usable Area (ft2)`, 
                stormwater_mngt_savings = GSA_national_cost_savings_persft * nyc_buildings_nona$`Flat, Usable Area (ft2)`,
                total_cost_savings_green_peryear = energy_savings_green_peryear + stormwater_mngt_savings,
                total_flat_area_pc_available = nyc_buildings_nona$`Usable Percent of Flat, Total Area (ft2)`,
                total_flat_roof_area = nyc_buildings_nona$`Flat, Usable Area (ft2)`,
                `Created Date` = "", `Modified Date` = "", Slug = "", `Created By` = "", `Unique id`=""
  )



nyc_buildings_csv = nyc_buildings_csv %>% mutate(
  energy_reduction_electricity_biosolar_peryear=energy_production_fromsolar_peryear+energy_reduction_electricity_green_peryear,
  energy_reduction_electricity_solaronly_peryear=energy_production_fromsolar_peryear,
  energy_savings_solaronly_peryear = energy_production_fromsolar_peryear*energy_cost_dollar_perkwh,
  total_cost_savings_solaronly_peryear = energy_savings_solaronly_peryear,
  total_cost_savings_biosolar_peryear=energy_savings_solaronly_peryear+energy_savings_green_peryear + stormwater_mngt_savings,
  net_emissions_reduction_solaronly_peryear = average_daily_sunlight_hours*number_of_kwpower_persqft*nyc_buildings_nona$`Flat, Usable Area (ft2)`*net_electricity_emission_reduction_fromsolar_factor*365,
  net_emissions_reduction_biosolar_peryear = net_emissions_reduction_green_peryear + net_emissions_reduction_solaronly_peryear
                                                 ) %>% dplyr::select(c(address_short,address_geo,address_text,application,bids,company,cre_report,
                                                          net_emissions_current_peryear,
                                                          net_emissions_reduction_green_peryear ,
                                                          net_emissions_reduction_solaronly_peryear, 
                                                          energy_reduction_electricity_green_peryear,
                                                          net_emissions_reduction_biosolar_peryear,
                                                          energy_reduction_heating_green_peryear,
                                                          energy_savings_green_rooftoplifetime,
                                                          energy_savings_green_peryear ,
                                                          energy_production_fromsolar_peryear,
                                                          energy_reduction_electricity_biosolar_peryear,
                                                          energy_reduction_electricity_solaronly_peryear,
                                                          energy_savings_solaronly_peryear,
                                                          total_cost_savings_green_peryear,
                                                          total_cost_savings_solaronly_peryear,
                                                          total_cost_savings_biosolar_peryear,
                                                          FAID,financing,
                                                          greenroof_installation_cost,greenroof_maintenance_costs,img_map,
                                                          members,name,notified,roi,score,score_verbal,start_date,status,stormwater_capture
                                                          ,stormwater_mngt_savings,
                                                          total_flat_area_pc_available,total_flat_roof_area,`Created Date`,
                                                          `Modified Date`,Slug,`Created By`,`Unique id`))




nyc_buildings_csv <- nyc_buildings_csv %>%
  distinct(address_text, total_flat_roof_area, .keep_all = TRUE)


nyc_buildings_csv <- nyc_buildings_csv %>%
  group_by(address_text) %>%
  mutate(FAID_rank = rank(-total_flat_roof_area)) %>%
  ungroup()

nyc_buildings_csv=nyc_buildings_csv[-c(which(nyc_buildings_csv$address_short=="516 E 13 St"),which(nyc_buildings_csv$address_short=="922 Prospect Pl")),]

write_sf(nyc_buildings_csv,'/Volumes/NDB_HDD/final/final_geospatial/final_NYC_results_withaddress.csv')

nyc_buildings_csv_noduplicates=unique(nyc_buildings_csv)

write_csv(nyc_buildings_csv_noduplicates,'/Volumes/NDB_HDD/final/final_geospatial/final_NYC_results_withaddress_noduplicates.csv')

