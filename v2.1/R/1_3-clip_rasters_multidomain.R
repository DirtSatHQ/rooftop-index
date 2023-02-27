#this script to take full domain mosaic tifs and clip to domain based on footprints
#this is necessary to deal with edge effects and the whole intention of scripts 1.1-1.3
#at this point this has only been used for NYC - Miami domain is small enough to 
#run all at once

#######################################################
#                    import libs                      #
#######################################################

library(terra)
library(tidyverse)
library(sf)
library(doParallel)

#######################################################
#                  define io params                   #
#######################################################
#here are the mosaic tifs for reference, but in parallel we need to read them in
#indivitually for each R process. 
# dem = rast('/mnt/hdd/data/dirtSAT_NYC_data/processed/raster/dem_merged_NYC.tif')
# dsm = rast('/mnt/hdd/data/dirtSAT_NYC_data/processed/raster/dsm_merged_NYC.tif')

dem_file = '/mnt/hdd/data/dirtSAT_NYC_data/processed/raster/dem_merged_NYC.tif'
dsm_file = '/mnt/hdd/data/dirtSAT_NYC_data/processed/raster/dsm_merged_NYC.tif'
footprint_dir = '/mnt/hdd/data/dirtSAT_NYC_data/processed/vector/tiled_footprints/'

dem_out_file_base = '/mnt/hdd/data/dirtSAT_NYC_data/processed/raster/tiled_dem/dem_clipped_'
dsm_out_file_base = '/mnt/hdd/data/dirtSAT_NYC_data/processed/raster/tiled_dsm/dsm_clipped_'

#######################################################
#               compute file locations                #
#######################################################


#compute location and meta data of each domain (tiled footprints)
files = list.files(footprint_dir,
                   full.names = T) %>%
  as_tibble()%>%
  mutate(name_id = parse_number(value) %>%
           str_pad(., 3, pad = "0"))

#######################################################
#                 set up cluster                      #
#######################################################

#set up multi processing (4 threads [think of as 4 cores])
cl = makeCluster(4)
registerDoParallel(cl)

#######################################################
#                   foreach loop                      #
#######################################################

#foreach loop- for loop but in parallel
out = foreach(i = 1:length(files$value)) %dopar% {
  #load required libs
  library(terra)
  library(tidyverse)
  library(sf)
  
  #import raw data for each r instance
  dem = rast(dem_file)
  dsm = rast(dsm_file)
  
  #define domain
  temp_domain = read_sf(files$value[i])
  
  #if it is not an empty domain
  if(length(temp_domain$geometry) != 0){
    #crop dem raster
    temp_cropped_dem = terra::crop(dem, temp_domain)
    
    #write as compressed raster
    writeRaster(temp_cropped_dem, 
                paste0(dem_out_file_base,files$name_id[i], '.tif'),
                gdal=c("COMPRESS=DEFLATE"),
                overwrite = T)
    
    #crop dsm raster
    temp_cropped_dsm = terra::crop(dsm, temp_domain)
    
    #write as compressed raster
    writeRaster(temp_cropped_dsm, 
                paste0(dsm_out_file_base,files$name_id[i], '.tif'),
                gdal=c("COMPRESS=DEFLATE"),
                overwrite = T)
  }
}
stopCluster(cl)
