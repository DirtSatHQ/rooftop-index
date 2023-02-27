library(terra)
library(tidyverse)
library(sf)
library(fasterize)
library(raster)

dem = rast('/mnt/hdd/data/dirtSAT_Miami_data/processed/raster/dem_merged_Miami.tif')
footprint = read_sf('/mnt/hdd/data/dirtSAT_Miami_data/processed/vector/tiled_footprints/Miami_tiled_footprint_001.geojson') %>%
  st_set_crs(., st_crs(dem))

dem_no_buildings_raw = mask(dem, footprint, inverse = T)

dem_no_buildings = ifel(dem_no_buildings_raw > 15, NA, dem_no_buildings_raw)

plot(dem_no_buildings)

smoother = terra::focal(dem_no_buildings, 15, fun =  'median', na.rm = T)

footprint$building_bases = exactextractr::exact_extract(smoother, footprint, 'mean')

base_height_raster = fasterize(footprint, raster(dem), 'building_bases') %>%
  rast() %>%
  resample(., dem, method = 'near')

crs(base_height_raster)  <- crs(dem_no_buildings)


modified_dem = ifel(is.na(dem_no_buildings_raw), base_height_raster, dem_no_buildings_raw)

writeRaster(modified_dem, '/mnt/hdd/data/dirtSAT_Miami_data/processed/raster/dem_merged_Miami_modified.tif')
