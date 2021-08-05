import richdem as rd
import pandas as pd
import numpy as np
import geopandas as gpd
import rasterstats
import rasterio
import subprocess as sp
import os
import shutil
from shapely.geometry import Polygon, MultiPolygon

class RooftopProc(object):

   def __init__(self, S3, main_dir, dsm_fname, hfdem_fname, bldgs_fname, bldgs_id):
      self.S3 = S3
      self.main_dir = main_dir
      self.dsm_rio = S3.read_tif_from_s3_as_rio(main_dir + dsm_fname)
      self.hfdem_rio = S3.read_tif_from_s3_as_rio(main_dir + hfdem_fname)
      self.meta = self.dsm_rio.meta
      self.epsg = self.meta['crs'].to_epsg()
      self.bldgs = S3.read_shp_from_s3_as_gpd(main_dir + bldgs_fname).to_crs(self.epsg)
      self.bldgs_id = bldgs_id
      
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
      self.slope_arr = slope
      return slope

   def create_height_arr(self, out_fname):
      """Calculates structure height. Returns as numpy array and writes results to
      S3 bucket as a geotiff.

      Args:
         out_fname (str): file name of height geotiff to be written to S3 bucket. 

      Returns:
         np.array: numpy array of height above ground surface
      """

      dsm_arr = self.dsm_rio.read(1).astype('float64')
      hfdem_arr = self.hfdem_rio.read(1).astype('float64')
      height = dsm_arr - hfdem_arr
      self.S3.write_raster_to_s3(height, self.main_dir + out_fname, self.meta)
      self.height_arr = height
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

   def pitched_roof_filter(self, pitch_slope_threshold=11, 
                           pitch_area_threshold=9, convert=True):
      """Filters out roofs that are not flat based on pst and pat hyperparameters

      Args:
          pitch_slope_threshold (int, optional): hyperparameter. Defaults to 11.
          pitch_area_threshold (int, optional): hyperparameter. Defaults to 9.
          convert (bool, optional): convert from meters to feet. Defaults to True.

      Returns:
          gpd: Geopandas dataframe of buildings with flat(ish) roofs
      """
      stat_name = 'flat_area'
      slope_arr = np.where(self.slope_arr > pitch_slope_threshold, 0, 1)
      zstats = rasterstats.zonal_stats(self.bldgs, slope_arr, 
                                       affine=self.meta['transform'],
                                       nodata = self.meta['nodata'],
                                       geojson_out=True, 
                                       add_stats={stat_name: self._zstats_flat_area,
                                                  'total_area': self._zstats_total_area})
      
      gdf = self._add_zstats_to_gpd(zstats, self.bldgs, stat_name, self.bldgs_id)
      gdf = self._add_zstats_to_gpd(zstats, gdf, 'total_area', self.bldgs_id)
      if convert == True:
         gdf[stat_name] = gdf[stat_name]*10.7639
         gdf['total_area'] = gdf['total_area']*10.7639
         
      gdf = gdf.astype({stat_name: np.float64, 'total_area':np.float64}, copy=True)
      gdf[stat_name + '_perc'] = (gdf[stat_name]/gdf['total_area'])*100
      gdf['flat'] = gdf[stat_name + '_perc'] > pitch_area_threshold
      gdf = gdf.loc[gdf['flat']]
      flat_bldgs = gdf[[self.bldgs_id, 'total_area', stat_name, 'geometry']] 
      self.flat_bldgs = flat_bldgs
      return flat_bldgs

   def _add_zstats_to_gpd(self, zstats, gdf, name, join_col):
      """Adds json zstats to gdf as new column

      Args:
          zstats (json): results from zonal_stats
          gdf (gdf): geodataframe to add zstats to
          name (str): name of json property to use for gdf column
          join_col (str): name of common property (json) and column (gdf) to join on
      """
      
      nlist = []
      for b in zstats:
         b_new = (b['properties'][join_col], b['properties'][name])
         nlist.append(b_new)
         
      new_gdf = gpd.GeoDataFrame(nlist, columns=[join_col, name])
      if gdf.empty:
         full_gdf = new_gdf
      else:
         full_gdf = gdf.merge(new_gdf, on=join_col)
      return full_gdf
   
   def polygonize_raster(self, arr):
      """Converts numpy array to vector polygons

      Args:
          arr (np.array): array to be converted to vector polygons
      """
       # Make temporary directory to perform polygonize operations in.

      temp = 'temp'
      if not os.path.isdir(temp):
         os.mkdir(temp)

      # Write raster to temp directory
      f = os.path.join(temp, 'flat_tmp.tif')
      out = rasterio.open(f, 'w', **self.meta)
      out.write(arr[np.newaxis].astype(np.float32))
      out.close()

      # Polygonize and return shapefile
      print('Creating polygons from raster data. Hang on, this may take a bit.')
      sp.call(['gdal_polygonize.py', f, os.path.join(temp, 'polys.shp')])
      flat_vec = gpd.read_file(os.path.join(temp, 'polys.shp'))
      flat_vec = flat_vec.set_crs(self.epsg, allow_override=True)
      flat_vec = flat_vec[flat_vec['DN'] != 0]
      
      # Remove temporary directory
      shutil.rmtree(temp)

      return flat_vec   

   def convert_multipgons_to_pgons(self, gdf):
      """Converts all multipolygons to individual polygons in a gdf.
      See https://gist.github.com/mhweber/cf36bb4e09df9deee5eb54dc6be74d26

      #TODO: Would apply() be faster?

      Args:
          gdf (GeoDataFrame): multipolygon geodataframe to be converted
      """
      
      new_gdf = gpd.GeoDataFrame(columns=gdf.columns)      
      for _, row in gdf.iterrows():
         if type(row.geometry) == Polygon:
               new_gdf = new_gdf.append(row,ignore_index=True)
         if type(row.geometry) == MultiPolygon:
               mult_gdf = gpd.GeoDataFrame(columns=gdf.columns)
               recs = len(row.geometry)
               mult_gdf = mult_gdf.append([row]*recs,ignore_index=True)
               for geom in range(recs):
                  mult_gdf.loc[geom,'geometry'] = row.geometry[geom]
               new_gdf = new_gdf.append(mult_gdf,ignore_index=True)
      return new_gdf
 
   def flat_area_disaggregator(self, bldgs, fa_slope_thresh, fa_area_thresh,
                               out_fname):
      """Disaggregates building footprint polygons to polygons representing flat areas

      Args:
          bldgs (gdf): geodataframe of building footprints (after slope filter)
          fa_slope_thresh (int): slope threshold to determine flat area
          fa_area_thresh (int): minimum area (sf) for defining as a flat area
          out_fname (str): filename for output shapefile
      """

      # If the building slope is less than fa_slope_thresh, classify as flat.
      flat = np.where(self.slope_arr <= fa_slope_thresh, 1, 0)
      
      # Convert flat np.array to polygon.
      flat_vector = self.polygonize_raster(flat)
      
      # Spatial join of buildings and flat areas.
      joined = gpd.overlay(flat_vector.to_crs(self.epsg), bldgs, how='intersection')
      
      # Drop unnecessary column. 
      joined = joined.drop(columns='DN')
      
      # Convert all the multipolygons to individual polygons.
      joined = self.convert_multipgons_to_pgons(joined)
         
      # Calculate area and remove polygons smaller than 1000 sq. ft. 
      # Filter buildings with an area smaller than 1000 Sq. Ft.
      joined['flat_area'] = joined['geometry'].area * 10.7639
      joined = joined[joined['flat_area'] > fa_area_thresh]
      joined = joined.sort_values(by='fid')
      joined['faid'] = range(joined.shape[0])
      
      self.S3.write_gdf_to_s3(joined, self.main_dir + out_fname)
      
      return joined      

   def feature_average_slope(self, rooftops):
      """Calculates average slope of rooftop area. Used in feature_builder()"""
      
      affine = self.meta['transform']
      nodata = self.meta['nodata']
      zstats = rasterstats.zonal_stats(rooftops, self.slope_arr, affine=affine,
                                 nodata=nodata, geojson_out=True,
                                 stats=['mean'])
      gdf = self._add_zstats_to_gpd(zstats, rooftops, 'mean', 'faid')
      gdf.rename(columns={'mean': 'avg_slope'}, inplace=True)
      print('Adding average slope feature now.')
      return gdf

   def feature_height(self, rooftops):
      """Calculates median rooftop height. Used in feature_builder()"""

      affine = self.meta['transform']
      nodata = self.meta['nodata']
      zstats = rasterstats.zonal_stats(rooftops, self.height_arr, affine=affine,
                                       nodata=nodata, geojson_out=True, 
                                       stats='median')
      gdf = self._add_zstats_to_gpd(zstats, rooftops, 'median', 'faid')
      gdf.rename(columns={'median': 'height'}, inplace=True)
      print('Adding median height feature now.')
      return gdf
   
   def _distance_to_nearest_pt(self, rooftops, pts, colname):
      rooftops['centers'] = rooftops.centroid
      rooftops[colname] = rooftops['centers'].apply(lambda x: min([x.distance(y) for y in pts['geometry']]))
      rooftops.drop(columns='centers', inplace=True)
      return rooftops
   
   def feature_closeness_to_pts(self, rooftops, ctp_paths):
      """Calculates closeness to a series of points. Used in feature_builder().
      
      Args: 
         ctp_paths (list): list of file names in S3 bucket to use as points. A
            separate feature is created for each file in the ctp_paths variable. 
      """
      for p in ctp_paths:
         colname = p.split('.')[0]
         pts = self.S3.read_shp_from_s3_as_gpd(self.main_dir + p).to_crs(self.epsg) 
         rooftops = self._distance_to_nearest_pt(rooftops, pts, colname)
         print('Adding closeness to ' + colname + ' feature now.') 
      return rooftops   
   
   def feature_volume_on_roof(self, rooftops):
      """Calculates volume of stuff on top of roof. Used in feature_builder()"""
      
      interiors = self._find_interior_holes(rooftops)
      interiors = self.convert_multipgons_to_pgons(interiors)
      int_height = self._calc_height(interiors, 'interior_height')
      roof_height = self._calc_height(rooftops, 'roof_height')
      roof_volume = self._calc_volume(roof_height, int_height)
      print('Adding volume on roof feature now.')
      return roof_volume
   
   def _find_interior_holes(self, rooftops):
      # Find all interior rings within polygon
      out = []
      for geom in rooftops['geometry']:
         interior_coords = []
         for interior in geom.interiors:
               interior_coords.append(interior.coords)

         out.append(interior_coords)

      # Convert interiors of each polygon into MultiPolygons so they can each be associated with an FAID.
      interiors = []
      for geom in out:
         interiors.append(MultiPolygon([Polygon(geom[i]) for i, _ in enumerate(geom)]))    

      # Create GDF of interior polygons
      interiors = pd.DataFrame({'faid': rooftops['faid'], 'geometry': interiors})
      interiors = gpd.GeoDataFrame(interiors)
      interiors = interiors.drop_duplicates()
      
      return interiors
   
   def _calc_height(self, gdf, colname):
      """Calculates median height of surface"""      

      affine = self.meta['transform']
      nodata = self.meta['nodata']
      zstats = rasterstats.zonal_stats(gdf, self.height_arr, affine=affine,
                                       nodata=nodata, geojson_out=True, 
                                       stats='median')
      false_gdf = pd.DataFrame() 
      new_gdf = self._add_zstats_to_gpd(zstats, false_gdf, 'median', 'faid')
      new_gdf.rename(columns={'median': colname}, inplace=True)
      return gdf
   
   def _calc_volume(self, rooftops, interiors):
      """Calculates volume of interior stuff on a roof"""
      #! This function does not work because of changes in dataframe structure 
      
      interiors['interior_area'] = interiors['geometry'].area * 10.7639
      merged = pd.merge(interiors.drop(columns='geometry'), rooftops, on='faid', how='outer')
      merged['rise'] = merged['interior_height'] - merged['faid_height']
      merged['rise'] = [0 if x < 0 else x for x in merged['rise']]
      merged['volume'] = merged['rise'] * merged['interior_area']
      merged['volume'] = [0 if np.isnan(x) else x for x in merged['volume']] 
      test = merged[['faid', 'volume', 'geometry']]
      output = test.dissolve(by='faid', aggfunc='sum')
      return output  
   
   def _create_bldg_buffer_pgon(self):
      """Used in feature_parapet()"""
      
      # Make gdf that is a boundary of the building
      bounds = self.flat_bldgs['geometry']
      bounds = gpd.GeoDataFrame({'geometry': bounds, 'fid': self.flat_bldgs['fid']})

      # Make gdf that is a 1m buffer around the inside of the building.
      buff = self.flat_bldgs['geometry'].buffer(-1)
      buff = gpd.GeoDataFrame({'geometry': buff, 'fid': self.flat_bldgs['fid']})
      
      # Join the two gdfs to make a ring polygon around the edge of the building
      parapet = gpd.overlay(bounds, buff, how='difference')
      parapet['area'] = parapet['geometry'].area
   
      return parapet
   
   def feature_parapet(self, rooftops):
      """Calculates the median slope of a one meter buffer around the edge of 
      of a building (not a rooftop). Used in feature_builder(). """
      
      affine = self.meta['transform']
      nodata = self.meta['nodata']
      parapet = self._create_bldg_buffer_pgon()
      zstats = rasterstats.zonal_stats(parapet, self.slope_arr, affine=affine,
                                       nodata=nodata, geojson_out=True, 
                                       stats='median')
      new_gdf = pd.DataFrame(self.flat_bldgs['fid'])
      gdf = self._add_zstats_to_gpd(zstats, new_gdf, 'median', 'fid')
      gdf.rename(columns={'median': 'parapet_slope'}, inplace=True)
      full_gdf = rooftops.merge(gdf, on='fid')
      
      print('Adding parapet feature now.')   
      return full_gdf   

   def feature_builder(self, rooftops, features, **kwargs):
      """Main function to build features"""
      
      for f in features:
         func = eval('self.feature_' + f)
         if f == 'closeness_to_pts':
            if 'ctp_paths' in kwargs.keys():
               rooftops = func(rooftops, kwargs['ctp_paths'])
            else:
               print('Oops, there are no ctp_paths for the closeness_to_pts feature.')
         else:
            rooftops = func(rooftops)
         
      return rooftops
         
   def index_builder():
      pass