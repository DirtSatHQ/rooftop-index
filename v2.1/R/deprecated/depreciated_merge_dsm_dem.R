#this script merges dem and dsm datasets. This is required becasue there is
#edge effect issues, see figs/edge_effect_problem.png 
library(tidyverse)
library(magrittr)
library(terra)

#make a list of dsm tifs
dsm_files = list.files('/mnt/hdd/data/dirtSAT_NYC_data/raw/NYC_TopoBathymetric2017_DSM', full.names = T) %>%
  as_tibble() %>%
  filter(str_detect(value, '.tif$'))

dsm_rast_list = dsm_files %$%
  value %>%
  purrr::map(., rast)

dsm_merge = do.call(terra::mosaic, dsm_rast_list) 

writeRaster(dsm_merge, 
            '/mnt/hdd/data/dirtSAT_NYC_data/processed/raster/dsm_full_NYC.tif',
            gdal=c("COMPRESS=DEFLATE"))

#build gdal command - sudo apt install gdal-bin
cmd_dsm = paste0('gdal_merge.py -o /mnt/hdd/data/dirtSAT_NYC_data/processed/raster/dsm_merged_NYC.tif',
                 paste0(' ', dsm_files$value, collapse = ''))

system(cmd_dsm)
