library(lidR)
library(terra)
library(tidyverse)
library(sf)

las_files = list.files('/mnt/hdd/data/dirtSAT_Miami_data/raw/LAS', full.names = T)
names = list.files('/mnt/hdd/data/dirtSAT_Miami_data/raw/LAS', full.names = F)

for(i in 1: length(las_files)){
  print(i)
  raw = readLAS(las_files[i])
  
  raw = classify_ground(las = raw, algorithm = csf())
  
  dem = grid_terrain(las = raw, res = 1, algorithm = tin()) %>%
    rast()
  
  terra::writeRaster(dem, paste0('/mnt/hdd/data/dirtSAT_Miami_data/raw/dem/dem_', names[i],'.tif'))
  
  dsm = grid_canopy(las = raw, res = 1, algorithm = dsmtin()) %>%
    rast()
  
  terra::writeRaster(dsm, paste0('/mnt/hdd/data/dirtSAT_Miami_data/raw/dsm/dsm_', names[i],'.tif'))
  
  rm(raw, dem, dsm)
  gc(); gc()
  
}