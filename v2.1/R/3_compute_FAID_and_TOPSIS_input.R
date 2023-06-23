#this script computes roof slope, building height and detects parapet 
#this script then filters buildings based on percent of area flatter 
#than a threshold (here 11 degrees) and for 5000ft2 of flat area

######################################################################
#      import libraries need for analysis and define specials        #
######################################################################

#read in libraries
library(sf) #simple features
library(terra) #raster manipulation
library(tidyverse) #syntax and tidy
library(exactextractr) #C++ for spatial extraction
library(spatialEco) #Gaussian smoother for raster data
library(stars) #for converting rasters to polygons quickly
library(mapview) #for interactive plotting
library(magrittr) #package for selecting columns in tidy form
library(fasterize) #for rasterizing polygon
library(raster) #another raster package needed for fasterize
library(leafpop) #stylizing map widget

#define not in special
`%notin%` = Negate(`%in%`)

######################################################################
#                       define io parameters                         #
######################################################################

# #input data for NYC
footprint_dir = '/Volumes/NDB_HDD/processed/vector/tiled_footprints/'
dsm_dir = '/Volumes/NDB_HDD/processed/raster/tiled_dsm/'
dem_dir = '/Volumes/NDB_HDD/processed/raster/tiled_dem/'
ndvi_dir = '/Volumes/NDB_HDD/raw/ndvi/NYC_full_summer_ndvi.tif'
lst_dir = '/Volumes/NDB_HDD/raw/lst/NYC_full_summer_LST_100scaler.tif'
# 
# #write dir
out_dir = '/Volumes/NDB_HDD/final/tiled_TOPSIS_input/'


#input data for MIAMI
# footprint_dir = '/mnt/hdd/data/dirtSAT_Miami_data/processed/vector/tiled_footprints/'
# dsm_dir = '/mnt/hdd/data/dirtSAT_Miami_data/processed/raster/tiled_dsm/'
# dem_dir = '/mnt/hdd/data/dirtSAT_Miami_data/processed/raster/tiled_dem/'
# ndvi_dir = '/mnt/hdd/data/dirtSAT_Miami_data/raw/ndvi/Miami_full_summer_ndvi.tif'
# lst_dir = '/mnt/hdd/data/dirtSAT_Miami_data/raw/lst/Miami_full_summer_LST_100scaler.tif'

#write dir
# out_dir = '/mnt/hdd/data/dirtSAT_Miami_data/final/tiled_TOPSIS_input/'

######################################################################
#                       define hyperparameters                       #
######################################################################

#define hyperparameters
#Maximum slope (in degrees) value at which we consider a rooftop to be 'flat'
slope_threshold = 11
#Minimum percentage of flat area on a roof for the roof to be classified as 'flat'
area_threshold = 9
#area threshold in ft2
abs_area_threshold = 5000

#define booleen for plot checks
plot_parapet = F
plot_domain = F

######################################################################
#           Compute file locations and location meta (id)            #
######################################################################
#here we are simply computing paths and meta, not pulling in data.
#data will be pulled into memory in the loop

#footprints first 
footprints_files = list.files(footprint_dir, full.names = T) %>%
  as_tibble() %>%
  mutate(id = parse_number(value) %>%
           str_pad(., 3, pad = "0")) %>%
  mutate(footprint = value) %>%
  dplyr::select(-value)

# clears memory space
#rm(footprint_dir)

#then dem
dem_files = list.files(dem_dir, full.names = T) %>%
  as_tibble() %>%
  mutate(id = parse_number(value) %>%
           str_pad(., 3, pad = "0")) %>%
  mutate(dem = value) %>%
  dplyr::select(-value)

# clears memory space
#rm(dem_dir)

#dsm
dsm_files = list.files(dsm_dir, full.names = T) %>%
  as_tibble() %>%
  mutate(id = parse_number(value) %>%
           str_pad(., 3, pad = "0")) %>%
  mutate(dsm = value) %>%
  dplyr::select(-value)

# clears memory space
#rm(dsm_dir)

#left join all the files together by the id meta
files = left_join(footprints_files, dem_files, by = 'id') %>%
  left_join(., dsm_files, by = 'id') %>%
  drop_na()

print(files)

######################################################################
#      import spatial data that is domain wide - LST and NDVI        #
######################################################################

#import NYC wide LST
ndvi = rast(ndvi_dir) %>%
  #reproject to match DEM 
  project(., crs(rast(files$dsm[1])), method = 'near') 

#clears memory space 
#rm(ndvi_dir)

#import NYC wide LST, descale and convert from C to F
lst = (((rast(lst_dir)/100)*9/5) + 32) %>%
  #convert to F
  #reproject to match DEM 
  project(., crs(rast(files$dsm[1])), method = 'near') 

#clears memory space
#rm(lst_dir)

######################################################################
#  define the for loop that will be used to do the tiled analysis    #
######################################################################

#for loop to loop throught tiled domain (there will be duplicate buildings on edges)
#unique FAID filter can be applied at TOPSIS stage to deal with duplicates. 
#for i in length of file ids 
#note, this whole process could be converted into a function or
#a series of functions
for( i in 1:length(files$id)){
  #i=1
  #print domain id to keep track of loop progress
  print(files$id[i])
  
  #use the tictoc package to compute run time per domain
  tictoc::tic()
  
  #######################################################
  #                  import tiled data                  #
  #######################################################
  
  #import tiled data
  dsm = rast(files$dsm[i])
  dem = rast(files$dem[i])
  footprint = read_sf(files$footprint[i]) %>%
    st_set_crs(., st_crs(dem))
  
  #######################################################
  #       compute height above ground and parapet       #
  #######################################################
  
  #compute height above ground
  hgt_above_ground = dsm - dem
  
  #first plot check (domain)
  if(plot_domain == T){
    #png(filename=paste0('/home/zhoylman/dirtSAT/figs/domains/nyc/nyc_domain_',files$id[i],'.png'),
    #    width = 6, height = 6, units = "in", res = 200)
    plot(hgt_above_ground, main = paste0('Height Above Ground (ft)\nDomain = ', files$id[i],', n = ', length(footprint$NAME)))
    plot(footprint$geometry, add = T)
    #dev.off()
  }
  
  #COMPUTE PARAPET DETECTION DATASETS
  #compute buffer for parapet detection (-2ft buffer)
  inside_buffer = st_buffer(footprint, -2) %>% 
    #remove empty features (small buildings with less than a 1m buffer zone)
    filter(!st_is_empty(.))
  #compute parapet_height as the inverse mask of the -1m buffer
  parapet_height = terra::mask(hgt_above_ground, inside_buffer, inverse = T) %>%
    #then mask by footprint
    terra::mask(., footprint)
  #compute inside building height to compare to parapet height
  inside_building_height = terra::mask(hgt_above_ground, inside_buffer)
  
  #compute relative parapet height - this is the difference between theoretical 
  #outter rim of building (computed using the focal mean of the building heights 
  #after masking for the inside height of the building) minus actual height.
  relative_parapet_height = hgt_above_ground - 
    terra::focal(inside_building_height, 
                 w = 3, fun = 'median', na.rm = T) %>%
    #mask to inside buffer
    terra::mask(., inside_buffer, inverse = T)
  
  #clear memory space
  #rm(inside_buffer)
  
  #plot parapet example if desired
  if(plot_parapet == T){
    #plot to show inside of building height example
    #i = 199
    plot(relative_parapet_height %>% mask(., footprint$geometry[i] %>% st_as_sf(.))%>%
           terra::crop(., footprint$geometry[i]), main = 'Relative Parapet Height') 
    plot(footprint$geometry[i], add = T)
    median(values(relative_parapet_height %>% mask(., footprint$geometry[i] %>% st_as_sf(.))%>%
                    terra::crop(., footprint$geometry[i])), na.rm = T)
  }
  
  #######################################################
  #             compute slope based metrics             #
  #######################################################
  
  #compute slope
  slope = terrain(dsm, 'slope') %>%
    #mask for building footprint
    terra::mask(., footprint) 
  #classify based on slope thresholds
  pitch_class = (slope <= slope_threshold) #%>%
  #replace non-flat pixels as NA
  #na_if(., 0)
  NAflag(pitch_class)<-0
  
  #clears some memory
  #rm(dsm)
  
  #compute dataset to calculate average height of flat class per building
  flat_class_height = hgt_above_ground * pitch_class
  
  #######################################################
  #               compute building volume               #
  #######################################################
  
  #compute building volume by multiplying the height (in ft) to the x and y resolution 
  #of the raster, in this case, it is a 1x1 ft resolution, but if not, this would normalize
  #for the resolution of the raster grid size. !! Make sure all units match !!
  volume = hgt_above_ground * (res(hgt_above_ground)[1] * res(hgt_above_ground)[2]) 
  
  #######################################################
  #       implement first slope and pitch filter        #
  #######################################################
  
  #extract flat class, total pixels, percent average slope and building info
  #these extractions are building specific, whereas FAID specific extractions
  #are conducted below
  footprint_filtered = footprint %>%
    #compute flat area ft2 = usable area
    mutate(building_flat_area_ft2 = exact_extract(pitch_class, footprint, 'count') * 
             (res(pitch_class)[1] * res(pitch_class)[1]),
           #compute total roof area
           building_total_area_ft2 = exact_extract(slope, footprint, 'count')* 
             (res(pitch_class)[1] * res(pitch_class)[1]),
           #compute percent flat area
           percent_flat_area = (building_flat_area_ft2/building_total_area_ft2) * 100,
           #compute  average height
           ave_building_height = exact_extract(hgt_above_ground, footprint, 'median'),
           #compute  average parapet height
           ave_rim_height = exact_extract(parapet_height, footprint, 'median'),
           #compute  average inside parapet building height
           ave_inside_height = exact_extract(inside_building_height, footprint, 'median'),
           #compute average relative parapet building height
           ave_parapet_height = exact_extract(relative_parapet_height, footprint, 'median'),
           ########## DEPRECIATED!!!! ############
           #take difference for the actual parapet height ## DEPRECIATED replaced with above!!!!
           #ave_parapet_height = ave_rim_height - ave_inside_height,
           #compute aggregated building volume (no need to multiply by resolution, done above)
           buidling_volume = exact_extract(volume, footprint, 'sum'),
           #average flat class height * area of footprint
           flat_class_volume = exact_extract(flat_class_height, footprint, 'median') * building_total_area_ft2,
           #compute flat class height to compute load 
           flat_class_height = exact_extract(flat_class_height, footprint, 'median')) %>%
    #filter based on hyperperameters, first percent flat area
    filter(percent_flat_area > area_threshold) %>%
    #filter for building footprints bigger than the absolute area thresh hyperparameter
    filter(building_total_area_ft2 > abs_area_threshold)
  
  #clears memory space
  #rm(footprint)
  
  #######################################################
  #           calculate a map of flat areas             #
  #######################################################
  
  #install development version of rcpp otherwise error messages break run
  #install.packages("Rcpp", repos="https://rcppcore.github.io/drat")
  flat_class_height_raster = fasterize(footprint_filtered, raster(slope), 'flat_class_height') %>%
    rast() %>%
    resample(., hgt_above_ground, method = 'near')
  
  #redefine what the working crs is (sometimes raster <-> terra gets confused)
  crs(flat_class_height_raster) = crs(slope)
  
  
  #######################################################
  #                calculate load volume                #
  #######################################################
  
  #now we have a better idea of the final domain (filtering the footprint), 
  #lets clip the domain down further to make these final raster operations more
  #efficient
  hgt_above_ground = terra::mask(hgt_above_ground, footprint_filtered) 
  flat_class_height_raster = terra::mask(flat_class_height_raster, footprint_filtered) 
  slope = terra::mask(slope, footprint_filtered) 
  
  #compute load height above flat area average height
  load_height = (hgt_above_ground - flat_class_height_raster) * ((hgt_above_ground - flat_class_height_raster)>0)
  
  #compute load volume above flat area height
  footprint_filtered = footprint_filtered %>%
    mutate(load_volume_old = exact_extract(load_height, footprint_filtered, 'sum')* 
             (res(pitch_class)[1] * res(pitch_class)[1]))
  
  #######################################################
  #     compute theoretical model of building           #
  #######################################################
  
  small_flat_area_mask = stars::st_as_stars(pitch_class) %>%
    #convert to polygon with merge = True
    sf::st_as_sf(., as_points = FALSE, merge = TRUE) %>%
    #compute area
    mutate(area = st_area(.) %>% as.numeric()) %>%
    #filter to remove load items from rooftop for smoothing (small flat areas)
    filter(area > 500) %>%
    #intersects with the filtered footprints
    st_intersection(., footprint_filtered)
  
  #compute small flat area heights
  flat_regions_height = (hgt_above_ground * pitch_class) %>%
    terra::mask(., small_flat_area_mask)
  
  #compute a slope class to remove walls and abrupt edges (this could be more sophisticated)
  slope_clip_class = (slope < 30 )
  
  #compute the "smoothed" region (first hierarchical interpolation)
  smoothed_region = focal(flat_regions_height, 31, 'mean', na.rm = T)
  
  #conditions based on certainty/ hierarchical structure
  # flat_regions_height > smoothed_region > flat_class_height_raster
  interpolated_domain = ifel(is.na(flat_regions_height), smoothed_region, flat_regions_height) 
  interpolated_domain = ifel(is.na(interpolated_domain), flat_class_height_raster, interpolated_domain)
  
  #plot(interpolated_domain)
  #plot(footprint_filtered$geometry[i], add = T)
  
  #######################################################
  #                  compute load volume                #
  #######################################################
  
  #compute rooftop load relative height
  rooftop_load = (hgt_above_ground - interpolated_domain) * slope_clip_class
  
  #filter for greater than zero (don't want to count negative space)
  rooftop_load = rooftop_load * (rooftop_load > 0) %>%
    #fiter to filtered footprint domain
    terra::mask(footprint_filtered)
  
  #compute rooftop volume load per filtered footprint
  footprint_filtered = footprint_filtered %>%
    mutate(load_volume = exact_extract(rooftop_load, footprint_filtered, 'sum')* 
             (res(rooftop_load)[1] * res(rooftop_load)[1]))
  
  #######################################################
  #             compute Flat Area ID (FAID)             #
  #######################################################
  
  #identify areas within building footprint that are flat and greater than 5000 ft2
  FAID_temp = ((slope %>%
                  #Gaussian smoother, classify based on 45 degree slope
                  raster.gaussian.smooth(.)) <= 45) 
  #replace non-flat pixels as NA
  #na_if(., 0) %>%
  NAflag(FAID_temp)<-0 
  FAID = FAID_temp %>%
    #convert to stars object
    stars::st_as_stars() %>%
    #convert to polygon with merge = True
    sf::st_as_sf(., as_points = FALSE, merge = TRUE) %>%
    #split up FAID geometry by building (see figs/FAID_proximity_issue.png)
    st_intersection(., footprint_filtered$geometry) %>%
    #compute area - for multiple lines of initial filters
    mutate(area = st_area(.)) %>%
    #filter for smaller than 5ft - (!!!) in initial v.1 algorithm, potentially redundant?
    dplyr::filter(area %>% as.numeric() > 5) %>%
    #spatial join 
    st_join(., footprint_filtered, largest = F) %>%
    #recompute area - this is of the merged FAIDs
    mutate(FAID_area = st_area(.)) %>%
    #filter for greater than 5000 sq feet of contiguous area
    #this will be done again below, for flat locations, but helps to filter out
    #locations that by definition, will not have 5000 ft2 of flat area
    filter(FAID_area %>% as.numeric() > abs_area_threshold) %>%
    #assign a FAID to each feature
    mutate(FAID = 1:length(FAID_area)) %>%
    #remove uneeded columns 
    dplyr::select(-c(area)) 
  
  #convert back to SF object for final extraction (must reconvert for C++ to work)
  FAID_final = st_as_sf(FAID) %>%
    distinct(geometry, .keep_all = TRUE)
  
  #######################################################
  #          compute final data for each FAID           #
  #######################################################
  
  #extract flat class, total pixels, percent average slope
  FAID_final = FAID_final %>%
    #compute flat area ft2 = usable area
    mutate(FAID_flat_area_ft2 = exact_extract(pitch_class, FAID_final, 'count'),
           #compute total roof area
           FAID_total_area_ft2 = exact_extract(slope, FAID_final, 'count'),
           #compute FAID height
           FAID_height_above_ground = exact_extract(hgt_above_ground, FAID_final, 'median'),
           #compute average slope
           FAID_ave_slope = exact_extract(slope, FAID_final, 'median'),
           #compute percent flat area
           FAID_percent_flat_area = (FAID_flat_area_ft2/FAID_total_area_ft2) * 100,
           #compute average lst
           FAID_ave_lst = exact_extract(lst, FAID_final, 'median'),
           #compute average NDVI
           FAID_ave_ndvi = exact_extract(ndvi, FAID_final, 'median')) %>%
    #remove buildings that were removed in pitch filter (I dont think this is necessary)
    #filter(BBL %in% footprint_filtered$BBL) %>%
    #filter one more time by area 5k ft2 
    filter(FAID_flat_area_ft2 > abs_area_threshold) %>%
    #compute if height is below 100ft (10 stories)
    mutate(FAID_under_100ft = ifelse(FAID_height_above_ground<100, 1, 0))
  
  #write out geospatial data (reproject to wgs84 for geojson export)
  write_sf(FAID_final, paste0(out_dir, 'TOPSIS_input_tile_', files$id[i], '.geojson'))
  
  #memory management, remove all but identifier objects 
  rm(list=setdiff(ls(), c('footprints_files', 'dem_files', 'dsm_files', 'files',
                          'i', 'ndvi', 'lst', 'slope_threshold', 'area_threshold',
                          'abs_area_threshold', 'plot_parapet', 'plot_domain', 'out_dir')))
  #garbage clean up, clear unused memory
  gc(); gc()
  
  tictoc::toc()
  
  #end of loop!
  #}
  
  #fin!
  