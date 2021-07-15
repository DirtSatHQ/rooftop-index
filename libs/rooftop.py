import richdem as rd
import numpy as np

def create_slope_arr(dsm_rio):
   """Calculates slope of DSM raster

   Args:
       dsm_rio (rio): rasterio object containing surface elevations

   Returns:
       np.array: array of slope values as degrees
   """
   
   nodata = dsm_rio.nodata
   affine = dsm_rio.transform
   geotransform = (affine[2], 
                   affine[0], 
                   affine[1], 
                   affine[5], 
                   affine[3], 
                   affine[4])
   crs = dsm_rio.crs.to_proj4()
   dsm_arr = dsm_rio.read(1).astype('float64')
   dsm_rd = rd.rdarray(dsm_arr, no_data=nodata)
   dsm_rd.geotransform = geotransform
   dsm_rd.projection = crs
   slope = rd.TerrainAttribute(dsm_rd, attrib='slope_degrees')
   return np.array(slope)

def create_height_arr(dsm_rio, hfdem_rio):
   """Calculates structure height

   Args:
       dsm_rio (rio): rasterio object containing surface elevations
       hfdem_rio (rio): rasterio object containing ground elevations

   Returns:
       np.array: numpy array of height above ground surface
   """
   dsm_arr = dsm_rio.read(1).astype('float64')
   hfdem_arr = hfdem_rio.read(1).astype('float64')
   return dsm_arr - hfdem_arr

def pitched_roof_filter(bldgs):
   pass

def flat_area_disaggregator(bldgs):
   pass

def feature1():
   pass

def feature_builder():
   pass

def index_builder():
   pass