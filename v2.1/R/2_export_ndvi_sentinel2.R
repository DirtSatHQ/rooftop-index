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
out_ndvi_tif_file = '/mnt/hdd/data/dirtSAT_Miami_data/raw/ndvi/Miami_full_summer_ndvi.tif' # MIAMI

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

#######################################################
#         define function to compute NDVI             #
#######################################################

# using sentinel data (Harmonized Sentinel-2 MSI: multispectral Instrument, Level-2A)
compute_ndvi = function(img) {
  #select relevant bands
  img_band_selected = img$select("B[4|8]")
  #compute NDVI 
  img_band_selected = img_band_selected$select("B8")$subtract(img_band_selected$select("B4"))$divide(img_band_selected$select("B8")$add(img_band_selected$select("B4")))
  #return ndvi band and rename
  return(img_band_selected$rename('NDVI'))
}

#######################################################
#         compute NDVI from sentinel2 data            #
#######################################################

#import raw Sentinel-2 data
sentinel2 = ee$ImageCollection("COPERNICUS/S2_SR_HARMONIZED")

#compute ndvi for the region of interest 
sentinel2_ndvi = sentinel2$
  #filter Sentinel returns for domain
  filterBounds(roi)$
  #filter out bad data based on cloud probability
  filter(ee$Filter$lte("CLOUDY_PIXEL_PERCENTAGE", 10))$
  #filter for time period of interest here, June through Sept.
  filter(ee$Filter$calendarRange(6, 9, "month"))$
  #map relevant function
  map(compute_ndvi)$
  #compute the mean of the image collection
  mean()$
  #clip to the domain of interest (roi)
  clip(roi)

#######################################################
#         import data to local from GEE               #
#######################################################

ndvi_image = ee_as_raster(sentinel2_ndvi,
                          region = roi,
                          scale = 10)

#######################################################
#            convert to rast and write out            #
#######################################################

ndvi_rast = rast(ndvi_image)
writeRaster(ndvi_rast, out_ndvi_tif_file)
