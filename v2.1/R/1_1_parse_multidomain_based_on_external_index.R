# script to break down the domain into tiles associated with LiDAR returns. 
# essentially this breaks down the footprint domain into manageable pieces
# This was only used for NYC analysis so far!

#######################################################
#                    import libs                      #
#######################################################

library(tidyverse)
library(sf)

#######################################################
#                  define io params                   #
#######################################################

footprint_file = '/mnt/hdd/data/dirtSAT_NYC_data/raw/building_footprints_shape/building_0716.shp'
index_file = '/mnt/hdd/data/dirtSAT_NYC_data/raw/NYC_Topobathy2017_DEM_Index/NYC_Topobathy2017_DEM_Index.shp'
tiles_out_file_base_name = '/mnt/hdd/data/dirtSAT_NYC_data/processed/vector/tiled_footprints/NYC_building_footprints_'

#######################################################
#      parse footprints by tile domain                #
#######################################################

#import building footprint
footprints = read_sf(footprint_file)

#import the index file (shows the indexing schema for DEM and DSM files)
index = read_sf(index_file) %>%
  mutate(name_id = parse_number(FILENAME) %>%
           str_pad(., 3, pad = "0")) %>%
  st_transform(., st_crs(footprints))

#loop through the tiles and find intersecting footprints, write them out. 
for(i in i:length(index$name_id)){
  temp_index = index[i,]
  temp_footprint = footprints %>%
    filter(st_intersects(geometry, temp_index, sparse = FALSE))
  write_sf(temp_footprint, paste0(tiles_out_file_base_name, temp_index$name_id, '.geojson'))
}
