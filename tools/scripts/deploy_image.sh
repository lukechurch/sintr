# Copyright (c) 2015, the Dart project authors.  Please see the AUTHORS file
# for details. All rights reserved. Use of this source code is governed by a
# BSD-style license that can be found in the LICENSE file.

# Script to pacakge and deploy the image for the librareis to where the
# workers will pull it from

# Run this script from the root of the sintr project

tar -cz --exclude="packages" --exclude=".pub" -f sintr-image.tar.gz sintr_*

# Uncomment to enable upload to cloud location
gsutil mv sintr-image.tar.gz gs://liftoff-dev-source
