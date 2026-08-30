name: Build SimpleCowbell Rootless

on:
  push:
    branches: [ main, master ]
  pull_request:
    branches: [ main, master ]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout Code
        uses: actions/checkout@v4
        with:
          submodules: recursive

      - name: Setup Environment
        run: |
          sudo apt-get update
          sudo apt-get install -y build-essential clang git perl zip unzip

      - name: Setup Theos
        run: |
          git clone --recursive https://github.com/theos/theos.git $GITHUB_WORKSPACE/theos
          echo "THEOS=$GITHUB_WORKSPACE/theos" >> $GITHUB_ENV

      - name: Setup iOS SDK
        run: |
          git clone https://github.com/xyzdev/ios-sdks.git $GITHUB_WORKSPACE/sdks
          cp -r $GITHUB_WORKSPACE/sdks/iPhoneOS16.5.sdk $THEOS/sdks/

      - name: Build DEB Package
        run: |
          make clean
          make package THEOS_PACKAGE_SCHEME=rootless FINALPACKAGE=1

      - name: Upload Artifact
        uses: actions/upload-artifact@v4
        with:
          name: SimpleCowbell-Rootless
          path: packages/*.deb
