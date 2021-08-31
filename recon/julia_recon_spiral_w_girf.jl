using PyPlot, HDF5, MRIReco, LinearAlgebra, Dierckx, DSP, Images, FourierTools, ImageView, ImageBinarization, ImageEdgeDetection

## Preparation

include("../io/grad_reader.jl")
include("../utils/utils.jl")

## Load ISMRMRD data files (can be undersampled) THIS SHOULD BE THE ONLY SECTION NEEDED TO EDIT TO ADJUST FOR DIFFERENT SCANS
@info "Loading Data Files"

# selectedSlice = 3

selectedSlice = 1

# excitationList = 20:2:36 # for MULTISLICE

excitationList = [4]

sliceSelection = excitationList[selectedSlice]


# adjustmentDict is the dictionary that sets the information for correct data loading and trajectory and data synchronization
adjustmentDict = Dict{Symbol,Any}()
adjustmentDict[:reconSize] = (200,200)
adjustmentDict[:interleave] = 1
adjustmentDict[:slices] = 1
adjustmentDict[:coils] = 20
adjustmentDict[:numSamples] = 15475
adjustmentDict[:delay] = 0.00000 # naive delay correction
adjustmentDict[:interleaveDataFileNames] = ["GIRFReco/data/Spirals/523_21_1_2.h5", "GIRFReco/data/Spirals/523_23_2_2.h5", "GIRFReco/data/Spirals/523_25_3_2.h5", "GIRFReco/data/Spirals/523_27_4_2.h5"]


adjustmentDict[:trajFilename] = "GIRFReco/data/Gradients/gradients523.txt"
adjustmentDict[:excitations] = sliceSelection

adjustmentDict[:doMultiInterleave] = true
adjustmentDict[:doOddInterleave] = true
adjustmentDict[:numInterleaves] = 4

adjustmentDict[:singleSlice] = true

@info "Using Parameters:\n\n"
# define recon size and parameters for data loading

print(" reconSize = $(adjustmentDict[:reconSize]) \n interleave = $(adjustmentDict[:interleave]) \n slices = $(adjustmentDict[:slices]) \n coils = $(adjustmentDict[:coils]) \n numSamples = $(adjustmentDict[:numSamples])\n\n")

## Convert raw to AcquisitionData

@info "Merging interleaves and reading data"
acqDataImaging = mergeInterleaves(adjustmentDict)


## Sense Map Calculation

@info "Calculating Sense Maps" # Code commented out as the cartesian reconstruction takes care of this
# acqDataSense = acqDataImaging
#
# # Regrid to Cartesian
# acqDataCart = regrid2d(acqDataSense,adjustmentDict[:reconSize])
#
# # Calculate Sense maps using ESPiRiT
# sense = espirit(acqDataCart,(6,6),30,eigThresh_1=0.05, eigThresh_2=0.98)
# sensitivity = sense

## Assumes have a sense map from gradient echo scan

# Resize sense maps to match encoding size of data matrix
sensitivity = mapslices(x ->imresize(x, (acqDataImaging.encodingSize[1],acqDataImaging.encodingSize[2])), senseCartesian[33:96,:,:,:], dims=[1,2])
sensitivity = mapslices(rotl90,sensitivity,dims=[1,2])

## Plot the sensitivity maps of each coil
@info "Plotting SENSE Maps"

plotSenseMaps(sensitivity,adjustmentDict[:coils])

## B0 Maps (Assumes have a B0 map from gradient echo scan)
@info "Resizing B0 Maps"

resizedB0 = mapslices(x->imresize(x,(acqDataImaging.encodingSize[1], acqDataImaging.encodingSize[2])), b0, dims=[1,2])

## Define Parameter Dictionary for use with reconstruction

@info "Setting Parameters"
params = Dict{Symbol,Any}()
params[:reco] = "multiCoil"
params[:reconSize] = adjustmentDict[:reconSize]
params[:regularization] = "L2"
params[:λ] = 1.e-2
params[:iterations] = 20
params[:solver] = "cgnr"
params[:solverInfo] = SolverInfo(ComplexF64,store_solutions=false)
params[:senseMaps] = sensitivity[:,:,[selectedSlice],:]
params[:correctionMap] = -1im.*resizedB0[:,:,selectedSlice]

##
@info "Performing Reconstruction"
reco = reconstruction(acqDataImaging,params)

## Plotting reconstruction
@info "Plotting Reconstruction"

# IF MULTISLICE
# indexArray = [5,1,6,2,7,3,8,4,9]

# IF SINGLESLICE
indexArray = 1

#totalRecon = sum(abs2,reco.data,dims=5)
plotReconstruction(reco,1)

## Plotting for debugging

slice1 = abs.(resampledRecon[:,:,selectedSlice,1,1])
slice2 = abs.(reco.data[:,:,1,1,1])

#slice1 = slice1./maximum(slice1)
#slice2 = slice2./maximum(slice2)

figure("Reference Recon")
imshow(slice1,cmap="gray")
colorbar()
gcf().suptitle("|Image|")

figure("Spiral Recon")
imshow(slice2,cmap="gray")
colorbar()
gcf().suptitle("|Image|")

## Plot the image edges (feature comparison)

img_edges₁ = detect_edges(slice1,Canny(spatial_scale = 2.6))
img_edges₂ = detect_edges(slice2,Canny(spatial_scale = 2.7))

imEdges = cat(img_edges₁,img_edges₂,zeros(size(img_edges₁)),dims=3)

figure("Edge Differences")
imshow(imEdges)