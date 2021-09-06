# Install the lidR package if it isn't already installed.
if (!require(lidR)) {
  install.packages('lidR')
  library(lidR)
}

las_to_tif <- function(f_dir, out_dir, descriptor = 'lidar') {
  
  # List all raw lidar files in directory
  f_list <- list.files(f_dir, full.names = T, pattern = '.laz') 
  
  # Apply following function to all files
  rast_list <- lapply(f_list, function(x) {
    
    print(paste('Processing ', x))
    
    # Read lidar file
    las <- readLAS(x)
    
    # Extract ground returns and convert to a raster.
    gnd <- filter_ground(las)
    gnd <- grid_canopy(gnd, res = 1, dsmtin())
    
    # Extract all first returns (canopy and buildings) and convert to a raster.
    bldgs <- filter_first(las)
    bldgs <- grid_canopy(bldgs, res = 1, dsmtin())
    
    c(gnd, bldgs)
    
  })
  
  # Extract the ground returns and mosaic into one raster
  gnd <- lapply(rast_list, `[[`, 1)
  gnd$fun <- mean
  gnd$na.rm <- TRUE
  gnd <- do.call(mosaic, gnd)
  
  # Save out ground raster to disk.
  raster::writeRaster(
    gnd, 
    file.path(out_dir, paste0(descriptor, '_dem.tif'))
  )
  
  # Extract the first returns and mosaic into one raster
  bldgs <- lapply(rast_list, `[[`, 2)
  bldgs$fun <- mean
  bldgs$na.rm <- TRUE
  bldgs <- do.call(raster::mosaic, bldgs)
  
  # Save out buildings raster to disk.
  raster::writeRaster(
    bldgs, 
    file.path(out_dir, paste0(descriptor, '_dsm.tif'))
  )
}