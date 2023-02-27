#this script to take full domain mosaic tifs and clip to domain based on footprints
#this is necessary to deal with edge effects and the whole intention of scripts 1.1-1.4
#this script is used if we are to run the whole domain all at once

#######################################################
#                    import libs                      #
#######################################################

library(terra)
library(tidyverse)
library(sf)

#######################################################
#                  define io params                   #
#######################################################
dem_file = '/mnt/hdd/data/dirtSAT_Miami_data/processed/raster/dem_merged_Miami_modified.tif'
dsm_file = '/mnt/hdd/data/dirtSAT_Miami_data/processed/raster/dsm_merged_Miami.tif'
footprint_dir = '/mnt/hdd/data/dirtSAT_Miami_data/raw/footprint/'

dem_out_file_base = '/mnt/hdd/data/dirtSAT_Miami_data/processed/raster/tiled_dem/dem_clipped_'
dsm_out_file_base = '/mnt/hdd/data/dirtSAT_Miami_data/processed/raster/tiled_dsm/dsm_clipped_'
footprint_out_file_base = '/mnt/hdd/data/dirtSAT_Miami_data/processed/vector/tiled_footprints/Miami_tiled_footprint_'
#######################################################
#               compute file locations                #
#######################################################

#compute location and meta data of each domain (tiled footprints)
files = list.files(footprint_dir,
                   full.names = T) %>%
  as_tibble()%>%
  mutate(name_id = '001')

#######################################################
#                   foreach loop                      #
#######################################################

#import raw data for each r instance
dem = rast(dem_file)
dsm = rast(dsm_file)

#define domain
temp_domain = read_sf(files$value[1]) %>%
  st_transform(., st_crs(dem))

#write as compressed raster
writeRaster(dem, 
            paste0(dem_out_file_base, files$name_id[1], '.tif'),
            gdal=c("COMPRESS=DEFLATE"),
            overwrite = T)

#write as compressed raster
writeRaster(dsm, 
            paste0(dsm_out_file_base,files$name_id[1], '.tif'),
            gdal=c("COMPRESS=DEFLATE"),
            overwrite = T)

#clip footprint
footprint_clipped = temp_domain %>%
  st_crop(., dsm)

write_sf(footprint_clipped, paste0(footprint_out_file_base, files$name_id[1], '.geojson'))