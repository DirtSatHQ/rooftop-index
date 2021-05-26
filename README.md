# Dirtsat Rooftop Index Development

## Layers
- **Roof Pitch:** This layer uses a convolutional neural network of NAIP imagery to classify rooftops as either pitched or not pitched.

- **Useable Area:** This layer is based on LiDAR data. It calculates the useable area as the amount of area with one-foot elevation of the modal elevation of the rooftop.