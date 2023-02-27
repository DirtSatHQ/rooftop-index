#function to compute sentinel greenness for each FAID

#load required libraries
library(reticulate) # allows for python interfacing
library(rgee) # R wrapper for the python GEE library
library(sf) # simple feature library - used for vectors
library(tidyverse) # package for tidy syntax etc
library(geojsonio) # package to send ROI SF objects to GEE

#set up the gee environment
use_condaenv("gee", conda = "auto",required = TRUE)
ee = import("ee")
ee_Initialize(drive = TRUE)

# using sentinel data (Harmonized Sentinel-2 MSI: multispectral Instrument, Level-2A)
compute_ndvi = function(img) {
  #select relevant bands
  img_band_selected = img$select("B[4|8]")
  #compute NDVI 
  img_band_selected = img_band_selected$select("B8")$subtract(img_band_selected$select("B4"))$divide(img_band_selected$select("B8")$add(img_band_selected$select("B4")))
  #return ndvi band and rename
  return(img_band_selected$rename('NDVI'))
}

query_gee = function(roi, FAID_final){
  #import ROI
  roi = roi %>%
    st_geometry() %>%
    sf_as_ee()
  
  #import raw Sentinel-2 data
  sentinel2 = ee$ImageCollection("COPERNICUS/S2_SR_HARMONIZED")
  modis = ee$ImageCollection("MODIS/061/MOD11A1")
  
  #compute ndvi for the region of interest 
  sentinel2_ndvi = sentinel2$
    #filter Sentinel returns for domain
    filterBounds(roi)$
    #filter out badd data based on cloud probability
    filter(ee$Filter$lte("CLOUDY_PIXEL_PERCENTAGE", 10))$
    #filter for time period of interest here, June through Sept.
    filter(ee$Filter$calendarRange(6, 9, "month"))$
    #map relevant function
    map(compute_ndvi)$
    #compute the mean of the image collection
    mean()$
    #clip to the domain of interet (roi)
    clip(roi)
  
  #visualization only works when function is run line by line
  Map$centerObject(roi, zoom = 15)
  Map$addLayer(sentinel2_ndvi)+
    Map$addLayer(FAID_final$geometry %>% sf_as_ee())
  
  #Extract average NDVI values for each FAID
  ee_mean_ndvi= ee_extract(
    x = sentinel2_ndvi,
    y = FAID_final$geometry %>% sf_as_ee(),
    scale = 10,
    fun = ee$Reducer$mean(),
    via = "drive"
  )
  return(ee_mean_ndvi)
}