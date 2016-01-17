# Startup script for the scintr worker
# This should be run on the worker node

JOB_NAME=$1

echo "Job:" $JOB_NAME

# Install Dart
# Enable HTTPS for apt.
sudo apt-get update
sudo apt-get install apt-transport-https

# Get the Google Linux package signing key.
sudo sh -c 'curl https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -'

# Set up the location of the stable repository.
sudo sh -c 'curl https://storage.googleapis.com/download.dartlang.org/linux/debian/dart_stable.list > /etc/apt/sources.list.d/dart_stable.list'
sudo apt-get update

sudo apt-get install dart
sudo apt-get install git -y

# Add Dart to the path
PATH=$PATH:/usr/lib/dart/bin

# Dpeloy crypto tokens
mkdir -p ~/Communications/CryptoTokens
gsutil cp gs://liftoff-dev-crypto-tokens/* ~/Communications/CryptoTokens

# Dpeloy the source
mkdir -p ~/src/sintr
gsutil cp gs://liftoff-dev-source/sintr-image.tar.gz ~/src/sintr/sintr-image.tar.gz

cd ~/src/sintr/
tar -xf sintr-image.tar.gz

# Pub get
find . -type f -name 'pubspec.yaml' \
  -exec sh -c '(publican=$(dirname {}) && cd $publican && pub get)' \;

# Setup the worker structure
mkdir ~/src/sintr/sintr_worker

# Now in worker root
cd ~/src/sintr/sintr_worker

while true; do
  INSTANCE_ID=$(curl http://metadata/computeMetadata/v1/instance/hostname -H "Metadata-Flavor: Google")
  NOW=$(date +"%Y-%m-%d-%H-%M-%S")

  # startup.dart project_name job_name worker_folder
  dart -c bin/startup.dart liftoff-dev $JOB_NAME $(readlink -f ~/src/sintr/sintr_worker)/ > ../$INSTANCE_ID-$NOW.log 2>&1

  # Upload the logs
  gsutil cp ../$INSTANCE_ID-$NOW.log gs://liftoff-dev-worker-logs
  sleep 5
done
