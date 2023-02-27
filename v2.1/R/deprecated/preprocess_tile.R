# this script clips geospatial data to the correct domain, defined with the ROI object

#read in libraries
library(sf)
library(terra)
library(tidyverse)

#import config data (this tells the script where the raw data files are and defines final name)
config_data = read_csv('~/dirtSAT/config/path_config.txt')
#read in DSM data
dsm = rast(config_data$dsm)
#read in DEM data 
dem = rast(config_data$dem)
#import raw ROI
roi = read_sf(config_data$roi) %>%
  #transform to match CRS of NYC data
  st_transform(., st_crs(dsm))
#read in lst data
lst = rast(config_data$lst) %>%
  #reproject to match DEM 
  project(., crs(dem), method = 'near') %>%
  #mask it to ROI + buffer for viz
  mask(., roi %>% st_buffer(., 10000)) %>%
  #clip domain and remove scaler
  crop(., roi %>% st_buffer(., 10000)) / 100
#import raw data (building footprints and ROI region of interest to begin)
building_footprints = read_sf(config_data$building_footprint) %>%
  #transform to match CRS of NYC data
  st_transform(., st_crs(dsm))
#make valid (fix topological errors) and clip to roi
building_footprints_clipped = st_intersection(building_footprints %>% st_make_valid, roi)
#clip dsm to domain
dsm_clipped = terra::crop(dsm, building_footprints_clipped)
#clip dem to domain
dem_clipped = terra::crop(dem, building_footprints_clipped)
#write out clipped data
write_sf(building_footprints_clipped, '/mnt/hdd/data/dirtSAT_data/processed/vector/building_footprints_clipped.shp')
terra::writeRaster(dsm_clipped, '/mnt/hdd/data/dirtSAT_data/processed/raster/dsm_clipped.tif', overwrite=TRUE)
terra::writeRaster(dem_clipped, '/mnt/hdd/data/dirtSAT_data/processed/raster/dem_clipped.tif', overwrite=TRUE)
terra::writeRaster(lst, '/mnt/hdd/data/dirtSAT_data/processed/raster/lst_clipped.tif', overwrite=TRUE)

#plot it
plot(dsm_clipped)
plot(building_footprints_clipped$geometry, add = T)
