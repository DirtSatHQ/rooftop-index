#this script computes the MCDA/TOPSIS analysis, filters for a domain
#of interest, in this case the CUNY footprints, and generates the 
#HTML widget and saves out final data. 

#######################################################
#                    import libs                      #
#######################################################

library(tidyverse)
library(sf)
library(magrittr)
library(MCDA) #package for MCDA analysis
library(terra)
library(raster)
library(mapview)
library(leafpop) #stylizing map widget

#######################################################
#              define io parameters                   #
#######################################################

# NYC input parameters
# #define if you want to filter the tiled results (here T as we are interested in the 
# #CUNY buildings that were processed across the entire NYC run)
filter_tiled_input = T
# #if true, define the footprints of intterest
footprints_of_interest_file = '/Users/nathaliedescusse-brown/Documents/DirtSat/Engineering/Index/rooftop-index/v2.1/R/building_footprints_shape/building_0716.shp'
# #crs template for transfomations
crs_template_file = '/Volumes/NDB_HDD/processed/raster/tiled_dem/dem_clipped_001.tif'
# #define where the tiled TOPSIS input is
tiled_TOPSIS_input_dir = '/Volumes/NDB_HDD/final/tiled_TOPSIS_input'
# #define where the LST raster is for mapping
lst_file = '/Volumes/NDB_HDD/raw/lst/NYC_full_summer_LST_100scaler.tif'
# #define the locations for export of final widget and geojson file
out_widget_file = '/Volumes/NDB_HDD/final/widget/NYC_results.html'
out_geojson_file = '/Volumes/NDB_HDD/final/final_geospatial/final_NYC_results.geojson'

# MIAMI input parameters
#define if you want to filter the tiled results (here T as we are interested in the
#CUNY buildings that were processed across the entire NYC run)
# filter_tiled_input = F
# #if true, define the footprints of intterest
# footprints_of_interest_file = '/mnt/hdd/data/dirtSAT_Miami_data/processed/vector/tiled_footprints/Miami_tiled_footprint_001.geojson'
# #crs template for transfomations
# crs_template_file = '/mnt/hdd/data/dirtSAT_Miami_data/processed/raster/tiled_dem/dem_clipped_001.tif'
# #define where the tiled TOPSIS input is
# tiled_TOPSIS_input_dir = '/mnt/hdd/data/dirtSAT_Miami_data/final/tiled_TOPSIS_input'
# #define where the LST raster is for mapping
# lst_file = '/mnt/hdd/data/dirtSAT_Miami_data/raw/lst/Miami_full_summer_LST_100scaler.tif'
# #define the locations for export of final widget and geojson file
# out_widget_file = '/mnt/hdd/data/dirtSAT_Miami_data/final/widget/Miami_results.html'
# out_geojson_file = '/mnt/hdd/data/dirtSAT_Miami_data/final/final_geospatial/final_Miami_results.geojson'

#######################################################
#              import crs template                    #
#######################################################

crs_template = rast(crs_template_file)

#######################################################
#             import CUNY footprints                  #
#######################################################

footprints_of_interest = read_sf(footprints_of_interest_file) %>%
  st_set_crs(., st_crs(crs_template)) %>%
  #transform coordinate reference frame to WGS48 - common in mapping
  st_transform(., st_crs('EPSG:4326'))

#######################################################
#    import tiled results from previous script        #
#######################################################

tiled_results = list.files(tiled_TOPSIS_input_dir, full.names = T) %>%
  purrr::map(., read_sf)

#merge results and set crs, then transform to WGS84
merged = tiled_results %>%
  bind_rows() %>%
  st_set_crs(st_crs(crs_template)) %>%
  st_transform(., st_crs('EPSG:4326'))

#######################################################
# remove parking lots or any FAID with height < 10ft  #
#######################################################

#sets minimum for FAID height above ground in ft in order to filter out most, if not all, parking lots
faid_height_threshold = 10

merged = merged %>%
  # removes FAID with height above ground below 10 ft in order to eliminate most parking lots
  filter(FAID_height_above_ground > faid_height_threshold)

#######################################################
#               compute MCDA/TOPSIS                   #
#######################################################

#compute MCDA analysis - TOPSIS analysis
#Technique for Order of Preference by Similarity to Ideal Solution (TOPSIS)
#is a multiple criteria decision analysis (MCDA) used here

# Then we can used the cleaned dataset to compute TOPSIS rankings
final_results = merged %>%
  #compute TOPSIS rank
  mutate(topsis_score = merged %>%
           #compute TOPSIS rank
           #mutate(topsis_rank = merged %>%
           #select appropriate data
           dplyr::select(#FAID_ave_slope, 
             #ave_parapet_height, 
             FAID_flat_area_ft2, 
             load_volume, 
             FAID_height_above_ground, 
             FAID_under_100ft, 
             FAID_ave_ndvi, 
             FAID_ave_lst
           ) %>%
           #remove geometry, restricts matrix transformation
           st_drop_geometry() %>%
           #convert to matrix
           as.matrix() %>%
           # 10 or less
           #preform the TOPSIS analysis, optimization criteria justified below
           #min for ave_slope, we want flatter green spaces
           #max for ave_parapet_height, higher parapets = greater safety
           #max for flat_area_ft2, we want big green spaces
           #max for load_volume, as sign that rooftop can take more load
           #min for FAID_height_above_ground, overcome urban heat effect and minimize shade from adjustment buildings
           #max for FAID_under_100ft, 1 = less than 100ft, 0 = greater than
           #min for NDVI, want to de-prioritize already green roofs
           #max for ave_lst, want rooftops to lower ave_lst
           #ASSUMES EQUAL WEIGHTING!!! (hense rep(1,6)) = 1 weight for each variable
         TOPSIS(., c(0.2,0.2,0.2,0.1,0.1,0.2), c( 'max', 'max','min','max','min','max')) %>%
           #convert back to tibble
           as_tibble() %>% mutate(score = value) %$% score) 

final_results = final_results %>%    
  mutate(topsis_rank = rank(-topsis_score)) 

final_results = final_results %>%
  #select data of interest
  dplyr::select(topsis_rank, topsis_score,DOITT_ID, FAID, FAID_ave_slope, FAID_under_100ft,ave_parapet_height, FAID_flat_area_ft2,load_volume, FAID_height_above_ground, FAID_ave_ndvi, FAID_ave_lst,FAID_total_area_ft2,FAID_percent_flat_area) %>%
  #rename variables to human readable format
  rename('TOPSIS MCDA Rank (1 = Best)' = topsis_rank,'TOPSIS score' = topsis_score,'Average Slope of FAID (deg)' = FAID_ave_slope,
         'Average Building Parapet Height (ft)' = ave_parapet_height,'Flat, Usable Area (ft2)' = FAID_flat_area_ft2,
         'Flat, Total Area (ft2)' = FAID_total_area_ft2, 'Usable Percent of Flat, Total Area (ft2)' = FAID_percent_flat_area,
         'Rooftop Load Volume (ft3)' = load_volume, 'Average FAID Height Above Ground (ft)' = FAID_height_above_ground, 'NDVI' = FAID_ave_ndvi,
         'Average Summer Surface Temperature (F)' = FAID_ave_lst) %>%
  #finally, transform CRS to a common standard for exporting (WGS84)
  st_transform(., st_crs(4326))

#extract top 5
final_results_top = final_results %>%
  filter(`TOPSIS MCDA Rank (1 = Best)` %in% c(1:5))

#######################################################
#      import rasters and preprocess for mapping      #
#######################################################

#import NYC wide LST, descale and convert from C to F
lst = (((rast(lst_file)/100)*9/5) + 32) %>%
  #convert to F
  #reproject to match DEM
  project(., crs(crs_template), method = 'near')

#generate mappable LST dataset
lst_map = lst %>%
  project(., crs('EPSG:4326')) %>%
  terra::crop(., final_results) %>%
  raster()
#crs(lst_map) <- "+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0"

#######################################################
#        map results and generate HTML widget         #
#######################################################

#plot results - comment out map except for Top 5 as too many buildings to display on a map
mapview_all = #mapview(footprints_of_interest, col.regions = 'black', alpha.regions = 0.5, hide = TRUE, layer.name = 'Origninal Footprint', map.types = c('CartoDB.Positron','Esri.WorldImagery', 'OpenStreetMap'), legend = F)
# +
#   mapview(final_results, zcol = 'TOPSIS MCDA Rank (1 = Best)', layer.name = 'MCDA Rank', col.regions=list("forestgreen","yellow",'red'),
#           popup = popupTable(final_results %>% st_drop_geometry(), feature.id = FALSE, row.numbers = F, className = "mapview-popup"))+
   mapview(final_results_top, zcol = 'TOPSIS MCDA Rank (1 = Best)', layer.name = 'MCDA Rank (TOP 5)', col.regions=list("forestgreen","yellow",'red'),
           popup = popupTable(final_results_top %>% st_drop_geometry(), feature.id = FALSE, row.numbers = F, className = "mapview-popup"), hide = T, legend = F)
#+
#   mapview(lst_map, hide = T, layer.name = 'Summer LST (°F)', legend = T)

# #write out widget
mapshot(mapview_all, out_widget_file, embedresources = T, standalone = T)

#save final geojson
write_sf(final_results, out_geojson_file)
