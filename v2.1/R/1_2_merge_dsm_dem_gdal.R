#this script merges dem and dsm datasets. This is required because there is
#edge effect issues, see figs/edge_effect_problem.png 

#######################################################
#                    import libs                      #
#######################################################

library(tidyverse)
library(magrittr)
library(terra)
library(sf)

#######################################################
#                  define io params                   #
#######################################################

#NYC
#DSM_in = '/mnt/hdd/data/dirtSAT_NYC_data/raw/NYC_TopoBathymetric2017_DSM' # NYC
#DSM_out = '/mnt/hdd/data/dirtSAT_NYC_data/processed/raster/dsm_merged_NYC.tif'# NYC

#DEM_in = '/mnt/hdd/data/dirtSAT_NYC_data/raw/NYC_TopoBathymetric2017' # NYC
#DEM_out = '/mnt/hdd/data/dirtSAT_NYC_data/processed/raster/dem_merged_NYC.tif'# NYC

#Miami
DSM_in = '/mnt/hdd/data/dirtSAT_Miami_data/raw/dsm' # Miami
DSM_out = '/mnt/hdd/data/dirtSAT_Miami_data/processed/raster/dsm_merged_Miami.tif'# Miami - 

DEM_in = '/mnt/hdd/data/dirtSAT_Miami_data/raw/dem' # Miami
DEM_out = '/mnt/hdd/data/dirtSAT_Miami_data/processed/raster/dem_merged_Miami.tif'# Miami

#######################################################
#                   merge DSM files                   #
#######################################################

#make a list of dsm tifs
dsm_files = list.files(DSM_in, full.names = T) %>%
  as_tibble() %>%
  filter(str_detect(value, '.tif$'))

#import raster stack and convert to SpatRasterCollection for merging
dsm_rast_list = dsm_files %$%
  value %>%
  purrr::map(., rast) %>%
  sprc()

#mosaic data into single raster
dsm_merge = terra::mosaic(dsm_rast_list) 

#write it out
writeRaster(dsm_merge, 
            DSM_out,
            gdal=c("COMPRESS=DEFLATE"))

#######################################################
#                   merge DEM files                   #
#######################################################

#DEM - Hydroenforced
#make a list of dem tifs
dem_files = list.files(DEM_in, full.names = T) %>%
  as_tibble() %>%
  filter(str_detect(value, '.tif$'))

#import raster stack and convert to SpatRasterCollection for merging
dem_rast_list = dem_files %$%
  value %>%
  purrr::map(., rast) %>%
  sprc()

#mosaic data into single raster
dem_merge = terra::mosaic(dem_rast_list) 

#write it out
writeRaster(dem_merge, 
            DEM_out,
            gdal=c("COMPRESS=DEFLATE"))