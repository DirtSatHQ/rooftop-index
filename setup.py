from setuptools import setup, find_packages
import pathlib

here = pathlib.Path(__file__).parent.resolve()

long_description = (here / 'README.md').read_text(encoding='utf-8')

setup(
    name='rooftop', 
    version='0.0.1',
    description='Functions and logic to create an index for urban green spaces.',
    long_description=long_description,
    long_description_content_type='text/markdown',
    url='https://github.com/DirtSatHQ/rooftop-index',
    author='DirtSat, Inc.',
    author_email='colin.brust@umontana.com',
    packages=['rooftop'],
    package_dir={'rooftop': 'libs'},
    python_requires='>=3.8.3, <4',
    install_requires=['rasterio', 'fiona', 'numpy', 'boto3', 'geopandas',
                      'scikit-criteria', 'richdem', 'scikit-learn', 'rasterstats'],  # Optional
)
