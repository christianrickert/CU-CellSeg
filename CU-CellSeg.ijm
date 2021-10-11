/*  Copyright 2021 Regents of the University of Colorado
 *
 *  This program is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <https://www.gnu.org/licenses/>.
 *
 *  Author:       Christian Rickert <christian.rickert@cuanschutz.edu>
 *  Group:        Human Immune Monitoring Shared Resource (HIMSR)
 *                University of Colorado, Anschutz Medical Campus
 *
 *  Title:        CU-CellSeg
 *  Summary:      ImageJ2 macro for the cell segmentation of multi-channel images
 *
 *  DOI:          https://doi.org/10.5281/zenodo.4599644
 *  URL:          https://github.com/christianrickert/CU-CellSeg/
 *
 *  Description:
 *
 *  CU-CellSeg uses the Fiji image processing package exclusively – there is no need
 *  to install additional plugins: You can simply edit or run this code by loading and
 *  executing it with the Macro plugin.
 *  In the first step of the cell segmentation process, the Bio-Formats plugin is used
 *  to read multi-channel images and to identify individual channels in the image stack.
 *  In the next step, selected channels depicting nuclei or cellular matrix elements
 *  (cytoplasm, membranes) are Median-normalized and Z-projected. The Trainable Weka
 *  Segmentation plugin is then used for the training and the application of separate
 *  pixel classifier models that calculate the probability of pixels belonging to the
 *  nuclei or the cellular matrix class, respectively. While the nuclei can be directly
 *  identified with the Analyze Particles function from the nuclei probability map using
 *  a user-defined threshold, the cellular matrix is identified with the nuclei as their
 *  center points for cellular matrix expansion using a marker-based watershed algorithm:
 *  The image basis for the cell particle identification is generated by combining the
 *  nuclei probability map with the Euclidean distance matrix of the nuclei, the cell
 *  matrix probability map, or with a combination of those two images and by applying a
 *  user-defined threshold. The actual cell segmentation is finally performed with the
 *  Find Maxima function. After both segmentations have been completed, the ROI Manger
 *  is employed to match all nuclei with cells and to compute the remaining cellular
 *  compartments based on user-defined parameters. All regions of interest are then
 *  overlayed with the initial multi-channel image to measure the properties of all
 *  cellular compartments - including their geometric and spatial properties - as well
 *  as the corresponding pixel data such as average intensities on a per-channel basis.
 *  In the final step, CU-CellSeg saves the results of the measurements as a CSV file,
 *  the regions of interest as a ZIP file, the segmentation result as a TIF file, and
 *  the Log output as TXT file.
 *  CU-CellSeg will repeat the segmentation and the analysis using identical parameters
 *  for every file matching the file name pattern. However, result files from repeated
 *  runs with the same file are overwritten.
 *
 *  Dependencies:
 *
 *  CU-CellSeg requires a recent version of CU-MacroLibrary to be installed:
 *  https://github.com/christianrickert/CU-MacroLibrary/
 */

/*
 *  Imports
 */

run("Bio-Formats Macro Extensions");  // access Bio-Formats extensions

/*
 *  Variables
 */

// file matching pattern
suffixes = newArray(".tif", ".tiff");  // match file name endings (not only extensions)

// particle detection settings
excludeEdges = true;  // exclude detection of nuclei bordering the edges of the image
minParticleSize = 2.5;  // minimum size [units²] for the detection of nuclei and cells
nucleiFilling = false;  // fills nuclei with dark centers white before final detection
userThresholds = newArray(false, 0.75, 1e30, (0.75 * 32767), 1e30);  // default values

// pixel classifier settings
cellMatrixChannels = newArray(0);  // optional, cell matrix channels
nucleiChannels = newArray("dapi", "dsdna");  // mandatory, nuclei channels

// cellular compartment settings
cellExpansion = 1.5;  // minimum cell radius [units] from closest nucleus
cellExpansionLimit = 100.0;  // maximum cell radius [units] from closest nucleus
cellMatrixContraction = 0.0;  // cellular matrix masks contraction [units]
membraneWidth = 0.0;  //  membrane width [units] inside the cell outline
nucleiContraction = 0.0;  // nuclei masks contraction [units]

// advanced user settings
batchMode = true;  // speed up processing by limiting visual output
cellMatrixChannelsLength = cellMatrixChannels.length;
targetNames = newArray("nu", "ce", "me", "cy", "cm");  // labels for classes and file output
targetCounts = initializeArray(targetNames.length, 0);  // regions of interest counts
versionString = "CU-CellSeg v1.00 (2021-10-11)\n" +
                 libraryVersion;


/*
 *  Start
 */

print("\\Clear");  // clear Log window
requires("1.52u");  // minimum ImageJ version
run("ROI Manager...");  // start before batch mode
run("Roi Defaults...", "color=red stroke=0 group=0");
roiManager("useNames", "true");  // use ROI names as labels
run("Options...", "edm=16-bit");  // access larger distances
run("Brightness/Contrast...");  // start for user convenience
files = getFilesInFolder("Select the first TIFF of your dataset", suffixes);
processFolder(files, userThresholds);

/*
 *  Loop
 */

// Function to process files with matching suffixes from a folder
function processFolder(files, thresholds)
{
  files_length = files.length;
  for ( i = 0; i < files_length; ++i )
  {
    processFile(files[i], thresholds);
  }
}

// Function to process a single file
function processFile(file, thresholds)
{
  // prepare next run
  initializeRun(versionString);
  print("\n*** Processing file ***");
  print("\t" + file);

  // read image file
  filePath = File.getDirectory(file);
  fileName = File.getName(file);
  fileSlices = readImage(file);
  fileTitle = getTitle();

  // get calibration data from image file
  pixelCalibration = getPixelCalibration();
  if ( pixelCalibration[0] == "pixels" )  // no conversion required
    toPixels = 1.0;
  else  // calculate conversion factor
    toPixels = Math.round(1.0 / 0.5 * (pixelCalibration[1] + pixelCalibration[2]));
  print("\t Calibration: " + toPixels + " pixel per " + pixelCalibration[0]);

  // create projections for nuclei and cellular matrix
  projectedNuclei = projectStack(fileTitle, fileSlices, nucleiChannels, targetNames[0]);
  classifiedNuclei = classifyImage(projectedNuclei, targetNames[0], filePath);
  if ( cellMatrixChannelsLength > 0 )
  {
    projectedCellMatrix = projectStack(fileTitle, fileSlices, cellMatrixChannels, targetNames[1]);
    classifiedCellMatrix = classifyImage(projectedCellMatrix, targetNames[1], filePath);
  }
  else
    classifiedCellMatrix = createImageFromTemplate(classifiedNuclei, "ce->none");

  // projection and pixel classification incompatible with batch mode, safe from here
  toggleBatchMode(batchMode, false);

  // segment nuclei from projection, create distance mask for cell expansion limit
  segmentedNuclei = segmentNucleiImage(classifiedNuclei, thresholds, targetCounts);
  nucleiDistanceMap = createDistanceMap(segmentedNuclei);
  nucleiDistanceMask = createDistanceMask(nucleiDistanceMap, nucleiContraction, cellExpansionLimit);

  // simulate cellular matrix image for minimum cell expansion, segment combined cellular matrix
  simulatedCellMatrix = simulateCellMatrixImage(targetNames[1], nucleiDistanceMap, nucleiContraction, cellExpansion);
  combinedCellMatrix = combineMaxImages(classifiedCellMatrix, simulatedCellMatrix);
  maskedCellMatrix = maskImage(combinedCellMatrix, nucleiDistanceMask);
  CellMatrixWithNuclei = combineCellMatrixWithNuclei(segmentedNuclei, maskedCellMatrix, targetNames);
  segmentedCellMatrix = segmentCellMatrixImage(CellMatrixWithNuclei, thresholds, targetNames[1], targetCounts);

  // match and modify regions of interest to produce a compartment image
  matchNucleiWithCells(targetNames, targetCounts);
  createCompartments(targetNames, targetCounts);
  renderedCells = renderCellsImage(segmentedCellMatrix);

  // measure nuclei, cells, membranes, and cytoplasm in multi-channel image
  measureRegions(fileTitle);

  // save and clear run, free memory
  finalizeRun(filePath, fileName, renderedCells);
  freeMemory();

  // restore user interface and display results
  toggleBatchMode(batchMode, false);
}

/*
 *  Functions
 */

// Function to classify images for more robust segmentation results
function classifyImage(image, target, path)
{
  print("\n*** Classifying " + target + " image ***");

  selectWindow(image);
  setMetadata("Label", image);  // Weka displays label in its window
  normalizePixelValues();  // normalize for stable classification results
  output = runWekaClassifier(image, target, path);
  return output;
}

// Function to combine the cellular matrix with the nuclei image
function combineCellMatrixWithNuclei(image1, image2, targets)
{
  print("\n*** Combining nuclei with cellular matrix ***");

  selectWindow(image1);
  rescalePixelValues(0.0, 1.0, 0.0, 65535.0);  // absolute maxima for peak detection
  selectWindow(image2);
  rescalePixelValues(0.0, 1.0, 0.0, 32767.0);  // relative maxima for peak segmentation
  output = combineMaxImages(image1, image2);
  return output;
}

// Function to combine two images by their maximum pixel values
function combineMaxImages(image1, image2)
{
  output = image1 + " ++ " + image2;
  imageCalculator("Max create 32-bit", image1, image2);
  renameImage("", output);
  return output;
}

// Function to generate a black canvas from selected image template
function createImageFromTemplate(image, name)
{
  output = name;

  selectWindow(image);
  height = getHeight();
  width = getWidth();
  type = bitDepth();
  depth = 1;
  newImage(output, type + " black", width, height, depth);
  return output;
}

// Function to create cellular compartments from pairs of cells and nuclei
function createCompartments(target, counts)
{
  // Both the membrane and the cytoplasm are created by simple subtractions
  // of the corresponding cell and nuclei regions: The membrane is created by
  // subtracting a contracted version of the cell and the nucleus from the
  // original cell, while the cytosol is calculated by substracting the membrane
  // and the nucleus from the cell. If any of the subtractions fails, because
  // the subtraction yields no selectable region (no pixels left), the following
  // steps are skipped. If the nuclei or the cell contraction fails, an object
  // identical to the original is returned - so this will never remove regions.
  print("\n*** Creating cellular compartments ***");
  print("\tThis might take a while...");
  showStatus("!Creating cellular compartments...");  // display and protect status message
  unit = pixelCalibration[0];
  print("\tCell contraction: " + cellMatrixContraction + " " + unit);
  print("\tMembrane width: " + membraneWidth + " " + unit);
  print("\tNuclei contraction: " + nucleiContraction + " " + unit);

  cellArea = 0.0;  // area in pixel²
  cellMatrixContraction = -cellMatrixContraction;
  delimiter = ":";
  membraneWidth = -membraneWidth;
  nucleiContraction = -nucleiContraction;
  nucleusArea = 0.0;

  last = counts[0] + counts[1] - 1;
  for (i = last; i >= 0; --i )  // iterate through cells and nuclei in reverse order
  {
    roiManager("select", i);
    if ( i % 2 != 0 )  // nuclei
    {
      if ( nucleiContraction < 0 )
      {
        getResizedSelection(i, nucleiContraction, unit);
        roiManager("update");  // resized nucleus
      }
      nucleusArea = getValue("Area raw");
    }
    else  // cells
    {
      if ( cellMatrixContraction < 0 )
      {
        getResizedSelection(i, cellMatrixContraction, unit);
        roiManager("update");  // resized cell
      }
      cellArea = getValue("Area raw");
      if ( cellArea > nucleusArea )
      {
        n = i + 1;  // nucleus
        regionID = getRegionID(n);
        if ( membraneWidth < 0 )
        {
          getResizedSelection(i, membraneWidth, unit);
          roiManager("add");  // shrunk cell
          p = getLastRegionIndex();  // get an index pointer
          roiManager("select", p);
          RoiManager.setGroup(9);
          if ( substractRegions(i, newArray(n, p)) )  // cell minus nucleus and shrunk cell
          {
            renameRegion(++p, regionID + delimiter + targetNames[2]);  // calculated membrane
            RoiManager.setGroup(3);
            if ( substractRegions(i, newArray(n, p)) )  // cell minus nucleus and membrane
            {
              renameRegion(++p, regionID + delimiter + targetNames[3]); // remaining cytoplasm
              RoiManager.setGroup(4);
            }
          }
        }
        else  // no membrane requested
        {
          if ( substractRegions(i, newArray(toString(n))) )  // cell minus nucleus
          {
            p = getLastRegionIndex();
            renameRegion(p, regionID + delimiter + targetNames[4]); // cellular matrix
            RoiManager.setGroup(5);
          }
        }
      }
    }
    if ( i % 200 == 0 )
      showProgress(last - i, last);
  }

  showStatus("!Deleting temporary regions...");
  deleteGroupRegions(9);
  roiManager("sort");  // new regions are sorted by creation time
  showStatus("");  // clear and free status message
  RoiManager.selectGroup(3);  // cellular matrix or membranes
  counts[2] = RoiManager.selected();
  RoiManager.selectGroup(4);  // cytoplasm
  counts[3] = RoiManager.selected();
  roiManager("show none");
  clearAllSelections();
  if ( membraneWidth < 0 )
  {
    print("\tCounts: " + counts[0] + " (" + target[0] + "), "
                       + counts[1] + " (" + target[1] + "), "
                       + counts[2] + " (" + target[2] + "), "
                       + counts[3] + " (" + target[3] + ")");
  }
  else
  {
    print("\tCounts: " + counts[0] + " (" + target[0] + "), "
                       + counts[1] + " (" + target[1] + "), "
                       + counts[2] + " (" + target[4] + ")");
  }
}

// Function to create an Euklidian distance map from segmented particles
function createDistanceMap(image)
{
  print("\n*** Creating nuclei distance map ***");
  output = image + "->dist";

  selectWindow(image);
  run("Duplicate...", "title=tmp");
  setOption("ScaleConversions", true);
  run("8-bit");  // required for EDM function call
  run("Invert");  // EDM works with black particles on white background
  run("Distance Map");  // creates separate distance map, see Binary Options
  renameImage("", output);
  getRawStatistics(nPixels, mean, min, max);  // from slice, not stack
  print("\tNuclei distances: " + min / toPixels + " " + pixelCalibration[0] + " (min), "
                               + max / toPixels + " " + pixelCalibration[0] + " (max)");
  close("tmp");
  return output;
}

// Function to create an Euklidian distance-based mask from segmented particles
function createDistanceMask(image, contraction, limit)
{
  print("\n*** Creating cytoplasm distance mask ***");
  print("\tCell expansion limit: " + limit + " " + pixelCalibration[0]);
  output = image + "->mask";
  limit = Math.round(toPixels * (limit - contraction));

  selectWindow(image);
  run("Duplicate...", "title=" + v2p(output));
  setThreshold(limit, 1e30);
  setOption("BlackBackground", true);
  run("Convert to Mask");  // make 8-bit binary (0 / 255)
  run("Invert");
  rescalePixelValues(NaN, NaN, 0.0, 1.0);  // make 1-bit binary (0 / 1)
  return output;
}

// Function to finalize a segmentation run by saving all results
function finalizeRun(path, name, image)
{
  print("\n*** Saving results to files ***");

  label = File.getNameWithoutExtension(name);
  directory = path + File.separator + label;  // create subfolder for result files
  File.makeDirectory(directory);
  result = directory + File.separator + label;  // generic full result path (without extension)
  zipFile = result + ".zip";
  print("\tWriting: " + zipFile);
  waitForFileDeletion(zipFile);
  roiManager("save", zipFile);
  csvFile = result + ".csv";
  print("\tWriting: " + csvFile);
  waitForFileDeletion(csvFile);
  saveAs("Results", csvFile);
  if ( batchMode )
  {
    selectWindow(image);
    close("\\Others");  // close all images except for the selected image
  }
  else
    run("Images to Stack", "name=" + v2p(name) + " title=[] use");
  tifFile = result + ".tif";
  print("\tWriting: " + tifFile);
  waitForFileDeletion(tifFile);
  run("Bio-Formats Exporter", "save=[" + tifFile + "] export compression=LZW");
  Ext.close();  // close active Bio-Formats dataset
  txtFile = result + ".txt";
  print("\tWriting: " + txtFile);
  waitForFileDeletion(txtFile);
  printDateTimeStamp();
  saveLogFile(txtFile);
}

// Function reads user-defined threshold values
function getUserThresholds(target, thresholds)
{
  title =   "Finalize thresholds limits";
  message = "Set the limits in the Threshold window and\n" +
            "cover the background with the blue mask:\n" +
            "Leave the white target regions unmasked.\n \n" +
            "The macro will apply the new thresholds,\n" +
            "upon confirming this dialog with OK,\n" +
            "but stop execution with Cancel.";
  
  toggleBatchMode(batchMode, true);  // stay in batch mode, but show current image
  run("Threshold...");
  call("ij.plugin.frame.ThresholdAdjuster.setMethod", "Otsu");  // preset Window defaults
  call("ij.plugin.frame.ThresholdAdjuster.setMode", "Over/Under");
  waitForUser(title, message);
  if (target == targetNames[0])  // read user-defined values
    getThreshold(thresholds[1], thresholds[2]);
  else if (target == targetNames[1])
    getThreshold(thresholds[3], thresholds[4]);
  run("Close");
  toggleBatchMode(batchMode, true);  // hide image and (re-)enter batch mode
}

// Function to mask the cytoplasm image to limit cell expansion
function maskImage(image1, image2)
{
  print("\n*** Masking cytoplasm image ***");
  output = image1 + "->dist mask";

  imageCalculator("Multiply create 32-bit", image1, image2);
  renameImage("", output);
  return output;
}

// Function to match regions of interest (nuclei/cells) with ROI Manager
function matchNucleiWithCells(target, counts)
{
  // We're matching each nucleus with a cell by checking if each of the pixels
  // from the nucleus region fall within a candidate cell region. However, the
  // pixel-by-pixel comparisons are slow, so we first approximate by comparing
  // the bounding box locations of the nucleus with the cell only. If there's
  // no overlap, we skip the current cell and continue with the next cell.
  // In order to avoid checking already matched cells multiple times, we keep
  // track of the match status in a cell array. However, this doesn't scale
  // well with many (> 10,000) cell candidates. That's why we make use of the
  // fact that the multithreaded cell segmentation produces cells roughly in
  // the same order as the nuclei - alas with some unknown offset: First, we
  // jump to a cell candidate in proximity of the nucleus index minus the offset
  // and then start to check incrementally for a match. If our estimate for the
  // actual offset fell short and we didn't find a matching cell from the start
  // of our search to the end of the cell list, we simply start from the first
  // cell until we've checked all possible cell candidates - the index counter
  // for the cell matches behaves like a ring buffer index by wrapping around.
  print("\n*** Matching nuclei with cells ***");
  print("\tThis might take a while...");
  showStatus("!Matching " + counts[0] + " nuclei with "
                          + counts[1] + " cells...");
  cells = counts[1];
  nuclei = counts[0];
  rois = cells + nuclei;
  matched = initializeArray(cells, false);  // matching table for cells
  offset = 100;  // offset from multithreaded cellular matrix segmentation
  roiManager("select", Array.getSequence(rois));  // select all regions
  RoiManager.setGroup(9);  // unmatched regions, mark for later removal

  showProgress(0);  // reset progress bar
  for (n = 0; n < nuclei; ++n)  // iterate through nuclei
  {
    found = false;  // track matching of nucleus with cell
    overlap = false;  // track overlap of nucleus with cell
    roiManager("select", n);
    Roi.getBounds(nu_x, nu_y, nu_width, nu_height)  // bounding rectangle of nucleus
    Roi.getContainedPoints(nu_xx, nu_yy);  // pixels inside nucleus
    nu_xx_length = nu_xx.length;

    if ( n > offset )  // jump ahead to cell in list proximity
      c = n - offset;
    else
      c = 0;  // relative cell index for list of cells
    for (d = 0; ( !found ) && ( d < cells ); ++d)  // cycle through cells
    {
      if ( matched[c] == false )  // cell not yet matched
      {
        i = nuclei + c; // absolute cell index for list of rois
        roiManager("select", i);
        Roi.getBounds(ce_x, ce_y, ce_width, ce_height)  // bounding rectangle of cell
        if ( nu_x >= ce_x && nu_x <= (ce_x + ce_width) &&
             nu_y >= ce_y && nu_y <= (ce_y + ce_height) )  // fast approximation of nucleus location
        {
          overlap = true;  // bounding box indicates possible overlap, now checking in-depth (slow)
          for (p = 0; ( overlap == true ) && ( p < nu_xx_length ); ++p)  // iterate through nucleus pixels
          {
            if ( !Roi.contains(nu_xx[p], nu_yy[p]) )  // nucleus pixel outside cell
              overlap = false;
          }

          if ( overlap ) // full overlap
          {
            regionID = toString(n + 1) + ":";  // avoid "NaN" error with preceeding numeric value
            renameRegion(n, regionID + targetNames[0]);
            RoiManager.setGroup(1);  // nucleus, paired with cell
            found = true;
            renameRegion(i, regionID + targetNames[1]);
            RoiManager.setGroup(2);  // cell, matched with nucleus
            matched[c] = true;
          }
        }
      }
      c = ( c + 1 ) % cells;
    }

    if ( n % 100 == 0 )
      showProgress(n, nuclei);
  }

  showStatus("!Deleting unmatched regions...");
  deleteGroupRegions(9);
  roiManager("sort");  // matching regions are unordered
  showStatus("");
  RoiManager.selectGroup(1);
  counts[0] = RoiManager.selected();
  RoiManager.selectGroup(2);
  counts[1] = RoiManager.selected();
  roiManager("show none");
  clearAllSelections();
  print("\tCounts: " + counts[0] + " (" + target[0] + "), "
                     + counts[1] + " (" + target[1] + "), "
                     + (rois - counts[0] - counts[1]) + " (-)");
}

// Function to measure regions from ROI Manager
function measureRegions(image)
{
  // The properties of all regions of interest (cell compartments) as well as teh pixel intensities
  // in these compartments are measured for all channels. Unfortunately, the measurement functions
  // remove columns which are not consensus, i.e. present for all entries. Alternatively, one could
  // implement a custom table that iterates through all regions of interest manually. However, the
  // perfomance impact will be quite significant with this approach.
  // The measurement function is pretty aggressive with its use of resources: I've tried several
  // ideas to update the status bar during the measurements. For now, we're stuck with the slice
  // slider as an indicator for the measurement progress.
  print("\n*** Measuring regions of interest ***");
  print("\tThis might take a while...");
  rois = roiManager("count");
  slices = 0;

  selectWindow(image);
  Ext.getImageCount(slices);
  showStatus("!Measuring " + rois + " regions of interest in " + slices + " channels...");
  run("Set Measurements...", "area mean standard modal min centroid center perimeter bounding fit shape feret's " +
      "integrated median skewness kurtosis area_fraction stack display scientific nan redirect=None decimal=3");

  for (i = 0; i < slices; ++i)
  {
    setSlice(i + 1);
    roiManager("measure");  // add measurement to Results window
  }

  showStatus("");
  close(image);
}

// Function to create a projected image from an image stack
function projectStack(image, slices, channels, target)
{
  // The slices used for the projection are identified by matching the slice labels
  // with the user-defined channel list. We're then creating a copy of the user-defined
  // channel or a projection of the list user-defined channels. Before the projection,
  // each slice is normalized by its median value to balance all pixel intensities.
  print("\n*** Projecting " + target + " image ***");
  output = target + "->proj";
  channelsLength = channels.length;
  channelMatches = 0;
  slicesLength = slices.length;
  stackSelection = "";

  selectWindow(image);

  for (i = 1; i <= slicesLength; ++i)  // iterate through slices
  {

    for (j = 0; j < channelsLength; ++j)  // match slice names with channels
    {
      slice = toLowerCase(slices[i - 1]);  // label pattern: "#" or "name (channel/mass)"
      if ( slice == channels[j] ||
          slice.contains(toLowerCase(channels[j])  + " ") )  // matching pattern: "name "
      {
        if ( stackSelection.length > 0 )  // append slices
          stackSelection = stackSelection + ",";
        stackSelection = stackSelection + toString(i);
        channelMatches += 1;
      }
    }

  }

  if ( channelMatches <= 1 )  // copy slice from stack
  {
    if ( channelMatches == 1 )  // select matching channel
      setSlice(stackSelection);
    run("Duplicate...", "title=slice-" + target);
  }
  else if ( channelMatches >= 2 ) // stack matching channels
  {
    run("Make Substack...", "channels=" + v2p(stackSelection));
    renameImage("", "stack-" + target);

    for (i = 0; i < channelMatches; ++i)
    {
      setSlice(i + 1);
      normalizePixelValues();  // normalize for balanced projection results
    }

    run("Z Project...", "projection=[Sum Slices]");  // project stack to image
    close("stack-*");  // close projection stack
  }
  renameImage("", output);
  print("\tChannels: \"" + stackSelection + "\" (" + target + ")");
  return output;
}

// Function to render an image with all cellular compartments
function renderCellsImage(image)
{
  // We're drawing the cells region in red to indicate regions,
  // for which the compartment creation has failed: A typical
  // case would be, if the membrane area is larger than the
  // available cell area - and the substraction of the child
  // region from the parent region fails.
  print("\n*** Rendering cellular compartments image ***");
  output = image + "->comp";

  createImageFromTemplate(image, output);
  if ( batchMode )
    run("RGB Color");
  colorGroup(2, 255, 0, 0);  // cells, red (should not be visible)
  colorGroup(3, 255, 255, 255);  // cellular matrix or membranes, white
  colorGroup(4, 127, 127, 127);  // cytoplasm, gray
  colorGroup(1, 207, 184, 124);  // nuclei, gold
  return output;
}

// Function to train and run a Weka classification
function runWekaClassifier(image, target, path)
{
  // The tricky part was to wait until the Trainable Weka Classifier plugin has
  // started or until the computation of the probability maps was completed,
  // since these variable times are highly system-dependent. This problem was
  // solved by frequently checking for the currently selected image name:
  // By default, newly opened or created images get the focus in ImageJ2.
  output = image + "->prob";
  classifier = path + target +".model";
  data = path + target +".arff";
  title =   "Finalize classifier training";
  message = "Draw selections in the Weka window and\n" +
            "assign these to their respective classes:\n" +
            "Train the classifier to update the results.\n \n" +
            "The macro will save the new classifier,\n" +
            "upon confirming this dialog with OK,\n" +
            "but stop execution with Cancel.";
  
  run("Trainable Weka Segmentation");  // start the Trainable Weka Segmentatio plugin
  waitForWindow("Trainable Weka Segmentation");  // title contains changing version number
  call("trainableSegmentation.Weka_Segmentation.setFeature", "Entropy=true");
  if ( target == targetNames[0] )
    call("trainableSegmentation.Weka_Segmentation.changeClassName", "0", "nuclei");
  else if ( target == targetNames[1] )
    call("trainableSegmentation.Weka_Segmentation.changeClassName", "0", "cellular matrix");
  call("trainableSegmentation.Weka_Segmentation.changeClassName", "1", "uncertain");
  call("trainableSegmentation.Weka_Segmentation.createNewClass", "background");
  if ( !File.exists(classifier) )  // classifier missing in folder
  {
    print("\tNo classifier file in dataset folder...");
    waitForUser(title, message);
    call("trainableSegmentation.Weka_Segmentation.saveClassifier", classifier);
    call("trainableSegmentation.Weka_Segmentation.saveData", data);
  }
  print("\tUsing classifier found in dataset folder...");
  call("trainableSegmentation.Weka_Segmentation.loadClassifier", classifier);
  call("trainableSegmentation.Weka_Segmentation.getProbability");
  waitForWindow("Probability maps");  // computation time machine-dependent
  close("Trainable Weka Segmentation*");  // title changes with version
  renameImage("", output);

  while ( nSlices() > 1 )  // use only first probability map
  {
    setSlice(nSlices());
    run("Delete Slice");
  }

  return output;
}

// Function to segment cellular matrix images into regions of interest
function segmentCellMatrixImage(image, thresholds, target, counts)
{
  // We're using a trick here to avoid local maxima detection within the cell matrix image:
  // With a prominence value of 32767, peaks will only be detected, if they stand out above
  // the surrounding plateau by a value of 32768 or greater. By combining a nuclei image
  // with intensities of 0 or 65535 with a cell matrix image with intensities ranging from
  // 0-32767, only nuclei-to-cell-matrix peaks will be detected by the algorithm.
  print("\n*** Segmenting cellular matrix image ***");
  print("\tMinimum cell size: " + minParticleSize + " " + pixelCalibration[0] + "²");
  output = target;

  selectWindow(image);
  updateDisplayRange(NaN, NaN);
  roiManager("show all without labels");
  setUserThresholds(targetNames[1], thresholds);
  run("Find Maxima...", "prominence=32767 strict above output=[Segmented Particles]");
  renameImage("", output);
  run("Analyze Particles...", "size=" + v2p(minParticleSize) + "-Infinity add");
  roiManager("show none");
  counts[1] = roiManager("count") - counts[0];
  print("\tCounts: " + counts[1] + " (cells)");
  return output;
}

// Function to segment nuclei images into regions of interest
function segmentNucleiImage(image, thresholds, counts)
{
  // The filling of the nuclei is implemented by running the Analyze Particles function twice:
  // In the first run, the detection algorithm uses a lasso algorithm by detecting the outlines
  // of the nuclei and then filling the detected regions of interest without adding any new
  // regions to the ROI Manager. In the second run, the nuclei are detected using the erosion-
  // watershed algorithm to detect and add new regions of interest to the ROI Manager.
  print("\n*** Segmenting nuclei image ***");
  print("\tMinimum nucleus size: " + minParticleSize + " " + pixelCalibration[0] + "²");
  output = image + "->seg";
  if ( excludeEdges )
    exclude = "exclude ";
  else
    exclude = "";

  selectWindow(image);
  run("Duplicate...", "title=" + v2p(output));
  setUserThresholds(targetNames[0], thresholds);
  setOption("BlackBackground", true);
  run("Convert to Mask", "method=Otsu background=Dark black");
  if ( nucleiFilling )
  {
    run("Analyze Particles...", "size=" + v2p(minParticleSize) + "-Infinity show=[Masks] include in_situ");
    print("\tNuclei filling: True");
  }
  else
    print("\tNuclei filling: False");
  run("Watershed", "slice");
  run("Analyze Particles...", "size=" + v2p(minParticleSize) + "-Infinity show=[Masks] "
                                      + exclude + "in_situ add");
  roiManager("show none");
  counts[0] = roiManager("count");
  print("\tCounts: " + counts[0] + " (nuclei)");
  return output;
}

// Function reads user-defined threshold values
function setUserThresholds(target, thresholds)
{
  if ( target == targetNames[0] )  // preset default values
    setThreshold(thresholds[1], thresholds[2]);
  else if ( target == targetNames[1] )
    setThreshold(thresholds[3], thresholds[4]);
  if ( thresholds[0] == false )  // check for custom values
    getUserThresholds(target, thresholds);
  if ( target == targetNames[0] )
  {
    setThreshold(thresholds[1], thresholds[2]);
    print("\tThresholds: " + thresholds[1] + " (lower), " + thresholds[2] + " (upper)");
  }
  else if ( target == targetNames[1] )
  {
    setThreshold(thresholds[3], thresholds[4]);
    thresholds[0] = true;
    print("\tThresholds: " + thresholds[3] + " (lower), " + thresholds[4] + " (upper)");
  }
}

// Function to simulate cellular matrix images based on nuclei distance maps
function simulateCellMatrixImage(target, image, contraction, expansion)
{
  // Instead of manipulating regions of interest after detection, i.e. expanding
  // existing cells to the minimum expansion value, we avoid overlapping cells or
  // computationally expensive region manipulations by providing a generic cell
  // matrix image that will be merged with the cell matrix classifer probability
  // map (if produced by the user). This way, the minimum cell expansion will
  // simply be part of the nuclei-based cell segmentation step that uses
  // watershed barriers to prevent overlapping of cells.
  print("\n*** Simulating cellular matrix image ***");
  print("\tCell expansion: " + expansion + " " + pixelCalibration[0]);
  output = target + "->sim";
  expansion = Math.round(toPixels * (expansion - contraction));

  selectWindow(image);
  run("Duplicate...", "title=" + v2p(output));
  getRawStatistics(nPixels, mean, min, max);
  changeValues(min, expansion, 32767.0);  // enhance distances within value
  changeValues((expansion + 1), max, 0.0);  // suppress distances above value
  return output;
}
