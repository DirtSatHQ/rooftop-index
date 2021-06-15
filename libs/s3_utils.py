#%%
import boto3
import fiona
from fiona.session import AWSSession
import geopandas as gpd
import zipfile
from io import BytesIO

#%%
s3_res = boto3.resource('s3')
s3_client = s3_res.meta.client

# %%
class S3Reader(object):

    """
    Class with helper functions to read and process data in S3
    """

    def __init__(self, bucket):
        self.bucket = bucket
        self.resource = s3_res 
        self.client = s3_client

        #aws_access_key_id="AKIAUVHRVMKCX2I2MPT3",
        #aws_secret_access_key="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"

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
    
    def get_shp_from_s3_to_gpd(self, path):
        """Gets zipped shapefile from S3 bucket and returns as Geopandas DF

        Args:
            path (str): path to zipped shapefile
        """
        full_path = 'zip+s3://' + self.bucket + path
        with fiona.Env(session=AWSSession(boto3.Session())):
            gdf = gpd.read_file(full_path)
        return gdf

# %% TEST
# S3 = S3Reader('roof-index')
# gdf = S3.get_shp_from_s3_to_gpd('/missoula/geospatial/downtown_bldgs.zip')
# %%
