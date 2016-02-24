repo for testing Thumbor functionality and image quality


# System requirements
- imagemagick: `brew install imagemagick`
- dssim: https://github.com/pornel/dssim#build-or-download

# Usage
- `bundle install`
- copy `config-example.yml` to `config.yml`
- add your thumbor details, images and transformation options
- ruby `bundle exec ruby run.rb`

# View test results
- `bundle exec middleman server`
- view results in browser

# Compile results into a static website
- `bundle exec middleman build`
- website will be in the `/build` dir

# How it works
- For each image url a new thumbor url will be generated based on the options hash (see https://github.com/thumbor/ruby-thumbor and/or read thumbor docs https://github.com/thumbor/thumbor for available transforms)
- Each source image will be downloaded
- Each thumbor url will be downloaded
- The transformed image will be compared to the source image, determining the DSSIM value
- The script will exit 1 on a failure
- Results can be viewed in a browser, where you can use an image comparison tool to compare source to transformed


# Fail conditions
- if a request does not succeed, the script will exit 1
- if any transformed image has a DSSIM value greater than the threshold, the script will exit 1