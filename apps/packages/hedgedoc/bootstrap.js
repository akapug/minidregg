'use strict'

// Sandstorm invokes the packaged Node binary directly. HedgeDoc expects its
// source directory as the working directory for configuration and assets.
process.chdir('/opt/app/hedgedoc')
require('/opt/app/hedgedoc/app.js')
