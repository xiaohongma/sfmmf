#!/bin/sh

inputFolder=$1
outputName=$2

createFolders () {
  inputFolder=$1
  outputName=$2

  echo "Creating folders and moving images..."
  if [ ! -d "$inputFolder/points/" ]; then
    mkdir $inputFolder/points/
  fi
  if [ ! -d "$inputFolder/images/" ]; then
    mkdir $inputFolder/images/
  fi

  mv $inputFolder/*.jpg $inputFolder/images/ 2> /dev/null
  mv $inputFolder/*.JPG $inputFolder/images/ 2> /dev/null
  mv $inputFolder/*.png $inputFolder/images/ 2> /dev/null
  mv $inputFolder/*.PNG $inputFolder/images/ 2> /dev/null
}

createImageList () {
  inputFolder=$1
  outputName=$2
  echo "Creating image list"
  find $inputFolder/images/ -maxdepth 1 | grep '.jpg\|.JPG' > $inputFolder/$outputName-image-list.txt
  nbImages=$(wc -l < $inputFolder/$outputName-image-list.txt)
  if [ ! $nbImages -gt 0 ]; then
    echo "No image found"
    exit 1
  fi

  echo "$outputName-image-list.txt"
}

resizeAllimage (){
  inputFolder=$1
  outputName=$2
  # convert $inputFolder/*.jpg[3200x3200] resized%03d.jpg

  if [ ! -d "$inputFolder/resized-images/" ]; then
    mkdir $inputFolder/resized-images/
  else
    nb_resized=$(ls -l $inputFolder/resized-images/ | grep .jpg | wc -l)
  fi

  # Better quality:
  # convertCommand="convert"
  # Faster:
  convertCommand="convert -filter Point -define registry:temporary-path=$inputFolder/tmp"

  nb_jpg=$(ls -l $inputFolder/images/ | grep .jpg | wc -l)
  if [ $nb_jpg -gt 0 ] && [ $nb_jpg -gt $nb_resized ]
  then
    echo "Resizing too large images..."
    ulimit -v 2097152
    nice $convertCommand $inputFolder/images/*.jpg[3200\>x3200\>] $inputFolder/resized-images/resized%03d.jpg
    ulimit -v unlimited
    if [ $? -ne 0 ]; then
      exit 1
    fi
  fi

  nb_jpg=$(ls -l $inputFolder/images/ | grep .JPG | wc -l)
  if [ $nb_jpg -gt 0 ] && [ $nb_jpg -gt $nb_resized ]
  then
    echo "Resizing too large images..."
    ulimit -v 2097152
    nice $convertCommand $inputFolder/images/*.JPG[3200\>x3200\>] $inputFolder/resized-images/resized%03d.jpg
    ulimit -v unlimited
    if [ $? -ne 0 ]; then
      exit 1
    fi
  fi


  find $inputFolder/resized-images/ -maxdepth 1 | grep '.jpg' > $inputFolder/resized-$outputName-image-list.txt
  nbImages=$(wc -l < $inputFolder/resized-$outputName-image-list.txt)
  if [ ! $nbImages -gt 0 ]; then
    echo "No resized usable image found"
    exit 1
  fi
  echo "resized-$outputName-image-list.txt"
  exit 0
}

mergeMeshes () {
  inputFolder=$1
  outputName=$2
  echo "Merging all meshs with meshlab..."

  meshlabserver -i $inputFolder/points/*.ply -o $inputFolder/points/$outputName-points.ply -om vc vq vn fq fn wc wn wt
}

pmvsComputation () {
  inputFolder=$1
  outputName=$2
  echo "Creating the mesh from the point cloud using PoissonRecon..."
  PoissonRecon --in $inputFolder/points/$outputName-points.ply --out $inputFolder/$outputName-mesh.ply --depth 10 --color 16
}

removeImageLists () {
  inputFolder=$1
  outputName=$2
  echo "Removing image list files"
  rm $inputFolder/$outputName-image-list.txt
  rm $inputFolder/resized-$outputName-image-list.txt
}

removeVisualtSFMfiles () {
  inputFolder=$1
  outputName=$2
  echo "Removing VisualSFM files"
  # TODO fix
  # rm: impossible de supprimer 'result.cmvs': Aucun fichier ou dossier de ce type
  rm -R $inputFolder/points/result.cmvs
}

computeMesh () {
  inputFolder=$1
  outputName=$2
  createFolders $inputFolder $outputName
  imageListPath=$(createImageList $inputFolder $outputName)
  imageListPath=$(resizeAllimage $inputFolder $outputName)
  VisualSFM sfm $inputFolder/$imageListPath $inputFolder/points/$outputName-visualSFM-results.nvm
  # PMVS2
  # mergeMeshes $inputFolder $outputName
  # TODO avancement des stif files ls -1 | grep .sift | wc -l
  # TODO maybe remove SIFT files in the images folder
  pmvsComputation $inputFolder $outputName
  #removeImageLists
  # removeVisualtSFMfiles
}

if [ -n "$inputFolder" ] && [ -n "$outputName" ]; then
  # remove trailing slash
  inputFolder=${inputFolder%/}
  computeMesh $inputFolder $outputName
else
    echo "argument error"
fi
