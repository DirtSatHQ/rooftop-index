var NY = ee.FeatureCollection("TIGER/2018/Counties")
  .filter(ee.Filter.or(ee.Filter.eq('NAME', 'New York'), ee.Filter.eq('COUNTYNS', '00974122'),
                        ee.Filter.eq('NAME', 'Bronx'),ee.Filter.eq('COUNTYNS', '00974141'),
                        ee.Filter.eq('NAME', 'Queens')))
var geometry = NY.union()
Map.addLayer(geometry)

Map.centerObject(geometry);

//cloud mask
function maskL8sr(col) {
  // Bits 3 and 5 are cloud shadow and cloud, respectively.
  var cloudShadowBitMask = (1 << 3);
  var cloudsBitMask = (1 << 5);
  // Get the pixel QA band.
  var qa = col.select('pixel_qa');
  // Both flags should be set to zero, indicating clear conditions.
  var mask = qa.bitwiseAnd(cloudShadowBitMask).eq(0)
                 .and(qa.bitwiseAnd(cloudsBitMask).eq(0));
  return col.updateMask(mask);
}

//load the collection:
var col = ee.ImageCollection('LANDSAT/LC08/C01/T1_SR')
    .map(maskL8sr)
    .filter(ee.Filter.calendarRange(6, 9, "month"))
    .filterBounds(geometry)
    .map(function(image){return image.clip(geometry)});

print('coleccion', col);

//image reduction
var image = col.median();

//median
var ndvi1 = image.normalizedDifference(['B5', 'B4']).rename('NDVI');
var ndviParams = {min: 0.10554729676864096, max: 0.41295681063122924, palette: ['blue', 'white', 'green']};

//individual LST images
var col_list = col.toList(col.size());
var LST_col = col_list.map(function (ele) {
  
  var date = ee.Image(ele).get('system:time_start');

  var ndvi = ee.Image(ele).normalizedDifference(['B5', 'B4']).rename('NDVI');
  
  // find the min and max of NDVI
  var min = ee.Number(ndvi.reduceRegion({
    reducer: ee.Reducer.min(),
    geometry: geometry,
    scale: 300,
    maxPixels: 1e9
  }).values().get(0));
  
  var max = ee.Number(ndvi.reduceRegion({
    reducer: ee.Reducer.max(),
    geometry: geometry,
    scale: 300,
    maxPixels: 1e9
  }).values().get(0));
  
  var fv = (ndvi.subtract(min).divide(max.subtract(min))).pow(ee.Number(2)).rename('FV');
  
  var a= ee.Number(0.004);
  var b= ee.Number(0.986);
  
  var EM = fv.multiply(a).add(b).rename('EMM');

  var image = ee.Image(ele);

  var LST = image.expression(
    '(Tb/(1 + (0.00115* (Tb / 1.438))*log(Ep)))-273.15', {
      'Tb': image.select('B10').multiply(0.1),
      'Ep': fv.multiply(a).add(b)
  });

  return ee.Algorithms.If(min, LST.set('system:time_start', date).float().rename('LST'), 0);

}).removeAll([0]);

LST_col = ee.ImageCollection(LST_col);

print("LST_col", LST_col);

/////////////////

//Map.addLayer(ndvi1, ndviParams, 'ndvi');

//select thermal band 10(with brightness tempereature), no calculation 
var thermal= image.select('B10').multiply(0.1);

var b10Params = {min: 200, max: 400, palette: ['blue', 'white', 'green']};

//Map.addLayer(thermal, b10Params, 'thermal');

// find the min and max of NDVI
var min = ee.Number(ndvi1.reduceRegion({
  reducer: ee.Reducer.min(),
  geometry: geometry,
  scale: 300,
  maxPixels: 1e9
}).values().get(0));

var max = ee.Number(ndvi1.reduceRegion({
  reducer: ee.Reducer.max(),
  geometry: geometry,
  scale: 300,
  maxPixels: 1e9
}).values().get(0));

//fractional vegetation
var fv = (ndvi1.subtract(min).divide(max.subtract(min))).pow(ee.Number(2)).rename('FV'); 

//Emissivity
var a= ee.Number(0.004);
var b= ee.Number(0.986);
var EM = fv.multiply(a).add(b).rename('EMM');

var imageVisParam3 = {min: 0.9865619146722164, max:0.989699971371314};

//LST in Celsius Degree bring -273.15
//NB: In Kelvin don't bring -273.15
/*var LST = col.map(function (image){

  var date = image.get('system:time_start');
  
  var LST = image.expression(
    '(Tb/(1 + (0.00115* (Tb / 1.438))*log(Ep)))-273.15', {
    'Tb': thermal.select('B10'),
    'Ep':EM.select('EMM')
  }).float().rename('LST');
  
  return LST.set('system:time_start', date);
  
});

print(LST);*/

var LST = LST_col.median().multiply(100).toInt16().clip(geometry)
/*
Map.addLayer(LST, {min: 2000, max: 3500, palette: [
'040274', '040281', '0502a3', '0502b8', '0502ce', '0502e6',
'0602ff', '235cb1', '307ef3', '269db1', '30c8e2', '32d3ef',
'3be285', '3ff38f', '86e26f', '3ae237', 'b5e22e', 'd6e21f',
'fff705', 'ffd611', 'ffb613', 'ff8b13', 'ff6e08', 'ff500d',
'ff0000', 'de0101', 'c21301', 'a71001', '911003'
]},'LST');

print(
      ui.Chart.image.series({
        imageCollection: LST_col, 
        region: geometry,
        reducer: ee.Reducer.median(),
        scale: 3000, // nominal scale Landsat imagery 
        xProperty: 'system:time_start' // default
      }));
*/
//export LST

// As a reduced Image
 Export.image.toDrive ({
  image: LST, 
  scale: 30,
  folder: 'consulting',
  maxPixels: 10000000000000,
  region: geometry,
  description: 'NYC_full_summer_LST_100scaler'});
