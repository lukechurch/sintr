FROM google/dart-runtime-base

WORKDIR /project/app

COPY liftoff-dev.token /project/app/crypto/

# Template for adding the application and local packages.
ADD app/pubspec.* /project/app/
RUN pub get
ADD . /project
RUN pub get --offline
