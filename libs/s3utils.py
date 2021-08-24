#%%
import boto3
from pathlib import Path
import rasterio
import fiona
from fiona.session import AWSSession
import geopandas as gpd
import numpy as np
import zipfile
from io import BytesIO
import os
import shutil
from fiona.io import ZipMemoryFile
from io import BytesIO
import zipfile

#%%
s3_res = boto3.resource('s3')
s3_client = s3_res.meta.client

# %%
class S3Helper(object):

    """
    Class with helper functions to read and process data in S3
    """

    def __init__(self, bucket):
        self.bucket = bucket
        self.resource = s3_res 
        self.client = s3_client

    def list_folders(self, path):
        """Returns list all folders in prefix"""
        res_list = []
        paginator = self.client.get_paginator('list_objects')
        
        for result in paginator.paginate(Bucket=self.bucket, Prefix=path, Delimiter='/'):
            for p in result.get('CommonPrefixes', []):
                res_list.append(p.get('Prefix'))
        return res_list

    def list_files_of_type(self, path, suffix='csv'):
        """Returns list of files in prefix with specified suffix"""
        res_list = []
        paginator = self.client.get_paginator('list_objects')
        for result in paginator.paginate(Bucket=self.bucket, Prefix=path, Delimiter='/'):
            for p in result.get('Contents', []):
                key = p['Key']
                if key.endswith(suffix):
                    res_list.append(p['Key'])
        return res_list

    def list_zipped_shps(self, zip_path):
        """Returns tuple of shapefile names within zip file

        Args:
            zip_path (str): S3 path to zipfile (e.g. 'missoula/geospatial/first_interstate_bldg.zip')
        """
        
        bytes_buffer = BytesIO()
        s3_client.download_fileobj(Bucket=self.bucket, Key=zip_path, Fileobj=bytes_buffer)
        zipshape = zipfile.ZipFile(bytes_buffer)
        shpnames = [f for f in zipshape.namelist() if '.shp' == f[-4:] and '__MACOSX' not in f]
        dbfnames = [f for f in zipshape.namelist() if '.dbf' == f[-4:] and '__MACOSX' not in f]
        shxnames = [f for f in zipshape.namelist() if '.shx' == f[-4:] and '__MACOSX' not in f]
        return shpnames[0], shxnames[0], dbfnames[0]
    
    def read_shp_from_s3_as_gpd(self, path):
        """Gets zipped shapefile from S3 bucket and returns as Geopandas DF

        Args:
            path (str): path to zipped shapefile
        """
        full_path = 'zip+s3://' + self.bucket + '/' + path
        with fiona.Env(session=AWSSession(boto3.Session())):
            gdf = gpd.read_file(full_path)
        return gdf
    
    def read_tif_from_s3_as_rio(self, path, s3=True):
        """Gets geotiff from s3 bucket and returns as rasterio object

        Args:
            path (str): path to geotiff
            s3 (bool): set as True if file is in s3
        """
        if s3:
            full_path = 's3://' + self.bucket + '/' + path
        else:
            full_path = path
        return rasterio.open(full_path)
        
    def write_gdf_to_s3(self, gdf, path):
        """Writes geopandas dataframe to S3 as a zipped shapefile
        Args:
            gdf (gdf): Geopandas DataFrame to be written S3 bucket
            path (str): full path including filename (e.g. missoula/geospatial/test.zip)
        """
        tempdir = 'temp/'
        fname = path.split("/")[-1].split('.')[0]
        ftype = path.split('.')[-1]
        
        if not os.path.isdir(tempdir):
            os.mkdir(tempdir)

        gdf.to_file(filename=tempdir + fname, driver='ESRI Shapefile')
        shutil.make_archive(tempdir + fname, ftype, tempdir + fname)
        s3_res.Bucket('roof-index').put_object(
            Key=path,
            Body=open(tempdir + fname + '.' + ftype, 'rb')
        )
        print(fname + '.' + ftype + " has been successfully written to your S3 bucket.")
        shutil.rmtree(tempdir)

    def write_raster_to_s3(self, arr, path, meta):
        """Writes numpy array to S3 as a geotiff

        Args:
            arr (arr): numpy array
            path (str): full path including filename (e.g. missoula/geospatial/test.tiff)
            meta (dict): meta data for geotiff creation
        """

        tempdir = 'temp/'
        fname = path.split("/")[-1]
        
        # Expand dimentions of array
        arr = np.expand_dims(arr, axis=0)
        
        if not os.path.isdir(tempdir):
            os.mkdir(tempdir)

        with rasterio.open(tempdir + fname, 'w', **meta) as f:
            f.write(arr)

        s3_res.Bucket(self.bucket).put_object(
            Key=path,
            Body=open(tempdir + fname, 'rb')
        )
        
        print(fname + " has been successfully written to your S3 bucket.")
        shutil.rmtree(tempdir)


# %% TEST shapefile read/write
# path = 'missoula/geospatial/'
# S3 = S3Helper('roof-index')
# gdf = S3.read_shp_from_s3_as_gpd(path + 'downtown_bldgs.zip')
# S3.write_gdf_to_s3(gdf, path + 'test3.zip')

# %% Test geotiff read/write
# S3 = S3Helper('roof-index')
# path = 'missoula/geospatial/'
# gt = S3.read_tif_from_s3_as_rio(path + 'downtown_dsm.tif')
# gt_arr = gt.read(1)
# gt_meta = gt.profile
# S3.write_raster_to_s3(gt_arr, 'missoula/geospatial/test.tif', gt_meta)
