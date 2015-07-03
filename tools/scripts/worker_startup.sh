# Startup script for the scintr worker

# Enable HTTPS for apt.
sudo apt-get update
sudo apt-get install apt-transport-https

# Get the Google Linux package signing key.
sudo sh -c 'curl https://dl-ssl.google.com/linux/linux_signing_key.pub | apt-key add -'

# Set up the location of the stable repository.
sudo sh -c 'curl https://storage.googleapis.com/download.dartlang.org/linux/debian/dart_stable.list > /etc/apt/sources.list.d/dart_stable.list'
sudo apt-get update

sudo apt-get install dart

git clone https://github.com/lukechurch/sintr.git

cd sintr/sintr_common

/usr/lib/dart/bin/pub get

cd ../sintr_worker

/usr/lib/dart/bin/pub get

dart bin/startup.dart sintr-994 control
