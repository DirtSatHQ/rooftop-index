# Merges NYC results with buildings addresses exported as NYC_Address_Points.geojson from NYC Open Data
# https://data.cityofnewyork.us/City-Government/NYC-Address-Points/g6pj-hd8k

library(sf)
library(terra)
library(tidyverse)

address_file = '/Volumes/NDB_HDD/NYC_Address_Points.geojson'

address = read_sf(address_file)

results_file = '/Volumes/NDB_HDD/final/final_geospatial/final_NYC_results.geojson'

results = read_sf(results_file)

mycrstransformedaddresses = st_transform(address,crs(results))

nyc_buildings_withadress <- st_join(results, mycrstransformedaddresses, st_intersects)

write_sf(nyc_buildings_withadress,'/Volumes/NDB_HDD/final/final_geospatial/final_NYC_results_withaddress.geojson')

