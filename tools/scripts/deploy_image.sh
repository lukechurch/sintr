# Script to pacakge and deploy the image for the librareis to where the
# workers will pull it from

cd ../../
tar -cz --exclude="packages" -f sintr-image.tar.gz sintr_*

# Uncomment to enable upload to cloud location
gsutil mv sintr-image.tar.gz gs://liftoff-dev-source
