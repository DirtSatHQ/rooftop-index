library(tidyverse)
library(sf)
library(mapview)

cuny = read_sf('/home/zhoylman/dirtSAT_data/raw/CUNY/cuny_buildings_2019/cuny_buildings_2019.shp')

dem_index = read_sf('/home/zhoylman/dirtSAT/data/raw/dem_index/NYC_Topobathy2017_DEM_Index/NYC_Topobathy2017_DEM_Index.shp')

cuny_properties = cuny %>%
  group_by(CUNY_name) %>%
  summarise(union = st_union(geometry),
            extent = st_as_sfc(st_bbox(union)),
            extent_buffer = st_buffer(extent, 1100))


cuny_groups = cuny_properties$extent_buffer %>%
  st_union() %>%
  st_cast(., "POLYGON") %>%
  st_as_sf() %>%
  mutate(id = 1:length(x)) %>%
  group_by(id) %>%
  summarise(extent = st_as_sfc(st_bbox(x)))

map = mapview(list(cuny_properties$union, cuny_groups$extent), 
              layer.name = c('CUNY Properties','CUNY Groups'),
              col.regions = c('red','blue'),
              alpha.regions = c(0.8,0.2),
              legend = list(TRUE, TRUE))+
  mapview(dem_index, col.regions = 'transparent', layer.name = 'DEM Grids',
          alpha.regions = 0, legend = F, hide = T)

map 
mapshot(map, paste0('~/dirtSAT/widget/CUNY_analysis_template.html'), embedresources = T, standalone = T)

