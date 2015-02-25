#!/bin/bash

if [ ! -d "js" ]; then
    mkdir js
fi
if [ ! -f "js/jquery.js" ]; then
    curl https://code.jquery.com/jquery-2.1.3.min.js > js/jquery-2.1.3.min.js
    cd js
    ln -s jquery-2.1.3.min.js jquery.js
fi
