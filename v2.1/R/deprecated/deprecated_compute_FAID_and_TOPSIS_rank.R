#this script computes roof slope, building height and detects parapet 
#this script then filters buildings based on percent of area flatter 
#than a threshold (here 11 degrees) and for 1000ft2 of flat area
#read in libraries
library(sf) #simple features
library(terra) #raster manipulation
library(tidyverse) #syntax and tidy
library(exactextractr) #C++ for spatial extraction
library(spatialEco) #gaussian smoother for raster data
library(stars) #for converting rasters to polygons quickly
library(mapview) #for intereactive plotting
library(MCDA) #package for MCDA analysis
library(magrittr) #package for selecting collumns in tidy form
library(fasterize) #for rasterizing polygon
library(raster) #another raster package needed for fasterize
library(leafpop) #stylizing map widget

`%notin%` = Negate(`%in%`)

tile_ids = list.files('/mnt/hdd/data/dirtSAT_NYC_data/processed/vector/tiled_footprints/') %>%
  as_tibble() %>%
  mutate(id = parse_number(value) %>%
           str_pad(., 3, pad = "0")) %>%
  filter(id %notin% c('032', '033')) %$% # these are empty domains (DSM exists but no buildings)
  id

i = 1

#plot parapet check?
plot_parapet = T

#define hyperperameters
#Maximum slope (in degrees) value at which we consider a rooftop to be 'flat'
slope_threshold = 11
#Minimum percentage of flat area on a roof for the roof to be classified as 'flat'
area_threshold = 9
#area threshold in ft2
abs_area_threshold = 5000

#import tiled data
dsm = rast(paste0('/mnt/hdd/data/dirtSAT_NYC_data/raw/NYC_TopoBathymetric2017_DSM/hh_NYC_',tile_ids[i],'.tif'))
dem = rast(paste0('/mnt/hdd/data/dirtSAT_NYC_data/raw/NYC_TopoBathymetric2017/be_NYC_',tile_ids[i],'.tif'))
lst = (rast('/mnt/hdd/data/dirtSAT_data/processed/raster/lst_clipped.tif')*9/5) + 32
footprint = read_sf(paste0('/mnt/hdd/data/dirtSAT_NYC_data/processed/vector/tiled_footprints/NYC_building_footprints_',tile_ids[i],'.geojson'))

#compute height above ground
hgt_above_ground = dsm - dem

#COMPUTE PARAPET DETECTION DATASETS
#compute buffer for parapet detection (-1m buffer)
inside_buffer = st_buffer(footprint, -3.28084) %>% 
  #remove empty features (small buildings with less than a 1m buffer zone)
  filter(!st_is_empty(.))
#compute parapet_height as the inverse mask of the -1m buffer
parapet_height = terra::mask(hgt_above_ground, inside_buffer, inverse = T) %>%
  #then mask by footprint
  terra::mask(., footprint)
#compute inside building height to compare to parapet height
inside_building_height = terra::mask(hgt_above_ground, inside_buffer)

################################################################
#                      PLOTTING CHECK!                         #
################################################################
if(plot_parapet == T){
  #plot to show inside of building height example
  plot(inside_building_height %>% mask(., footprint$geometry[3] %>% st_as_sf(.))%>%
         terra::crop(., footprint$geometry[3]), main = 'Inside Building Height') 
  plot(footprint$geometry[3], add = T)
  
  #plot to show parapet height example
  plot(parapet_height %>% mask(., footprint$geometry[3] %>% st_as_sf(.), touches = F)%>%
         terra::crop(., footprint$geometry[3]), main = 'Parapet Height') 
  plot(footprint$geometry[3], add = T) 
}
################################################################

#COMPUTE SLOPE BASED METRICS FOR FILTERING AND EXTRACTING
#compute slope
slope = terrain(dsm, 'slope') %>%
  #mask for building footprint
  terra::mask(., footprint) 
#classify based on slope thresholds
pitch_class = (slope <= slope_threshold) %>%
  #replace non-flat pixels as NA
  na_if(., 0)

#COMPUTE BUILDING VOLUME
#compute building volume by multiplying the height (in ft) to the x and y resolution 
#of the raster, in this case, it is a 1x1 ft resolution, but if not, this would normalize
#for the resolution of the raster grid size. !! Make sure all units match !!
volume = hgt_above_ground * (res(hgt_above_ground)[1] * res(hgt_above_ground)[2]) 

#compute dataset to calculate average height of flat class per building
flat_class_height = hgt_above_ground * pitch_class

#IMPLEMENT SLOPE / PITCH FILTER AND EXTRACTION
#extract flat class, total pixels, percent average slope and building info
#these extractions are building specific, whereas FAID specific extractions
#are conducted below
footprint_filtered = footprint %>%
  #compute flat area ft2 = usable area
  mutate(flat_area_ft2 = exact_extract(pitch_class, footprint, 'count') * 
           (res(pitch_class)[1] * res(pitch_class)[1]),
         #compute total roof area
         total_area_ft2 = exact_extract(slope, footprint, 'count')* 
           (res(pitch_class)[1] * res(pitch_class)[1]),
         #compute percent flat area
         percent_flat_area = (flat_area_ft2/total_area_ft2) * 100,
         #compute  average height
         ave_building_height = exact_extract(hgt_above_ground, footprint, 'median'),
         #compute  average parapet height
         ave_rim_height = exact_extract(parapet_height, footprint, 'median'),
         #compute  average inside parapet building height
         ave_inside_height = exact_extract(inside_building_height, footprint, 'median'),
         #take difference for the actual parapet height
         ave_parapet_height = ave_rim_height - ave_inside_height,
         #compute aggregated building volume (no need to multiply by resolution, done above)
         buidling_volume = exact_extract(volume, footprint, 'sum'),
         #average flat class height * area of footprint
         flat_class_volume = exact_extract(flat_class_height, footprint, 'median') * total_area_ft2,
         #compute flat class height to compute load 
         flat_class_height = exact_extract(flat_class_height, footprint, 'median'),
         #compute the "load volume" by subtracting the total volume from the 
         load_volume = buidling_volume - flat_class_volume) %>%
  #filter based on hyperperameter
  filter(percent_flat_area > area_threshold)

#calculate a map of flat areas
#install development version of rcpp otherwise error messages break run
#install.packages("Rcpp", repos="https://rcppcore.github.io/drat")
flat_class_height_raster = fasterize(footprint_filtered, raster(slope), 'flat_class_height') %>%
  rast() %>%
  resample(., hgt_above_ground, method = 'near')

#compute load height above flat area average heaight
load_height = (hgt_above_ground - flat_class_height_raster) * ((hgt_above_ground - flat_class_height_raster)>0)

#compute load volume above flat area height
footprint_filtered = footprint_filtered %>%
  mutate(load_volume2 = exact_extract(load_height, footprint_filtered, 'sum'))

#COMPUTE Flat Area ID (FAID)
#identify areas within building footprint that are flat and greater than 1000 ft2
FAID = ((slope %>%
           #Gaussian smoother, classify based on 45 degree slope
           raster.gaussian.smooth(.)) <= 45) %>%
  #replace non-flat pixels as NA
  na_if(., 0) %>%
  #convert to stars object
  stars::st_as_stars() %>%
  #convert to polygon with merge = True
  sf::st_as_sf(., as_points = FALSE, merge = TRUE) %>%
  #compute area - for multiple lines of initial filters
  mutate(area = st_area(.)) %>%
  #filter for smaller than 5ft - (!!!) in initial v.1 algorithm, potentially redundant?
  dplyr::filter(area %>% as.numeric() > 5) %>%
  #spatial join 
  st_join(., footprint_filtered, largest = TRUE) %>%
  #recompute area - this is of the merged FAIDs
  mutate(FAID_area = st_area(.)) %>%
  #filter for greater than 5000 sq feet of contiguous area
  #this will be done again below, for flat locations, but helps to filter out
  #locations that by definition, will not have 5000 ft2 of flat area
  filter(FAID_area %>% as.numeric() > abs_area_threshold) %>%
  #assign a FAID to each feature
  mutate(FAID = 1:length(FAID_area)) %>%
  #remove uneeded columns 
  dplyr::select(-c(focal_mean, area)) 

#convert back to SF object for final extraction (must reconvert for C++ to work)
FAID_final = st_as_sf(FAID)

#extract flat class, total pixels, percent average slope
FAID_final = FAID_final %>%
  #compute flat area ft2 = usable area
  mutate(flat_area_ft2 = exact_extract(pitch_class, FAID_final, 'count'),
         #compute total roof area
         total_area_ft2 = exact_extract(slope, FAID_final, 'count'),
         #compute FAID height
         FAID_height_above_ground = exact_extract(hgt_above_ground, FAID_final, 'median'),
         #compute average slope
         ave_slope = exact_extract(slope, FAID_final, 'median'),
         #compute percent flat area
         percent_flat_area = (flat_area_ft2/total_area_ft2) * 100,
         #compute average lst
         ave_lst = exact_extract(lst, FAID_final, 'median')) %>%
  #remove buildings that were removed in pitch filter
  filter(bbl %in% footprint_filtered$bbl) %>%
  #filter one more time by area 5k ft2 
  filter(flat_area_ft2 > abs_area_threshold) %>%
  #compute if height is below 100ft (10 stories)
  mutate(FAID_under_100ft = ifelse(FAID_height_above_ground<100, 1, 0))

#compute average NDVI for each FAID
#import the greenness functions for GEE analysis
source('~/dirtSAT/R/gee_funs.R')

#run function to compute NDVI
NDVI = query_gee(roi, FAID_final)

#compute MCDA analysis - TOPSIS analysis
#Technique for Order of Preference by Similarity to Ideal Solution (TOPSIS) 
#is a multiple criteria decision analysis (MCDA) used here
final_results = FAID_final %>%
  #compute TOPSIS rank
  mutate(topsis_rank = FAID_final %>%
           #bind NDVI to the results
           mutate(NDVI = NDVI$NDVI) %>%
           #select appropriate data
           dplyr::select(ave_slope, ave_parapet_height, flat_area_ft2, load_volume2, FAID_height_above_ground, FAID_under_100ft, NDVI, ave_lst) %>% 
           #remove geometry, restricts matrix transformation
           st_drop_geometry() %>%
           #convert to matrix
           as.matrix() %>%
           # 10 or less
           #preform the TOPSIS analysis, optimization criteria justified below
           #min for ave_slope, we want flatter green spaces
           #max for ave_parapet_height, higher parapets = greater safety
           #max for flat_area_ft2, we want big green spaces
           #min for load_volume, less shade from obstructions, pollution 
           #min for FAID_height_above_ground, overcome urban heat effect and minimize shade from adjustment buildings
           #max for FAID_under_100ft, 1 = less than 100ft, 0 = greater than
           #min for NDVI, want to de-prioritize already green roofs
           #min for ave_lst, want cooler rooftops 
           #ASSUMES EQUAL WEIGHTING!!! (hense rep(1,6)) = 1 weight for each variable
           TOPSIS(., rep(1,8), c('min', 'max', 'max', 'min', 'min', 'max', 'min','min')) %>%
           #convert back to tibble
           as_tibble() %>%
           #compute rank (higher rank = better)
           mutate(rank = rank(-value)) %$%
           #select rank and bind to the table
           rank) %>%
  #bind NDVI to the results
  mutate(NDVI = NDVI$NDVI) %>%
  #select data of interest
  dplyr::select(topsis_rank, FAID, ave_slope, ave_parapet_height, flat_area_ft2, load_volume2, FAID_height_above_ground, NDVI, ave_lst) %>%
  #rename variables to human readable format 
  rename('TOPSIS MCDA Rank (1 = Best)' = topsis_rank, 'Average Slope of FAID (deg)' = ave_slope,
         'Average Building Parapet Height (ft)' = ave_parapet_height,'Flat, Usable Area (ft2)' = flat_area_ft2, 
         'Rooftop Load Volume (ft3)' = load_volume2, 'Average FAID Height Above Ground (ft)' = FAID_height_above_ground, 'NDVI' = NDVI, 
         'Average Summer Surface Temperature (F)' = ave_lst) %>% 
  #finally, transform CRS to a common standard for exporting (WGS84) 
  st_transform(., st_crs(4326))

#extract top 5
final_results_top = final_results %>%
  filter(`TOPSIS MCDA Rank (1 = Best)` %in% c(1:5))

#generate mappable LST dataset
lst_map = lst %>% 
  project(., crs('EPSG:4326')) %>%
  crop(., final_results) %>%
  raster() 
crs(lst_map) <- "+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0" 

#plot results 
mapview_all = mapview(footprint, col.regions = 'black', alpha.regions = 1, hide = TRUE, layer.name = 'Origninal Footprint', map.types = c('CartoDB.Positron','Esri.WorldImagery'), legend = F)+
  mapview(final_results, zcol = 'TOPSIS MCDA Rank (1 = Best)', layer.name = 'MCDA Rank', col.regions=list("forestgreen","yellow",'red'),
          popup = popupTable(final_results %>% st_drop_geometry(), feature.id = FALSE, row.numbers = F, className = "mapview-popup"))+
  mapview(final_results_top, zcol = 'TOPSIS MCDA Rank (1 = Best)', layer.name = 'MCDA Rank (TOP 5)', col.regions=list("forestgreen","yellow",'red'),
          popup = popupTable(final_results_top %>% st_drop_geometry(), feature.id = FALSE, row.numbers = F, className = "mapview-popup"), hide = T, legend = F)+
  mapview(lst_map, hide = T, layer.name = 'Summer LST (°F)', legend = T)

#write out widget
mapshot(mapview_all, paste0('~/dirtSAT/widget/', config_data$out_name, '.html'), embedresources = T, standalone = T)

#write out geospatial data (reproject to wgs84 for geojson export)
write_sf(final_results, paste0('~/dirtSAT/data/final/', config_data$out_name, '.geojson'))
