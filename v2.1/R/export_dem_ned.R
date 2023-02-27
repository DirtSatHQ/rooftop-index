#this script computes sentinel greenness for a domain for interest

#######################################################
#                    import libs                      #
#######################################################

#load required libraries
library(reticulate) # allows for python interfacing
library(rgee) # R wrapper for the python GEE library
library(sf) # simple feature library - used for vectors
library(tidyverse) # package for tidy syntax etc
library(geojsonio) # package to send ROI SF objects to GEE
library(terra)

#######################################################
#               initiate GEE environment              #
#######################################################

#set up the gee environment
use_condaenv("gee-base", conda = "auto", required = TRUE)
ee = import("ee")
ee_Initialize(drive = TRUE)

#######################################################
#                  define io params                   #
#######################################################

#domain_file = '/mnt/hdd/data/dirtSAT_NYC_data/processed/raster/dem_merged_NYC.tif'# - NYC
domain_file = '/mnt/hdd/data/dirtSAT_Miami_data/processed/raster/dem_merged_Miami.tif'# - MIAMI 

#out_ndvi_tif_file = '/mnt/hdd/data/dirtSAT_NYC_data/raw/ndvi/NYC_full_summer_ndvi.tif' # NYC
out_dem_tif_file = '/mnt/hdd/data/dirtSAT_Miami_data/processed/raster/Miami_dem_ned.tif' # MIAMI

#dem template
dem_template = '/mnt/hdd/data/dirtSAT_Miami_data/processed/raster/dsm_merged_Miami_ft.tif'
#######################################################
#             define domain of interest               #
#######################################################
#import the full extent of the domain (here the dem or dsm typically)
domain = rast(domain_file)

#compute extent
extent = ext(domain) %>%
  as.polygons() %>%
  st_as_sf() %>%
  st_set_crs(., crs(domain)) %>%
  st_transform(., st_crs('EPSG:4326'))

#define ROI
roi = extent %>%
  st_geometry() %>%
  sf_as_ee()

#compute ndvi for the region of interest 
ned = ee$Image("USGS/3DEP/10m")$
  #filter out bad data based on cloud probability
  select('elevation')$
  #clip to the domain of interest (roi)
  clip(roi)

#######################################################
#         import data to local from GEE               #
#######################################################

ned_image = ee_as_raster(ned,
                          region = roi,
                          scale = 10)
crs(ned_image) <- "+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0" 

#######################################################
#            convert to rast and write out            #
#######################################################

ned_rast = (rast(ned_image)* 3.28084) %>%
  project(., terra::crs(dem_template %>% rast()))%>%
  resample(., (dem_template %>% rast()))


writeRaster(out_dem_tif_file, out_ndvi_tif_file)
