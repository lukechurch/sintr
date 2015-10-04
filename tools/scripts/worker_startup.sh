# Startup script for the scintr worker
# This should be run on the worker node

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

# Dpeloy crypto tokens
mkdir -p ~/Communications/CryptoTokens
gsutil cp gs://liftoff-dev-crypto-tokens/* ~/Communications/CryptoTokens

# Dpeloy the source
mkdir -p ~/src/sintr
gsutil cp gs://liftoff-dev-source/sintr-image.tar.gz ~/src/sintr/sintr-image.tar.gz

cd ~/src/sintr/
tar -xf sintr-image.tar.gz
cd sintr_common
/usr/lib/dart/bin/pub get
cd ..

cd sintr_working
/usr/lib/dart/bin/pub get
cd ..

cd sintr_worker
/usr/lib/dart/bin/pub get
cd ..

# Now in worker roout

cd sintr_worker

INSTANCE_ID=$(curl http://metadata/computeMetadata/v1/instance/hostname -H "Metadata-Flavor: Google")
NOW=$(date +"%Y-%m-%d-%H-%M-%S")


dart -c bin/startup.dart liftoff-dev example_task $(readlink -f ../sintr_working)/ > ../$INSTANCE_ID-$NOW.log 2>&1

gsutil cp ../$INSTANCE_ID-$NOW.log gs://liftoff-dev-worker-logs
