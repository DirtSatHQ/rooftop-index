import richdem as rd
import pandas as pd
import numpy as np
import geopandas as gpd
import rasterstats

class RooftopProc(object):

   def __init__(self, S3, main_dir, dsm_fname, hfdem_fname, bldgs_fname):
      self.S3 = S3
      self.main_dir = main_dir
      self.dsm_rio = S3.read_tif_from_s3_as_rio(main_dir + dsm_fname)
      self.hfdem_rio = S3.read_tif_from_s3_as_rio(main_dir + hfdem_fname)
      self.meta = self.dsm_rio.meta
      self.epsg = self.meta['crs'].to_epsg()
      self.bldgs = S3.read_shp_from_s3_as_gpd(main_dir + bldgs_fname).to_crs(self.epsg)

   def create_slope_arr(self, slope_fname):
      """Calculates slope of DSM raster. Returns as numpy array and writes results 
      to S3 bucket as a geotiff.

      Args:
         slope_fname (str): file name of slope geotiff to be written to S3 bucket

      Returns:
         np.array: array of slope values as degrees
      """
      nodata = self.meta['nodata']
      affine = self.meta['transform']
      geotransform = (affine[2], 
                     affine[0], 
                     affine[1], 
                     affine[5], 
                     affine[3], 
                     affine[4])
      crs = self.dsm_rio.crs.to_proj4()
      dsm_arr = self.dsm_rio.read(1).astype('float64')
      dsm_rd = rd.rdarray(dsm_arr, no_data=nodata)
      dsm_rd.geotransform = geotransform
      dsm_rd.projection = crs
      slope = np.array(rd.TerrainAttribute(dsm_rd, attrib='slope_degrees'))
      self.S3.write_raster_to_s3(slope, self.main_dir + slope_fname, self.meta)
      return slope

   def create_height_arr(self, height_fname):
      """Calculates structure height. Returns as numpy array and writes results to
      S3 bucket as a geotiff.

      Args:
         height_fname (str): file name of height geotiff to be written to S3 bucket. 

      Returns:
         np.array: numpy array of height above ground surface
      """
      dsm_arr = self.dsm_rio.read(1).astype('float64')
      hfdem_arr = self.hfdem_rio.read(1).astype('float64')
      height = dsm_arr - hfdem_arr
      self.S3.write_raster_to_s3(height, self.main_dir + height_fname, self.meta)
      return height

   def _zstats_flat_area(self, x):
      """Used in zonal_stats calculation for sloped area"""
      flat_count = np.ma.sum(x)
      affine = self.meta['transform']
      return flat_count * affine[0] * -affine[4]
   
   def _zstats_total_area(self, x):
      """Used in zonal_stats calculation for total polygon area"""
      total_count = np.count_nonzero(x+100)
      affine = self.meta['transform']
      return total_count * affine[0] * -affine[4]

   def pitched_roof_filter(self, slope_arr, pitch_slope_threshold=11, 
                           pitch_area_threshold=9, convert=True):
      """Filters out roofs that are not flat based on pst and pat hyperparameters

      Args:
          slope_arr (np.array): numpy array with slope values
          pitch_slope_threshold (int, optional): hyperparameter. Defaults to 11.
          pitch_area_threshold (int, optional): hyperparameter. Defaults to 9.
          convert (bool, optional): convert from meters to feet. Defaults to True.

      Returns:
          gpd: Geopandas dataframe of buildings with flat(ish) roofs
      """
      stat_name = 'flat_area'
      slope_arr = np.where(slope_arr > pitch_slope_threshold, 0, 1)
      zstats = rasterstats.zonal_stats(self.bldgs, slope_arr, 
                                       affine=self.meta['transform'],
                                       nodata = self.meta['nodata'],
                                       geojson_out=True, 
                                       add_stats={stat_name: self._zstats_flat_area,
                                                  'total_area': self._zstats_total_area})
      
      gdf = self._add_zstats_to_gpd(zstats, self.bldgs, stat_name)
      gdf = self._add_zstats_to_gpd(zstats, gdf, 'total_area')
      if convert == True:
         gdf[stat_name] = gdf[stat_name]*10.7639
         gdf['total_area'] = gdf['total_area']*10.7639
         
      gdf = gdf.astype({stat_name: np.float64, 'total_area':np.float64}, copy=True)
      gdf[stat_name + '_perc'] = (gdf[stat_name]/gdf['total_area'])*100
      gdf['flat'] = gdf[stat_name + '_perc'] > pitch_area_threshold
      gdf = gdf.loc[gdf['flat']]
      
      return gdf[['fid', 'total_area', stat_name, 'geometry']] 

   def _add_zstats_to_gpd(self, zstats, gdf, name):
      """Adds json zstats to gdf as new column"""
      nlist = []
      for b in zstats:
         b_new = (b['properties']['fid'], b['properties'][name])
         nlist.append(b_new)
         
      new_gdf = gpd.GeoDataFrame(nlist, columns=['fid', name])
      full_gdf = pd.merge(gdf, new_gdf)
      return full_gdf
      

   def flat_area_disaggregator(self):
      
      pass

   def feature1():
      pass

   def feature_builder():
      pass

   def index_builder():
      pass