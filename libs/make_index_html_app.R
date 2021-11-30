library(mapview)
library(magrittr)

f = "~/Desktop/simple_index_app/missoula_main_index.shp"
ndvi = '~/Desktop/simple_index_app/layers/missoula_ndvi.tif'
lst = '~/Desktop/simple_index_app/layers/missoula_lst.tif'

# f: path to index shapefile
# ndvi: path to NDVI .tif for the index location.
# lst: path to the LST .tif for the index location.
# location: either 'missoula' or 'austin'. The location to generate the map for.
# All these data are available in the roof-index/geospatial/simple_app bucket.
make_map <- function(f, ndvi, lst, location='missoula') {
  
  # Get original index CRS.
  if (location == 'missoula') {
    source_crs = 6514
  } else if (location == 'austin') {
    source_crs = 6343
  }
  
  # Read index shapefile and return a tidy dataframe
  Index <- sf::read_sf(f) %>%
    sf::`st_crs<-`(source_crs) %>% 
    sf::st_transform(4326) %>%
    dplyr::select(-vulnerabil) %>% 
    dplyr::rename(
      'Rank' = 'vul_rank',
      'Flat Area (m^2)' = 'flat_area',
      'Flat Area ID' = 'faid',
      'Avg. Slope (degrees)' = 'avg_slope',
      'Avg. Height (m)' = 'height',
      'Parapet Slope (degrees)' = 'parapet_sl',
      'Load Capacity (m^3)' = 'volume'
    ) %>% 
    dplyr::mutate(dplyr::across(where(is.numeric), round, 4))

  # Read raster layers.
  LST <- raster::raster(lst)
  NDVI <- raster::raster(ndvi)
  
  # Make interactive application with index, ndvi and lst layers.
  m = mapview(
    sf::st_zm(Index), zcol = 'Rank', alpha.regions = 1,
    map.types = c('Esri.WorldImagery', 'CartoDB.Positron'),
    layer.name = 'Index Rank'
    ) + 
    mapview(
      LST, legend = F, alpha.regions = 1,
      col.regions = rev(RColorBrewer::brewer.pal(nrow(Index), 'RdYlBu'))
    ) + 
    mapview(
      NDVI, legend = F, alpha.regions = 1,
      col.regions = RColorBrewer::brewer.pal(nrow(Index), 'YlGn')
    ) 

  # Save interactive application to disk. 
  mapshot(m, url=glue::glue('{location}.html'))
}
