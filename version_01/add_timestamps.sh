#!/bin/bash

# Generate timestamp
timestamp=$(date '+%Y%m%d_%H%M%S')

# Rename folder and file
mv data "data_${timestamp}"
mv "data_${timestamp}/sitemap.xml" "data_${timestamp}/sitemap_${timestamp}.xml"
