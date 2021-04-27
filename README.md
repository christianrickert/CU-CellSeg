![header](https://user-images.githubusercontent.com/19319377/116157818-d863c380-a6aa-11eb-81d8-a458dbbe0b38.png)

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.4599644.svg)](https://doi.org/10.5281/zenodo.4599644)
# CU-CellSeg
## ImageJ2 macro for the cell segmentation of multi-channel images

### Segmentation approach
The CU-CellSeg macro implements a "classic" segmentation approach: In short, probability maps for nucleus channels (mandatory) and cell matrix channels (optional) are thresholded and segmented to create individual cellular compartments. Typical nucleus channels would be DAPI, dsDNA, or histone. Cell matrix channels could contain cytoplasm markers (beta-tubulin, keratin, vimentin, ...) or membrane markers (V-ATPase, HLA class 1, CD8, ...), or both. If no cell matrix channel is specified, cell outlines are generated by expanding the nuclei outlines by a fixed radius. Both cell matrix options generate non-overlapping cell outlines.

![nuclei](https://user-images.githubusercontent.com/19319377/116175227-2689be80-a6cd-11eb-85a8-5704d422aed8.png)![matrix](https://user-images.githubusercontent.com/19319377/116175233-28ec1880-a6cd-11eb-9bd7-3b8f387c7e37.png)


**Figure 1: Segmentation example.** Detail from the center of the composite image (top). Left side: Grayscale dsDNA channel with nuclei overlay (blue). Right side: Grayscale beta-tubulin channel with cell matrix overlay (red).

### Software documentation
The documentation of our macros is located in the corresponding source code: You can view the source code on GitHub by following the links to the macros.

### Software requirements
* The CU-CellSeg macro requires a recent version of the [Fiji](https://fiji.sc/) image processing package.
  * ImageJ2 (>= 1.53e)
  * Bio-Formats (>= 6.6.0)
  * Trainable Weka Segmentation Plugin (>= 3.2.34)

### Copyright notices
The [MIBIscope™ image](https://mibi-share.ionpath.com/tracker/overlay/sets/16/116) was kindly provided by Ionpath.
