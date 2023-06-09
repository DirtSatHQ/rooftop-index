# This script reformats the output of TOPSIS so it can match the format of the 
# Property database in DirtSat's Bubble app and outpus a csv file that can be directly
# uploaded to Bubble
# Script outputs also a second file similar to the first one but included the TOPSIS
# results which can't be matched to an address from NYC Open Data so it can be investigated
# further

library(tidyverse)
library(sf)

nyc_buildings_file='/Volumes/NDB_HDD/final/final_geospatial/final_NYC_results_withaddress.geojson'
nyc_buildings=read_sf(nyc_buildings_file)

nyc_buildings_nona = nyc_buildings %>% dplyr::filter(!is.na(nyc_buildings$address_id)) %>% 
              dplyr::mutate(boro = case_when(borocode == '1' ~ 'Manhattan',
                                             borocode == '2' ~ 'Bronx',
                                             borocode == '3' ~ 'Brooklyn',
                                             borocode == '4' ~ 'Queens',
                                             borocode == '5' ~ 'Staten Island'))
                            

nyc_buildings_csv = nyc_buildings_nona %>% dplyr::select(h_no,hno_suffix,full_stree,zipcode,`TOPSIS MCDA Rank (1 = Best)`) %>%
                        dplyr::mutate(address_short = paste0(nyc_buildings_nona$h_no,replace_na(nyc_buildings_nona$hno_suffix,"")," ",str_to_title(tolower(nyc_buildings_nona$full_stree))),
                                      address_geo = paste0(nyc_buildings_nona$h_no,replace_na(nyc_buildings_nona$hno_suffix,"")," ",str_to_title(tolower(nyc_buildings_nona$full_stree)),", ", nyc_buildings_nona$boro,", NY ",nyc_buildings_nona$zipcode, ", USA"),
                                      address_text = paste0(nyc_buildings_nona$h_no,replace_na(nyc_buildings_nona$hno_suffix,"")," ",str_to_title(tolower(nyc_buildings_nona$full_stree)),", ", nyc_buildings_nona$boro,", NY ",nyc_buildings_nona$zipcode, ", USA"),
                                      application = "",bids = "",company= "",cre_report = "",financing = "",img_map = "",members = "",name = "",notified="",
                                      score = case_when(`TOPSIS MCDA Rank (1 = Best)`< 6000 ~ 'A',`TOPSIS MCDA Rank (1 = Best)`< 12000 ~ 'B',
                                                        `TOPSIS MCDA Rank (1 = Best)`< 18000 ~ 'C',`TOPSIS MCDA Rank (1 = Best)`>= 18000 ~ 'D'),
                                      score_verbal = case_when(`TOPSIS MCDA Rank (1 = Best)`< 6000 ~ 'High potential',
                                                               `TOPSIS MCDA Rank (1 = Best)`< 12000 ~ 'High potential',
                                                               `TOPSIS MCDA Rank (1 = Best)`< 18000 ~ 'Average potential',
                                                               `TOPSIS MCDA Rank (1 = Best)`>= 18000 ~ 'Low potential'),
                                      start_date = "", status = "", `Created Date` = "", `Modified Date` = "", Slug = "", `Created By` = "", `Unique id`=""
                                      )



nyc_buildings_csv = nyc_buildings_csv %>% dplyr::select(-c(h_no,hno_suffix,full_stree,zipcode,`TOPSIS MCDA Rank (1 = Best)`))

write_sf(nyc_buildings_csv,'/Volumes/NDB_HDD/final/final_geospatial/final_NYC_results_withaddress.csv')


## The below repeats the above but doesn't remove the FAID that can't be matched to an address, in order to investigate why this is the case

nyc_buildings_inclna = nyc_buildings %>% 
  dplyr::mutate(boro = case_when(borocode == '1' ~ 'Manhattan',
                                 borocode == '2' ~ 'Bronx',
                                 borocode == '3' ~ 'Brooklyn',
                                 borocode == '4' ~ 'Queens',
                                 borocode == '5' ~ 'Staten Island'))


nyc_buildings_csv_inclna = nyc_buildings_inclna %>% dplyr::select(h_no,hno_suffix,full_stree,zipcode,`TOPSIS MCDA Rank (1 = Best)`) %>%
  dplyr::mutate(address_short = paste0(nyc_buildings_inclna$h_no,replace_na(nyc_buildings_inclna$hno_suffix,"")," ",str_to_title(tolower(nyc_buildings_inclna$full_stree))),
                address_geo = paste0(nyc_buildings_inclna$h_no,replace_na(nyc_buildings_inclna$hno_suffix,"")," ",str_to_title(tolower(nyc_buildings_inclna$full_stree)),", ", nyc_buildings_inclna$boro,", NY ",nyc_buildings_inclna$zipcode, ", USA"),
                address_text = paste0(nyc_buildings_inclna$h_no,replace_na(nyc_buildings_inclna$hno_suffix,"")," ",str_to_title(tolower(nyc_buildings_inclna$full_stree)),", ", nyc_buildings_inclna$boro,", NY ",nyc_buildings_inclna$zipcode, ", USA"),
                application = "",bids = "",company= "",cre_report = "",financing = "",img_map = "",members = "",name = "",notified="",
                score = case_when(`TOPSIS MCDA Rank (1 = Best)`< 6000 ~ 'A',`TOPSIS MCDA Rank (1 = Best)`< 12000 ~ 'B',
                                  `TOPSIS MCDA Rank (1 = Best)`< 18000 ~ 'C',`TOPSIS MCDA Rank (1 = Best)`>= 18000 ~ 'D'),
                score_verbal = case_when(`TOPSIS MCDA Rank (1 = Best)`< 12000 ~ 'High potential',
                                         `TOPSIS MCDA Rank (1 = Best)`>= 12000 ~ 'Average potential'),
                start_date = "", status = "", `Created Date` = "", `Modified Date` = "", Slug = "", `Created By` = "", `Unique id`=""
  )



nyc_buildings_csv_inclna = nyc_buildings_csv_inclna %>% dplyr::select(-c(h_no,hno_suffix,full_stree,zipcode,`TOPSIS MCDA Rank (1 = Best)`))

write_sf(nyc_buildings_csv_inclna,'/Volumes/NDB_HDD/final/final_geospatial/final_NYC_results_withaddress_inclna.csv')
