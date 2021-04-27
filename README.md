![header](https://user-images.githubusercontent.com/19319377/116176053-b2e8b100-a6ce-11eb-874a-d2bc5a48bd5e.png)

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.4599644.svg)](https://doi.org/10.5281/zenodo.4599644)
# CU-CellSeg
## ImageJ2 macro for the cell segmentation of multi-channel images

### Segmentation approach
The CU-CellSeg macro implements a "classic" cell segmentation approach with a marker-based cell expansion: 

In short, pixel probability maps for nucleus channels (mandatory) and cell matrix channels (optional) are thresholded and segmented by ImageJ's [watershed algorithm](https://imagej.nih.gov/ij/docs/guide/146-29.html#sub:Watershed) (nuclei) and by the ["Find maxima..." function](https://imagej.nih.gov/ij/docs/guide/146-29.html#sub:Find-Maxima) (cell matrix) to create individual cellular compartments. Typical nucleus channels would be markers for DAPI, dsDNA, or histone. Cell matrix channels could be cytoplasm markers (beta-tubulin, keratin, vimentin, ...) or membrane markers (V-ATPase, HLA class 1, CD8, ...), or both. If no cell matrix channel is specified (default), cell outlines are generated from the expansion of the nuclei outlines by a fixed radius. Both cell matrix options generate non-overlapping cell outlines.

![nuclei](https://user-images.githubusercontent.com/19319377/116176320-34404380-a6cf-11eb-998f-4f9d501c8398.png) ![matrix](https://user-images.githubusercontent.com/19319377/116176328-373b3400-a6cf-11eb-9588-298a12cf4f00.png)
**Figure 1: Segmentation example.** Detail from the center of the composite image (top). Left side: Grayscale dsDNA channel with nuclei outlines (blue). Right side: Grayscale beta-tubulin channel with cell matrix outlines (red).

### Software documentation
The documentation of our macros is located in the corresponding source code: You can view the source code on GitHub by following the links to the macros.

### Software requirements
* The CU-CellSeg macro requires a recent version of the [Fiji](https://fiji.sc/) image processing package.
  * ImageJ2 (>= 1.53e)
  * Bio-Formats (>= 6.6.0)
  * Trainable Weka Segmentation Plugin (>= 3.2.34)

### Example files
The [example folder](https://github.com/christianrickert/CU-CellSeg/tree/main/example) contains a single [MIBIscope™ image](https://github.com/christianrickert/CU-CellSeg/blob/main/example/20200109_3232_Run-16_FOV1_Final_3232_Top_R3C1_Tonsil.tiff) (800x800 px) and two corresponding pixel-classifier models - trained with dsDNA ([nu.model](https://github.com/christianrickert/CU-CellSeg/blob/main/example/nu.model)) and beta-tubulin ([ce.model](https://github.com/christianrickert/CU-CellSeg/blob/main/example/ce.model)), respectively.
Running CU-CellSeg with with the default [userThresholds](https://github.com/christianrickert/CU-CellSeg/blob/639e2b154d8455282ee769e337859a0713fe247f/CU-CellSeg.ijm#L75) and with the [cellMatrixChannels](https://github.com/christianrickert/CU-CellSeg/blob/639e2b154d8455282ee769e337859a0713fe247f/CU-CellSeg.ijm#L78) variable set to `newArray("beta-tubulin")`, should yield results identical to the data in the [results subfolder](https://github.com/christianrickert/CU-CellSeg/tree/main/example/20200109_3232_Run-16_FOV1_Final_3232_Top_R3C1_Tonsil). However, instead of the 7-zip archive, you will find a rather large comma-separated value file (.csv) with the measurements for each of the regions of interest.
The general output of CU-CellSeg consists of these files:
* `*.csv` - [measurements table](https://github.com/christianrickert/CU-CellSeg/blob/main/example/20200109_3232_Run-16_FOV1_Final_3232_Top_R3C1_Tonsil/20200109_3232_Run-16_FOV1_Final_3232_Top_R3C1_Tonsil.7z?raw=true)
* `*.tif` - [overview image](https://github.com/christianrickert/CU-CellSeg/blob/main/example/20200109_3232_Run-16_FOV1_Final_3232_Top_R3C1_Tonsil/20200109_3232_Run-16_FOV1_Final_3232_Top_R3C1_Tonsil.tif?raw=true)
* `*.txt` - [log file](https://github.com/christianrickert/CU-CellSeg/blob/main/example/20200109_3232_Run-16_FOV1_Final_3232_Top_R3C1_Tonsil/20200109_3232_Run-16_FOV1_Final_3232_Top_R3C1_Tonsil.txt)
* `*.csv` - [masks](https://github.com/christianrickert/CU-CellSeg/blob/main/example/20200109_3232_Run-16_FOV1_Final_3232_Top_R3C1_Tonsil/20200109_3232_Run-16_FOV1_Final_3232_Top_R3C1_Tonsil.zip?raw=true)

### Copyright notices
The [MIBIscope™ image](https://mibi-share.ionpath.com/tracker/overlay/sets/16/116) was kindly provided by Ionpath.
