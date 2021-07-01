# Dirtsat Rooftop Index Development

## Dependencies
- Python and Jupyter Notebooks
- All other python dependencies are listed in the `requirements.txt` file
- Make sure the `pygdal` version matches the gdal version on your local machine. 

## Conceptual diagram
![concept diagram](imgs/RooftopIndexWorkflow.jpg)

## Concept details

### Pitch Filter
[Pitch filter POC notebook](roof_pitch/lidar_roof_pitch.ipynb)

Based on LiDAR data. Filter out any roofs that are greater than 10% slope

(*Colin to fill in more details*)

### Flat Area ID (FAID)
[FAID POC notebook](useable_area/flat_area.ipynb)

Based on LiDAR data. Identify areas within building footprint taht are flat and greater than 1000 sf. Output is a shapefile with an attribute taht connects each polygon to a building footprint. 

This vector data will be used to throughout the MCDA feature development. 

(*Colin to fill in more details*)

### Useable area
[Useable area POC notebook](useable_area/flat_area.ipynb)

Based on LiDAR data. The area within a FAID that could be used to for a farm. 

(*Colin to fill in more details*)

### Slope
Based on LiDAR data. The average slope within a FAID.

### Load volume
Based on LiDAR data. The volume of structures on top of a FAID. 

### Building height
[Height POC notebook](roof_height/roof_height.ipynb)

Based on LiDAR data. The average height above ground surface of FAID.

This is calculated from a raster of structure height. If there is no height raster you can calculate it from subtracting the DSM from the HFDEM. For example, see this [notebook](roof_height/caculate_height_raster.ipynb).  

### Greenness
Based on Sentinel data. Greenness of the rooftop. 

### Closeness to a point
Based on FAID and point data in vector format. 

### Shadows and wind
TBD

### Parapet
TBD
