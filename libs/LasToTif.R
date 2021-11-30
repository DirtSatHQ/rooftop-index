# Install the lidR package if it isn't already installed.
if (!require(lidR)) {
  install.packages('lidR')
  library(lidR)
}

# f_dir: path to directory with .laz lidar images
# out_dir: path to directory where the .tif images will be saved.
# descriptor: string that will be prepended to the filename as a description.
# save_each: Whether to save individual .tif files out, or to mosaic them into one larger file. 
las_to_tif <- function(f_dir, out_dir, descriptor = 'lidar', save_each = FALSE) {
  
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
    
    if (save_each) {
      
      raster::writeRaster(
        gnd, 
        file.path(
          out_dir, 
          paste0('dem_', tools::file_path_sans_ext(basename(x)), '.tif'))
      )
      
      raster::writeRaster(
        bldgs, 
        file.path(
          out_dir, 
          paste0('dsm_', tools::file_path_sans_ext(basename(x)), '.tif'))
      )
    } else {
      return(c(gnd, bldgs))
    }
    
  })
  
  if (!save_each) {
    # Extract the ground returns and mosaic into one raster
    gnd <- lapply(rast_list, `[[`, 1)
    if (length(f_list) == 1) {
      gnd <- gnd[[1]]
    } else {
      gnd$fun <- mean
      gnd$na.rm <- TRUE
      gnd <- do.call(mosaic, gnd)
    }
    
    # Save out ground raster to disk.
    raster::writeRaster(
      gnd, 
      file.path(out_dir, paste0(descriptor, '_dem.tif'))
    )
    
    # Extract the first returns and mosaic into one raster
    bldgs <- lapply(rast_list, `[[`, 2)
    if (length(f_list) == 1) {
      bldgs <- bldgs[[1]]
    } else {
      bldgs$fun <- mean
      bldgs$na.rm <- TRUE
      bldgs <- do.call(raster::mosaic, bldgs)
    }
    
    # Save out buildings raster to disk.
    raster::writeRaster(
      bldgs, 
      file.path(out_dir, paste0(descriptor, '_dsm.tif'))
    )
  }
}

