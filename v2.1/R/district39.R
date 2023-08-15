# This script aims at obtaining data for district 39 covering the following:
# Map of green-viable buildings (output of script 4 but limited to District 39)
# Number of green-viable buildings in District 39
# Total number of addresses in District 39, for context
# Total number of building in District 39, for context

library(mapview)
library(sf)
library(terra)


nyc_buildings_file='/Volumes/NDB_HDD/final/final_geospatial/final_NYC_results_withaddress_st_is_within_distance_3_allpolys.geojson'
nyc_buildings=read_sf(nyc_buildings_file)

footprint_file = '/Volumes/NDB_HDD/raw/building_0716.shp'
footprints = read_sf(footprint_file)

address_file = '/Volumes/NDB_HDD/NYC_Address_Points.geojson'
address = read_sf(address_file)

# output file for map of green-viable buildings in District 39
out_widget_file = '/Volumes/NDB_HDD/final/widget/NYC_District39_results.html'

polygon_coords <- matrix(c(
  -74.0, 40.69179,
  -73.99235, 40.68952,
  -73.99363, 40.68708,
  -73.98871, 40.68515,
  -73.98827, 40.68578,
  -73.97958, 40.68244,
  -73.97804, 40.68483,
  -73.97184, 40.67634,
  -73.96946, 40.67585,
  -73.96968, 40.67535,
  -73.96911, 40.67241,
  -73.96186, 40.65481,
  -73.97525, 40.64960,
  -73.97403, 40.64320,
  -73.96871, 40.64382,
  -73.96818, 40.63724,
  -73.96801, 40.63661,
  -73.97809, 40.63551,
  -73.97910, 40.63539,
  -73.99271, 40.64173,
  -73.98038, 40.64765,
  -73.98844, 40.65917,
  -73.99018, 40.65756,
  -73.99244, 40.65881,
  -73.99295, 40.65827,
  -73.99515, 40.65957,
  -73.98628, 40.66911,
  -73.99649, 40.67400,
  -73.99851, 40.67169,
  -74.00829, 40.68612,
  -74.0, 40.69179
  
), ncol = 2, byrow = TRUE)

# Create an sf object for the polygon

polygon_sf <- st_sf(geometry = st_sfc(st_polygon(list(polygon_coords))), crs = 4326)

# View the sf object
#mapview(st_geometry(polygon_sf))

# First we want to view the actual green-viable buildings (the buildings output by scripts 3 and 4)
# Check which building from my nyc_buildings intersect
district39_buildings=st_intersection(nyc_buildings,polygon_sf)

# View intersection
mapview_district39=mapview(district39_buildings,maxpoints = 1000000)

# #write out widget
mapshot(mapview_district39, out_widget_file, embedresources = T, standalone = T)


# Then we print out to screen number of green-viable buildings in District 39
print(paste0('The number of green-viable buildings in District 39 is:', nrow(unique(district39_buildings$DOITT_ID))))


# But we need to put this in context of overall address and buildings in District 39.
# The below aims at identifying number of total buildings and addresses in District 39, 
# to help to put the number of green-viable properties into perspective (i.e. what proportion
# of buildings does that represent)
footprints = footprints %>% st_transform(., st_crs(polygon_sf))

# NUMBER OF ADDRESSES IN DISTRICT 39
# Check which building from my nyc_buildings intersect - the number of rows in the beloa variables
# indicates number of addresses in District 39
district39_buildings_addresses=st_intersection(address,polygon_sf)

print(paste0('The total number of addresses in District 39 is:', nrow(district39_buildings_addresses)))


# NUMBER OF BUILDINGS IN DISTRICT 39
# We can then identify the number of unique BIN (= number of buildings) in District 39 
# with the below
district39_BINs = unique(district39_buildings_addresses$bin)


print(paste0('The total number of buildings in District 39 is:', length(district39_BINs)))