# This script reformats the output of TOPSIS so it can match the format of the 
# Property database in DirtSat's Bubble app and outpus a csv file that can be directly
# uploaded to Bubble
# Script outputs also a second file similar to the first one but included the TOPSIS
# results which can't be matched to an address from NYC Open Data so it can be investigated
# further

library(tidyverse)
library(sf)
library(readr)

nyc_buildings_file='/Volumes/NDB_HDD/final/final_geospatial/final_NYC_results_withaddress.geojson'
nyc_buildings=read_sf(nyc_buildings_file)

nyc_buildings_nona = nyc_buildings %>% dplyr::filter(!is.na(nyc_buildings$address_id)) 

topsis_percentile=quantile(nyc_buildings$`TOPSIS score`, probs = c(0.15,0.30,0.45,0.60,0.75,0.90))

nyc_buildings_csv = nyc_buildings_nona %>% dplyr::select(h_no,hno_suffix,full_stree,zipcode,`TOPSIS MCDA Rank (1 = Best)`,`TOPSIS score`) %>%
  dplyr::mutate(address_short = str_squish(paste0(nyc_buildings_nona$h_no," ",replace_na(nyc_buildings_nona$hno_suffix,"")," ",str_to_title(tolower(nyc_buildings_nona$full_stree)))),
                address_geo = str_squish(paste0(nyc_buildings_nona$h_no," ",replace_na(nyc_buildings_nona$hno_suffix,"")," ",str_replace_all(str_to_title(tolower(nyc_buildings_nona$full_stree)),
                                    c("1 St"="1st St","2 St"="2nd St","3 St"="3rd St","4 St"="4th St","5 St"="5th St","6 St"="6th St","7 St"="7th St","8 St"="8th St","9 St"="9th St","0 St"="0th St",
                                      "1 Ave"="1st Ave","2 Ave"="2nd Ave","3 Ave"="3rd Ave","4 Ave"="4th Ave","5 Ave"="5th Ave","6 Ave"="6th Ave","7 Ave"="7th Ave","8 Ave"="8th Ave","9 Ave"="9th Ave","0 Ave"="0th Ave"))
                                    ,", NY ",nyc_buildings_nona$zipcode, ", USA")),
                address_text = str_squish(paste0(nyc_buildings_nona$h_no," ",replace_na(nyc_buildings_nona$hno_suffix,"")," ",str_replace_all(str_to_title(tolower(nyc_buildings_nona$full_stree)),
                                    c("1 St"="1st St","2 St"="2nd St","3 St"="3rd St","4 St"="4th St","5 St"="5th St","6 St"="6th St","7 St"="7th St","8 St"="8th St","9 St"="9th St","0 St"="0th St",
                                      "1 Ave"="1st Ave","2 Ave"="2nd Ave","3 Ave"="3rd Ave","4 Ave"="4th Ave","5 Ave"="5th Ave","6 Ave"="6th Ave","7 Ave"="7th Ave","8 Ave"="8th Ave","9 Ave"="9th Ave","0 Ave"="0th Ave"))
                                      ,", NY ",nyc_buildings_nona$zipcode, ", USA")),
                application = "",bids = "",company= "",cre_report = "",financing = "",img_map = "",members = "",name = "",notified="",
                score = case_when(`TOPSIS score`>= topsis_percentile[6] ~ 'A',(`TOPSIS score`< topsis_percentile[6])&(`TOPSIS score`>= topsis_percentile[5]) ~ 'B',
                                  (`TOPSIS score`< topsis_percentile[5])&(`TOPSIS score`>= topsis_percentile[4]) ~ 'C',(`TOPSIS score`< topsis_percentile[4])&(`TOPSIS score`>= topsis_percentile[3]) ~ 'D',
                                  (`TOPSIS score`< topsis_percentile[3])&(`TOPSIS score`>= topsis_percentile[2]) ~ 'E',`TOPSIS score`< topsis_percentile[2] ~ 'F'),
                score_verbal = case_when(`TOPSIS score`>= topsis_percentile[5]  ~ 'High potential',
                                         (`TOPSIS score`< topsis_percentile[5])&(`TOPSIS score`>= topsis_percentile[3]) ~ 'Average potential',
                                         (`TOPSIS score`< topsis_percentile[3]) ~ 'Low potential'),
                start_date = "", status = "", `Created Date` = "", `Modified Date` = "", Slug = "", `Created By` = "", `Unique id`=""
                )



nyc_buildings_csv = nyc_buildings_csv %>% dplyr::select(-c(h_no,hno_suffix,full_stree,zipcode,`TOPSIS MCDA Rank (1 = Best)`,`TOPSIS score`,geometry))

write_sf(nyc_buildings_csv,'/Volumes/NDB_HDD/final/final_geospatial/final_NYC_results_withaddress.csv')

nyc_buildings_csv_read = read.csv('/Volumes/NDB_HDD/final/final_geospatial/final_NYC_results_withaddress.csv')

nyc_buildings_csv_noduplicates=unique(nyc_buildings_csv_read)

write_csv(nyc_buildings_csv_noduplicates,'/Volumes/NDB_HDD/final/final_geospatial/final_NYC_results_withaddress_noduplicates.csv')

## The below repeats the above but doesn't remove the FAID that can't be matched to an address, in order to investigate why this is the case

nyc_buildings_csv_inclna = nyc_buildings %>% dplyr::select(h_no,hno_suffix,full_stree,zipcode,`TOPSIS MCDA Rank (1 = Best)`,`TOPSIS score`) %>%
  dplyr::mutate(address_short = str_squish(paste0(nyc_buildings$h_no," ",replace_na(nyc_buildings$hno_suffix,"")," ",str_to_title(tolower(nyc_buildings$full_stree)))),
                address_geo = str_squish(paste0(nyc_buildings$h_no," ",replace_na(nyc_buildings$hno_suffix,"")," ",str_replace_all(str_to_title(tolower(nyc_buildings$full_stree)),
                                      c("1 St"="1st St","2 St"="2nd St","3 St"="3rd St","4 St"="4th St","5 St"="5th St","6 St"="6th St","7 St"="7th St","8 St"="8th St","9 St"="9th St","0 St"="0th St",
                                      "1 Ave"="1st Ave","2 Ave"="2nd Ave","3 Ave"="3rd Ave","4 Ave"="4th Ave","5 Ave"="5th Ave","6 Ave"="6th Ave","7 Ave"="7th Ave","8 Ave"="8th Ave","9 Ave"="9th Ave","0 Ave"="0th Ave"))
                                     ,", NY ",nyc_buildings$zipcode, ", USA")),
                address_text = str_squish(paste0(nyc_buildings$h_no," ",replace_na(nyc_buildings$hno_suffix,"")," ",str_replace_all(str_to_title(tolower(nyc_buildings$full_stree)),
                                      c("1 St"="1st St","2 St"="2nd St","3 St"="3rd St","4 St"="4th St","5 St"="5th St","6 St"="6th St","7 St"="7th St","8 St"="8th St","9 St"="9th St","0 St"="0th St",
                                       "1 Ave"="1st Ave","2 Ave"="2nd Ave","3 Ave"="3rd Ave","4 Ave"="4th Ave","5 Ave"="5th Ave","6 Ave"="6th Ave","7 Ave"="7th Ave","8 Ave"="8th Ave","9 Ave"="9th Ave","0 Ave"="0th Ave"))
                                      ,", NY ",nyc_buildings$zipcode, ", USA")),
                application = "",bids = "",company= "",cre_report = "",financing = "",img_map = "",members = "",name = "",notified="",
                score = case_when(`TOPSIS score`>= topsis_percentile[6] ~ 'A',(`TOPSIS score`< topsis_percentile[6])&(`TOPSIS score`>= topsis_percentile[5]) ~ 'B',
                                  (`TOPSIS score`< topsis_percentile[5])&(`TOPSIS score`>= topsis_percentile[4]) ~ 'C',(`TOPSIS score`< topsis_percentile[4])&(`TOPSIS score`>= topsis_percentile[3]) ~ 'D',
                                 (`TOPSIS score`< topsis_percentile[3])&(`TOPSIS score`>= topsis_percentile[2]) ~ 'E',`TOPSIS score`< topsis_percentile[2] ~ 'F'),
                score_verbal = case_when(`TOPSIS score`>= topsis_percentile[5]  ~ 'High potential',
                                        (`TOPSIS score`< topsis_percentile[5])&(`TOPSIS score`>= topsis_percentile[3]) ~ 'Average potential',
                                        (`TOPSIS score`< topsis_percentile[3]) ~ 'Low potential'),
                start_date = "", status = "", `Created Date` = "", `Modified Date` = "", Slug = "", `Created By` = "", `Unique id`=""
                )



nyc_buildings_csv_inclna = nyc_buildings_csv_inclna %>% dplyr::select(-c(h_no,hno_suffix,full_stree,zipcode,`TOPSIS MCDA Rank (1 = Best)`,`TOPSIS score`))

write_sf(nyc_buildings_csv_inclna,'/Volumes/NDB_HDD/final/final_geospatial/final_NYC_results_withaddress_inclna.csv')

nyc_buildings_csv_inclna_read = read.csv('/Volumes/NDB_HDD/final/final_geospatial/final_NYC_results_withaddress_inclna.csv')

nyc_buildings_csv_inclna_noduplicates=unique(nyc_buildings_csv_inclna_read)

write_csv(nyc_buildings_csv_inclna_noduplicates,'/Volumes/NDB_HDD/final/final_geospatial/final_NYC_results_withaddress_inclna_noduplicates.csv')

