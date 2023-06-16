# This script is to check mapping of the NCY Open Data addresses used in script 5 to the Google API addresses. It is important to ensure our address_text fied
# which we use within Bubble is an exact match to the address_geo filed, which corrresponds to the matching Google API address. There are occasionally mismatches,
# but most of them can be resolved. The borough is usually an issue as Google API inconsistently uses it (may use the name of the area instead of
# the correct borough, e.g. "Flushing" instead of "Queens"). For this reason, boroughs are not used in listing address_text and the checks
# between Google API addresses and NYC Open Data addresses is done by matching house number + street name + zipcode.

library(stringr)
library(readr)
library(tidyverse)

export_file = read.csv('/Volumes/NDB_HDD/final/final_geospatial/export_All-Properties-modified---_2023-06-15_11-20-09.csv')

# Define function to extract city, zip code and country from the address fields
tidy_fun <- function(x) {
  substring(x,nchar(x)-12,nchar(x)) 
}

# Define function to compare house number, street and zipcode between address_text (NYC Open Data) and address_geo (Google API data)
flag_fun <- function(x1,x2,y1,y2) {
  if ((tolower(x1)==tolower(x2)) && (tolower(y1)==tolower(y2))){
    1
  }
  else
  {
    0
  }
}

export_file = export_file %>% dplyr::mutate(geo_street_num=str_replace_all(sapply(strsplit(address_geo,","),"[",1)," ",""),
                                     text_street_num=str_replace_all(sapply(strsplit(address_text,","),"[",1)," ",""),
                                     geo_zipcode=lapply(address_geo,tidy_fun),
                                     text_zipcode=lapply(address_text,tidy_fun))

export_file_clean = export_file %>% dplyr::mutate(flag = mapply(flag_fun,geo_street_num,text_street_num,geo_zipcode,text_zipcode),
                                     datetime = lapply(Creation.Date,function (x) as.POSIXct(x, format = "%b %d, %Y %I:%M %p")))

export_latest = export_file_clean  %>%  dplyr::filter(flag==1) %>% dplyr::filter(datetime > as.POSIXct("2023-06-14")) %>%
                                      dplyr::mutate(address_text=address_geo) %>% dplyr::select(address_short,address_geo,address_text,score,score_verbal)


export_latest = export_latest  %>% dplyr::filter(.,address_geo != "113- 10 157th St, Queens, NY 11433, USA" &
                                                   address_geo != "158-14 Cross Bay Blvd, Queens, NY 11414, USA",
                                                   address_geo != "1340 3 Ave, Manhattan, NY 10021, USA",
                                                   address_geo != "925 Kings Hwy, Brooklyn, NY 11223, USA"
                                                  
                                                 ) 


write_csv(export_latest,'/Volumes/NDB_HDD/final/final_geospatial/export_file_cleanaddresses_latestrecords.csv')


